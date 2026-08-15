import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/features/play/domain/entities/play_session.dart';
import 'package:goodquestion/features/play/domain/repositories/play_repository.dart';
import 'package:goodquestion/features/play/presentation/views/play_view.dart';
import 'package:goodquestion/features/play/presentation/voice/mission_voice_recorder.dart';
import 'package:goodquestion/features/play/presentation/voice/story_audio_player.dart';

/// 사전 렌더 내레이션 음성과 AI 실패 코드 안내.
///
/// 서버가 채워 보내는데 화면이 안 쓰던 두 가지다 - 내레이션은 무음으로 흘렀고,
/// AI 실패는 전부 "서버 오류"로 뭉개졌다.
void main() {
  Future<void> pump(
    WidgetTester tester,
    PlayRepository repository, {
    bool settle = true,
  }) async {
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
          audioPlayer: _RecordingAudioPlayer.instance,
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  setUp(_RecordingAudioPlayer.instance.reset);

  /// 첫 대사 재생이 끝나 마이크가 켜질 때까지. 대화 장면은 녹음 카운트다운
  /// 주기 타이머가 돌아 pumpAndSettle 이 정착하지 않으므로 직접 굴립니다.
  Future<void> reachListening(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('사전 렌더 음성이 있으면 문장별 합성 대신 장면 음성을 한 번 튼다', (
    WidgetTester tester,
  ) async {
    final _NarrationRepository repository = _NarrationRepository();
    await pump(tester, repository, settle: false);
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(
      _RecordingAudioPlayer.instance.playedUrls,
      contains(contains('/tts/banggui/sc_banggui_01.mp3')),
      reason: '장면 음성 URL을 그대로 재생해야 합니다',
    );
    expect(
      repository.synthesizedTexts,
      isEmpty,
      reason: '사전 렌더가 있으면 문장별 TTS를 부르지 않아야 합니다',
    );
  });

  testWidgets('자막은 글자수가 아니라 실측 타이밍으로 넘어간다', (WidgetTester tester) async {
    // 첫 문장은 실측 6초인데 글자수 추정으로는 2.4초다. 3초 시점에 아직
    // 첫 문장이면 실측을 따르고 있다는 뜻이다.
    final _NarrationRepository repository = _NarrationRepository();
    await pump(tester, repository, settle: false);
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('짧은 첫 문장.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(
      find.text('짧은 첫 문장.'),
      findsOneWidget,
      reason: '실측 6초 구간이라 3초에는 아직 첫 문장이어야 합니다',
    );

    await tester.pump(const Duration(seconds: 4));
    expect(
      find.text('두 번째 문장이에요.'),
      findsOneWidget,
      reason: '6초를 넘기면 다음 문장으로 넘어가야 합니다',
    );
  });

  testWidgets('사전 렌더 음성이 없으면 기존 문장별 합성 경로를 쓴다', (
    WidgetTester tester,
  ) async {
    final _NarrationRepository repository = _NarrationRepository(
      withAudio: false,
    );
    await pump(tester, repository, settle: false);
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(repository.synthesizedTexts, contains('짧은 첫 문장.'));
  });

  testWidgets('녹음이 너무 길면 짧게 말하라고 안내하고 화면은 그대로 둔다', (
    WidgetTester tester,
  ) async {
    final _SttFailureRepository repository = _SttFailureRepository(
      const ServerFailure(message: '서버 오류가 발생했습니다.', code: 'AUDIO_TOO_LARGE'),
    );
    await pump(tester, repository, settle: false);
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
      final _SttFailureRepository repository = _SttFailureRepository(
        ServerFailure(message: '서버 오류가 발생했습니다.', code: code),
      );
      await pump(tester, repository, settle: false);
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

/// 재생한 URL을 기록하는 오디오 플레이어. PlayPage 가 위젯 트리 밖에서
/// 만들어 쓰므로 싱글턴으로 두고 테스트마다 초기화합니다.
class _RecordingAudioPlayer implements StoryAudioPlayer {
  _RecordingAudioPlayer._();

  static final _RecordingAudioPlayer instance = _RecordingAudioPlayer._();

  final List<String> playedUrls = <String>[];

  void reset() => playedUrls.clear();

  @override
  Future<void> playUrl(String url) async => playedUrls.add(url);

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

class _NarrationRepository implements PlayRepository {
  _NarrationRepository({this.withAudio = true});

  final bool withAudio;
  final List<String> synthesizedTexts = <String>[];

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      PlaySessionSnapshot(
        phase: PlayPhase.story,
        currentScene: PlayScene(
          sceneId: 'scene-1',
          sceneOrder: 1,
          sceneType: PlaySceneType.story,
          narrationSentences: const <String>['짧은 첫 문장.', '두 번째 문장이에요.'],
          narrationAudioUrl: withAudio ? '/tts/banggui/sc_banggui_01.mp3' : null,
          narrationTimings: withAudio
              ? const <PlayNarrationTiming>[
                  PlayNarrationTiming(index: 0, start: 0, end: 6),
                  PlayNarrationTiming(index: 1, start: 6, end: 10),
                ]
              : const <PlayNarrationTiming>[],
        ),
      );

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) =>
      resume(sessionId);

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(text: '', audioUrl: null, alreadyOpened: true);

  @override
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) async => const <PlayMessage>[];

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async =>
      const PlayTranscription(text: '', confidence: null, lowConfidence: false);

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async {
    synthesizedTexts.add(text);
    return const PlaySpeechAudio(audioUrl: 'stub://audio');
  }

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
