import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/features/play/domain/entities/play_session.dart';
import 'package:goodquestion/features/play/domain/repositories/play_repository.dart';
import 'package:goodquestion/features/play/presentation/views/play_view.dart';
import 'package:goodquestion/features/play/presentation/voice/mission_voice_recorder.dart';
import 'package:goodquestion/features/play/presentation/voice/story_audio_player.dart';

void main() {
  Future<void> pumpPlay(
    WidgetTester tester, {
    PlayRepository? repository,
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: PlayPage(
          sessionId: 'preview-session',
          characterName: '토리',
          question: '친구가 속상해할 때는 어떻게 하면 좋을까?',
          repository: repository,
          voiceRecorder: const _FakeVoiceRecorder(),
          audioPlayer: const _FakeAudioPlayer(),
        ),
      ),
    );
    // repository 가 있으면 resume() 이 끝날 때까지 한 프레임 더 필요합니다.
    // 데모 모드(테스트 대부분)는 동기 경로라 pump() 로 충분합니다.
    // STORY 내레이션처럼 스스로 다음 장면을 계속 부르는 반복 흐름은
    // settle: false 로 받아 호출부가 직접 pump 횟수를 제어합니다.
    if (repository != null && settle) await tester.pumpAndSettle();
  }

  testWidgets('좌측 캐릭터와 머리 우측의 한 문장 질문을 보여준다', (WidgetTester tester) async {
    await pumpPlay(tester);

    expect(find.text('토리'), findsOneWidget);
    expect(find.text('토리의 질문'), findsOneWidget);
    expect(find.text('친구가 속상해할 때는 어떻게 하면 좋을까?'), findsOneWidget);
    expect(find.text('질문을 듣고 있어요'), findsOneWidget);
    expect(find.text('질문이 끝나면 마이크가 켜져요.'), findsOneWidget);
  });

  testWidgets('질문이 끝나면 마이크가 자동으로 켜진다', (WidgetTester tester) async {
    await pumpPlay(tester);

    expect(find.bySemanticsLabel('마이크 준비 중'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.bySemanticsLabel('마이크 켜짐'), findsOneWidget);
    expect(find.textContaining('잘 듣고 있어요'), findsOneWidget);
    expect(find.text('나는 이렇게 생각해요…'), findsOneWidget);
  });

  testWidgets('다시 듣기와 일시정지 동작이 명확하다', (WidgetTester tester) async {
    await pumpPlay(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    await tester.tap(find.byTooltip('다시 듣기'));
    await tester.pump();
    expect(find.text('질문을 듣고 있어요'), findsOneWidget);

    await tester.tap(find.byTooltip('잠시 멈춤'));
    await tester.pump();
    expect(find.text('이야기를 잠시 멈췄어요'), findsOneWidget);

    await tester.tap(find.text('계속 듣기'));
    await tester.pump();
    expect(find.text('이야기를 잠시 멈췄어요'), findsNothing);
  });

  testWidgets('나가기는 실수 방지를 위해 확인하고, 되돌릴 수 없다고 알려준다', (
    WidgetTester tester,
  ) async {
    await pumpPlay(tester);

    await tester.tap(find.byTooltip('나가기'));
    await tester.pumpAndSettle();
    expect(find.text('이야기를 그만할까요?'), findsOneWidget);
    // stop 은 되돌릴 수 없습니다 - "저장해 둘게요" 처럼 다시 들을 수 있는
    // 것으로 오해하게 하면 안 됩니다.
    expect(find.text('그만하면 다시 이어서 들을 수 없어요. 처음부터 다시 시작해야 해요.'), findsOneWidget);
  });

  testWidgets('그만하기를 확정하면 서버에도 stop 을 알린다', (WidgetTester tester) async {
    final _StopSpyRepository repository = _StopSpyRepository();
    await pumpPlay(tester, repository: repository);

    await tester.tap(find.byTooltip('나가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('그만하기'));
    await tester.pumpAndSettle();

    expect(repository.stoppedSessionId, 'preview-session');
  });

  testWidgets('무음(STT_EMPTY_TEXT)이면 화면을 안 바꾸고 마이크 옆에 안내만 하고, '
      '다시 말하면 재시도 횟수를 실어 보낸다', (WidgetTester tester) async {
    final _SttRetrySpyRepository repository = _SttRetrySpyRepository();
    await pumpPlay(tester, repository: repository);

    // 듣기 화면에 들어오면 마이크가 자동으로 녹음을 시작합니다.
    expect(find.byTooltip('말하기 완료'), findsOneWidget);

    // 첫 녹음은 무음으로 실패합니다.
    await tester.tap(find.byTooltip('말하기 완료'));
    await tester.pumpAndSettle();

    // 화면이 에러 화면으로 안 바뀌고, 마이크 옆에만 안내가 붙습니다.
    expect(find.text('잘 못 들었어요. 다시 말해 볼까?'), findsOneWidget);
    expect(find.byTooltip('나가기'), findsOneWidget); // 대화 화면 그대로

    // 다시 녹음합니다 - 이번에는 성공합니다.
    await tester.tap(find.byTooltip('눌러서 말하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('말하기 완료'));
    await tester.pumpAndSettle();

    expect(
      repository.lastSttRetryCount,
      1,
      reason: '무음으로 한 번 다시 말했으니 재시도 횟수 1이 실려 가야 합니다',
    );
  });

  testWidgets('녹음이 상한에 닿으면 자동으로 멈추고 지금까지 말한 것을 보낸다', (
    WidgetTester tester,
  ) async {
    final _AutoStopSpyRepository repository = _AutoStopSpyRepository();
    await pumpPlay(tester, repository: repository);

    // 듣기 화면에 들어오면 마이크가 자동으로 녹음을 시작한 상태입니다.
    expect(find.byTooltip('말하기 완료'), findsOneWidget);

    // 아무도 누르지 않은 채 상한까지 시간이 흐릅니다. 상한을 넘기면 업로드가
    // 통째로 413이라(웹 48kHz, 10MB 한도) 그 전에 끊어 보내야 합니다.
    await tester.pump(const Duration(seconds: maxRecordingSeconds));
    await tester.pumpAndSettle();

    expect(repository.transcribeCalls, 1, reason: '상한에서 자동으로 멈추고 변환을 요청해야 합니다');
    expect(repository.submittedTexts, isNotEmpty);
  });

  testWidgets('STORY(전개) 장면은 문장마다 내레이션 음성을 실제로 요청한다', (
    WidgetTester tester,
  ) async {
    final _StoryNarrationSpyRepository repository =
        _StoryNarrationSpyRepository();
    // 이 가짜는 장면이 끝나면 같은 장면을 또 돌려줘서 계속 내레이션합니다
    // (진짜 서버라면 다음 장면으로 넘어가겠지만, 여기서는 TTS 호출 자체만
    // 확인하면 되므로) - pumpAndSettle 을 쓰면 끝없이 돕니다. 필요한
    // 만큼만 직접 pump 합니다.
    await pumpPlay(tester, repository: repository, settle: false);

    // 첫 문장의 합성이 끝날 때까지 - 진짜 타이머(700ms 장면 종료 대기)는
    // 건드리지 않을 만큼만 마이크로태스크를 흘려보냅니다.
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(
      repository.synthesizedTexts,
      contains('첫 문장이에요.'),
      reason: '전개 장면도 대사처럼 문장마다 TTS를 실제로 불러야 합니다',
    );
    expect(
      repository.synthesizedCharacterNames.first,
      isNull,
      reason: '내레이션은 characterName 없이 불러야 내레이션 보이스가 나옵니다',
    );
  });

  testWidgets('첫 전개 장면이 끝나고 다음 장면으로 넘어가도 내레이션이 계속 나온다', (
    WidgetTester tester,
  ) async {
    final _StoryNarrationSpyRepository repository =
        _StoryNarrationSpyRepository()
          ..nextSceneOnComplete = const PlaySessionSnapshot(
            phase: PlayPhase.story,
            currentScene: PlayScene(
              sceneId: 'scene-2',
              sceneOrder: 2,
              sceneType: PlaySceneType.story,
              narrationSentences: <String>['그래서 며느리는 이렇게 말했어요.'],
            ),
          );
    await pumpPlay(tester, repository: repository, settle: false);

    // 첫 장면(문장 2개)이 다 끝나고, 다음 장면으로 넘어가기 전 700ms 대기까지
    // 지나갈 시간을 줍니다.
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 750));
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(
      repository.synthesizedTexts,
      containsAll(<String>['첫 문장이에요.', '두 번째 문장이에요.']),
      reason: '첫 장면 문장은 둘 다 불렀어야 합니다',
    );
    expect(
      repository.synthesizedTexts,
      contains('그래서 며느리는 이렇게 말했어요.'),
      reason: '두 번째 장면으로 넘어간 뒤에도 내레이션 TTS 를 계속 불러야 합니다',
    );
  });

  testWidgets('1280x720 범용 대화 템플릿 골든', (WidgetTester tester) async {
    await pumpPlay(tester);
    await tester.pump();

    await expectLater(
      find.byType(PlayPage),
      matchesGoldenFile('goldens/play_dialogue_template.png'),
    );
  });
}

class _FakeVoiceRecorder implements MissionVoiceRecorder {
  const _FakeVoiceRecorder();

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
  Future<void> dispose() async {}

  @override
  Future<void> playUrl(String url) async {}

  @override
  Future<void> stop() async {}
}

/// "그만하기"가 실제로 `POST /sessions/{id}/stop`(→ [stop])을 부르는지만
/// 확인하는 최소 가짜입니다. 그 외 메서드는 대화 화면이 뜨는 데 필요한
/// 만큼만 값을 돌려줍니다.
class _StopSpyRepository implements PlayRepository {
  String? stoppedSessionId;

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      const PlaySessionSnapshot(
        phase: PlayPhase.dialogue,
        currentScene: PlayScene(
          sceneId: 'scene-1',
          sceneOrder: 1,
          sceneType: PlaySceneType.dialogue,
          narrationSentences: <String>[],
          characterName: '토리',
          maxTurns: 4,
        ),
        openingText: '이럴 때는 어떻게 하면 좋을까?',
      );

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) =>
      resume(sessionId);

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(
        text: '이럴 때는 어떻게 하면 좋을까?',
        audioUrl: null,
        alreadyOpened: true,
      );

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async =>
      const PlayTranscription(text: '', confidence: null, lowConfidence: false);

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
  Future<void> stop(String sessionId) async {
    stoppedSessionId = sessionId;
  }
}

/// 첫 녹음은 422 `STT_EMPTY_TEXT`로 실패시키고, 그다음부터는 성공시킵니다.
/// 결국 제출되는 `sttRetryCount`를 [lastSttRetryCount]에 기록합니다.
class _SttRetrySpyRepository implements PlayRepository {
  int _transcribeCalls = 0;
  int? lastSttRetryCount;

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      const PlaySessionSnapshot(
        phase: PlayPhase.dialogue,
        currentScene: PlayScene(
          sceneId: 'scene-1',
          sceneOrder: 1,
          sceneType: PlaySceneType.dialogue,
          narrationSentences: <String>[],
          characterName: '토리',
          maxTurns: 4,
        ),
        openingText: '이럴 때는 어떻게 하면 좋을까?',
      );

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) =>
      resume(sessionId);

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(
        text: '이럴 때는 어떻게 하면 좋을까?',
        audioUrl: null,
        alreadyOpened: true,
      );

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async {
    _transcribeCalls++;
    if (_transcribeCalls == 1) {
      throw const ServerFailure(message: '무음이거나 인식 실패', code: 'STT_EMPTY_TEXT');
    }
    return const PlayTranscription(
      text: '나는 이렇게 생각해요',
      confidence: .9,
      lowConfidence: false,
    );
  }

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
  }) async {
    lastSttRetryCount = sttRetryCount;
    return const PlayTurnResult(
      characterText: null,
      characterAudioUrl: null,
      mission: null,
      sceneTransition: null,
    );
  }

  @override
  Future<void> stop(String sessionId) async {}
}

