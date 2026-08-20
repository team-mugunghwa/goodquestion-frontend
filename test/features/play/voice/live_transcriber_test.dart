import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/features/play/presentation/voice/live_transcriber.dart';

/// [resolveVoiceMode] 판정표, [ScriptedLiveTranscriber] 의 흘리기·정리
/// 동작, [NoopLiveTranscriber] 의 강등 동작을 확인한다.
void main() {
  group('resolveVoiceMode', () {
    // liveReady가 false면 나머지 두 값과 무관하게 recordOnly.
    // liveReady가 true일 때만 canRecordWhileListening·hasServerStt 조합이
    // 의미를 가진다.
    const List<
      (bool liveReady, bool canRecord, bool hasServerStt, RecapVoiceMode want)
    >
    cases = <(bool, bool, bool, RecapVoiceMode)>[
      (false, false, false, RecapVoiceMode.recordOnly),
      (false, false, true, RecapVoiceMode.recordOnly),
      (false, true, false, RecapVoiceMode.recordOnly),
      (false, true, true, RecapVoiceMode.recordOnly),
      (true, false, false, RecapVoiceMode.liveOnly),
      // 서버 STT가 있는데 동시 녹음이 안 되면 liveOnly가 아니라
      // recordOnly다 - 침묵 3초에 끊긴 뒷부분을 복구할 원본이 없어서.
      (true, false, true, RecapVoiceMode.recordOnly),
      (true, true, false, RecapVoiceMode.liveOnly),
      (true, true, true, RecapVoiceMode.hybrid),
    ];

    for (final (
          bool liveReady,
          bool canRecord,
          bool hasServerStt,
          RecapVoiceMode want,
        )
        in cases) {
      test(
        'liveReady=$liveReady canRecord=$canRecord hasServerStt=$hasServerStt → $want',
        () {
          expect(
            resolveVoiceMode(
              liveReady: liveReady,
              canRecordWhileListening: canRecord,
              hasServerStt: hasServerStt,
            ),
            want,
          );
        },
      );
    }
  });

  group('ScriptedLiveTranscriber', () {
    test('어절을 순서대로 누적해서 흘린다', () {
      fakeAsync((FakeAsync async) {
        final ScriptedLiveTranscriber transcriber = ScriptedLiveTranscriber(
          '며느리가 방귀를 참다가',
          wordInterval: const Duration(milliseconds: 100),
        );
        final List<LiveTranscript> received = <LiveTranscript>[];
        transcriber.listen().listen(received.add);

        async.elapse(const Duration(milliseconds: 350));

        expect(received.map((LiveTranscript t) => t.text), <String>[
          '며느리가',
          '며느리가 방귀를',
          '며느리가 방귀를 참다가',
        ]);

        transcriber.dispose();
      });
    });

    test('마지막에 isFinal true가 정확히 한 번 오고 스트림이 닫힌다', () {
      fakeAsync((FakeAsync async) {
        final ScriptedLiveTranscriber transcriber = ScriptedLiveTranscriber(
          '하나 둘 셋',
          wordInterval: const Duration(milliseconds: 100),
        );
        final List<LiveTranscript> received = <LiveTranscript>[];
        bool closed = false;
        transcriber.listen().listen(received.add, onDone: () => closed = true);

        async.elapse(const Duration(milliseconds: 350));

        expect(received.where((LiveTranscript t) => t.isFinal).length, 1);
        expect(received.last.isFinal, isTrue);
        expect(closed, isTrue);

        transcriber.dispose();
      });
    });

    test('dispose() 후 타이머가 남지 않는다', () {
      fakeAsync((FakeAsync async) {
        final ScriptedLiveTranscriber transcriber = ScriptedLiveTranscriber(
          '하나 둘 셋 넷 다섯',
          wordInterval: const Duration(milliseconds: 100),
        );
        transcriber.listen().listen((_) {});

        // 다 흐르기 전에 dispose - 타이머가 안 남아야 fakeAsync가 통과한다.
        async.elapse(const Duration(milliseconds: 150));
        transcriber.dispose();

        // pending timer가 남아 있으면 아래에서 FakeAsync가 예외를 던진다.
        async.elapse(const Duration(seconds: 5));
      });
    });

    test('cancel()이 중간에 스트림을 끊는다', () {
      fakeAsync((FakeAsync async) {
        final ScriptedLiveTranscriber transcriber = ScriptedLiveTranscriber(
          '하나 둘 셋 넷 다섯',
          wordInterval: const Duration(milliseconds: 100),
        );
        final List<LiveTranscript> received = <LiveTranscript>[];
        bool closed = false;
        transcriber.listen().listen(received.add, onDone: () => closed = true);

        async.elapse(const Duration(milliseconds: 150));
        expect(received.length, 1);

        transcriber.cancel();
        async.flushMicrotasks();

        expect(closed, isTrue);
        expect(received.any((LiveTranscript t) => t.isFinal), isFalse);

        // cancel 이후 남은 시간이 흘러도 더 이상 결과가 오지 않아야 한다.
        async.elapse(const Duration(seconds: 5));
        expect(received.length, 1);

        transcriber.dispose();
      });
    });
  });

  group('NoopLiveTranscriber', () {
    test('initialize()는 false, listen()은 빈 스트림', () async {
      final NoopLiveTranscriber transcriber = NoopLiveTranscriber();

      expect(await transcriber.initialize(), isFalse);
      expect(await transcriber.listen().toList(), isEmpty);

      await transcriber.dispose();
    });
  });
}
