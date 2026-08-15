import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/features/play/domain/entities/play_session.dart';
import 'package:goodquestion/features/play/domain/repositories/play_repository.dart';
import 'package:goodquestion/features/play/presentation/views/play_view.dart';
import 'package:goodquestion/features/play/presentation/voice/mission_voice_recorder.dart';
import 'package:goodquestion/features/play/presentation/voice/story_audio_player.dart';

/// AI 실패 코드별 안내.
///
/// 백엔드가 원인별로 갈라 준 코드(백엔드 #68)를 화면이 몰라서 전부 "서버 오류"로
/// 뭉개고 있었다. 특히 413은 같은 녹음을 다시 보내면 또 실패하므로 "다시
/// 해보세요"로 안내하면 아이가 계속 막힌다.
void main() {
  Future<void> pump(WidgetTester tester, PlayRepository repository) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: PlayPage(
          sessionId: 'test-session',
          repository: repository,
          voiceRecorder: const _FakeRecorder(),
          audioPlayer: const _FakeAudioPlayer(),
        ),
      ),
    );
  }

  /// 첫 대사 재생이 끝나 마이크가 켜질 때까지. 대화 장면은 녹음 카운트다운
  /// 주기 타이머가 돌아 pumpAndSettle 이 정착하지 않으므로 직접 굴립니다.
  Future<void> reachListening(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('녹음이 너무 길면 짧게 말하라고 안내하고 화면은 그대로 둔다', (WidgetTester tester) async {
    await pump(
      tester,
      _SttFailureRepository(
        const ServerFailure(message: '서버 오류가 발생했습니다.', code: 'AUDIO_TOO_LARGE'),
      ),
    );
    await reachListening(tester);

    await tester.tap(find.byTooltip('말하기 완료'));
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }

    expect(find.text('말이 조금 길었어요. 짧게 말해 볼까?'), findsOneWidget);
    expect(find.text('서버 오류가 발생했습니다.'), findsNothing);
    expect(find.byTooltip('나가기'), findsOneWidget, reason: '대화 화면이 그대로 남아야 합니다');
  });

  for (final String code in <String>[
    'AI_RATE_LIMITED',
    'AI_UPSTREAM_ERROR',
    'AI_UNAVAILABLE',
  ]) {
    testWidgets('$code 는 잠시 뒤 다시 하라고 안내한다', (WidgetTester tester) async {
      await pump(
        tester,
        _SttFailureRepository(
          ServerFailure(message: '서버 오류가 발생했습니다.', code: code),
        ),
      );
      await reachListening(tester);

      await tester.tap(find.byTooltip('말하기 완료'));
      for (int i = 0; i < 6; i++) {
        await tester.pump();
      }

      expect(find.text('지금은 잘 안 들려요. 잠시 뒤에 다시 말해 볼까?'), findsOneWidget);
      expect(find.text('서버 오류가 발생했습니다.'), findsNothing);
      expect(find.byTooltip('나가기'), findsOneWidget);
    });
  }
}

/// 대화 장면에서 STT가 주어진 실패로 떨어지는 저장소.
class _SttFailureRepository implements PlayRepository {
  _SttFailureRepository(this.failure);

  final Failure failure;

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      const PlaySessionSnapshot(
        phase: PlayPhase.dialogue,
        currentScene: PlayScene(
          sceneId: 'scene-3',
          sceneOrder: 3,
          sceneType: PlaySceneType.dialogue,
          narrationSentences: <String>[],
          characterName: '토리',
          maxTurns: 4,
        ),
        openingText: '어떻게 하면 좋을까?',
      );

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) =>
      resume(sessionId);

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(
        text: '어떻게 하면 좋을까?',
        audioUrl: null,
        alreadyOpened: true,
      );

  @override
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) async => const <PlayMessage>[];

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async =>
      throw failure;

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async => const PlaySpeechAudio(audioUrl: 'stub://audio');

  @override
  Future<PlayTurnResult> submitUtterance(
    String sessionId, {
    required String text,
    String? missionId,
    String? sttRawText,
    double? sttConfidence,
    int sttRetryCount = 0,
    String? idempotencyKey,
  }) async => const PlayTurnResult(
    characterText: null,
    characterAudioUrl: null,
    mission: null,
    sceneTransition: null,
  );

  @override
  Future<void> stop(String sessionId) async {}
}

class _FakeRecorder implements MissionVoiceRecorder {
  const _FakeRecorder();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> start() async => true;

  @override
  Future<Uint8List?> stop() async => Uint8List.fromList(<int>[1, 2, 3]);
}

class _FakeAudioPlayer implements StoryAudioPlayer {
  const _FakeAudioPlayer();

  @override
  Future<void> playUrl(String url) async {}

  @override
  bool get canResume => false;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