/// 녹음 상한 자동 종료 검증용. 변환 호출 수와 제출된 텍스트를 기록합니다.
class _AutoStopSpyRepository implements PlayRepository {
  int transcribeCalls = 0;
  final List<String> submittedTexts = <String>[];

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      const PlaySessionSnapshot(
        phase: PlayPhase.dialogue,
        currentScene: PlayScene(
          sceneId: 'scene-1',
          sceneOrder: 1,
          sceneType: PlaySceneType.dialogue,
          narrationSentences: <String>[],
          characterName: '토리',
          maxTurns: 4,
        ),
        openingText: '이럴 때는 어떻게 하면 좋을까?',
      );

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) =>
      resume(sessionId);

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(
        text: '이럴 때는 어떻게 하면 좋을까?',
        audioUrl: null,
        alreadyOpened: true,
      );

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async {
    transcribeCalls++;
    return const PlayTranscription(
      text: '오래오래 말한 내 생각이에요',
      confidence: .9,
      lowConfidence: false,
    );
  }

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
  }) async {
    submittedTexts.add(text);
    return const PlayTurnResult(
      characterText: null,
      characterAudioUrl: null,
      mission: null,
      sceneTransition: null,
    );
  }

  @override
  Future<void> stop(String sessionId) async {}
}

/// STORY(전개) 장면으로 들어가서 문장별 `synthesizeSpeech` 호출을 기록합니다.
class _StoryNarrationSpyRepository implements PlayRepository {
  final List<String> synthesizedTexts = <String>[];
  final List<String?> synthesizedCharacterNames = <String?>[];

  /// 장면 하나가 끝났을 때(=completeStoryScene 호출) 다음으로 돌려줄 장면.
  /// null 이면 같은 장면을 반복합니다(무한 루프 방지는 호출부의 pump 횟수가
  /// 책임짐). 두 번째 장면부터 내레이션이 안 나온다는 버그를 재현하려면
  /// 이걸 채워서 서로 다른 장면으로 실제로 넘어가게 합니다.
  PlaySessionSnapshot? nextSceneOnComplete;

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      const PlaySessionSnapshot(
        phase: PlayPhase.story,
        currentScene: PlayScene(
          sceneId: 'scene-1',
          sceneOrder: 1,
          sceneType: PlaySceneType.story,
          narrationSentences: <String>['첫 문장이에요.', '두 번째 문장이에요.'],
        ),
      );

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) async =>
      nextSceneOnComplete ?? await resume(sessionId);

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(text: '', audioUrl: null, alreadyOpened: true);

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
    synthesizedCharacterNames.add(characterName);
    return const PlaySpeechAudio(audioUrl: 'stub://narration');
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
