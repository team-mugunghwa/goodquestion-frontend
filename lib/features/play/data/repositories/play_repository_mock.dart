import 'dart:typed_data';

import '../../domain/entities/play_session.dart';
import '../../domain/repositories/play_repository.dart';

/// 백엔드가 준비되기 전까지 "방귀 뀌는 며느리" 한 편을 처음부터 끝까지
/// 진행할 수 있게 해 주는 목업입니다.
///
/// `lib/main_play_preview.dart`·`lib/main_mission_preview.dart` 의 미리보기
/// Repository 들은 화면 하나(대화 한 장면, 미션 한 번)만 보여 주도록 만들어져
/// 있어서 그대로 재사용할 수 없었습니다. 이 목업은 그 둘의 방식을 그대로
/// 따르되, **장면 4개(이야기→대화→이야기→대화)를 순서대로 넘기며** 마지막에는
/// 말하기 후 활동(recap)으로 이어지는 상태까지 만듭니다.
///
/// [StoryRepositoryMock.startSession] 은 `mock-session-<storyId>` 를 돌려주고,
/// 실제 서버라면 세션이 없을 때 에러를 내야 하지만 여기서는 **어떤
/// sessionId 든 받아 줍니다.** 데모에서는 새로고침·다른 이야기 진입마다
/// sessionId 검증에 걸려 "세션 없음" 화면을 보게 하는 게 오히려 방해입니다.
class PlayRepositoryMock implements PlayRepository {
  PlayRepositoryMock({this.latency = const Duration(milliseconds: 500)});

  final Duration latency;

  /// sessionId 별 진행 상태. lazySingleton 이라 앱이 켜져 있는 동안 유지되고,
  /// 같은 이야기를 다시 시작하면(=sessionId 가 같으면) 마지막으로 도달한
  /// 장면부터 이어집니다. 완전히 처음부터 다시 보려면 앱을 새로고침하세요.
  final Map<String, _MockSessionState> _sessions =
      <String, _MockSessionState>{};

  _MockSessionState _stateOf(String sessionId) =>
      _sessions.putIfAbsent(sessionId, _MockSessionState.new);

  /// [transcribeAudio] 가 돌려줄 문장을 순서대로 고르기 위한 카운터입니다.
  /// 세션별로 나눌 필요는 없습니다 — 어차피 진짜 음성 내용이 아니라
  /// 데모가 자연스럽게 흘러가도록 돌아가며 보여 주는 대사일 뿐입니다.
  int _transcriptionCount = 0;

  // ---- 장면 정의 ----
  // 실제 스토리 카탈로그(assets/dummy/story_details.json 의 storyId 11)와
  // 같은 도입부를 써서 "시작하기"부터 자연스럽게 이어지게 했습니다.
  static const PlayScene _scene1Story = PlayScene(
    sceneId: 'mock-scene-1',
    sceneOrder: 1,
    sceneType: PlaySceneType.story,
    narrationSentences: <String>[
      '옛날 어느 마을에 방귀를 꾹 참는 며느리가 살았어요.',
      '참고 참다가 얼굴이 점점 노래졌대요.',
      '오늘은 며느리에게 무슨 일이 있었는지 함께 들어볼 참이에요.',
    ],
  );

  static const PlayScene _scene2Dialogue = PlayScene(
    sceneId: 'mock-scene-2',
    sceneOrder: 2,
    sceneType: PlaySceneType.dialogue,
    narrationSentences: <String>[],
    imageUrl: 'assets/images/dialogue/banggui_dialogue_1.png',
    characterName: '방귀쟁이 며느리',
    maxTurns: 3,
  );

  static const PlayScene _scene3Story = PlayScene(
    sceneId: 'mock-scene-3',
    sceneOrder: 3,
    sceneType: PlaySceneType.story,
    narrationSentences: <String>[
      '며느리는 네 응원 덕분에 용기를 얻었어요.',
      '이제 방귀가 나와도 웃으며 넘길 수 있게 되었답니다.',
      '마을 사람들도 며느리와 함께 소리 내어 웃었어요.',
    ],
  );

  static const PlayScene _scene4Dialogue = PlayScene(
    sceneId: 'mock-scene-4',
    sceneOrder: 4,
    sceneType: PlaySceneType.dialogue,
    narrationSentences: <String>[],
    imageUrl: 'assets/images/dialogue/banggui_dialogue_1.png',
    characterName: '방귀쟁이 며느리',
    maxTurns: 2,
  );

  static const PlayMission _mission = PlayMission(
    missionId: 'mock-mission-1',
    missionType: PlayMissionType.problemSolving,
    title: '며느리에게 용기를 주는 말 찾기',
    description: '며느리가 부끄러워하지 않도록 세 가지 생각을 모아 보세요.',
    questions: <PlayMissionQuestion>[
      PlayMissionQuestion(key: 'reason', label: '왜 방귀가 나왔을까요?'),
      PlayMissionQuestion(key: 'feeling', label: '며느리는 어떤 기분이었을까요?'),
      PlayMissionQuestion(key: 'idea', label: '며느리에게 어떤 말을 해 주고 싶나요?'),
    ],
    cards: <PlayMissionCard>[],
  );

  static const List<String> _demoChildAnswers = <String>[
    '방귀는 부끄러운 게 아니라 그냥 몸에서 나오는 자연스러운 거예요.',
    '며느리는 사람들 앞이라 많이 창피했을 것 같아요.',
    '괜찮아요, 누구나 그럴 수 있어요! 라고 말해 주고 싶어요.',
    '오늘 이야기에서 며느리가 웃게 된 게 제일 기억에 남아요.',
  ];

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async {
    await Future<void>.delayed(latency);
    return _snapshotFor(_stateOf(sessionId));
  }

  PlaySessionSnapshot _snapshotFor(_MockSessionState state) {
    switch (state.stage) {
      case 0:
        return const PlaySessionSnapshot(
          phase: PlayPhase.story,
          currentScene: _scene1Story,
        );
      case 1:
        return PlaySessionSnapshot(
          phase: PlayPhase.dialogue,
          currentScene: _scene2Dialogue,
          openingText: '나는 방귀 소리 때문에 사람들 앞에서 너무 창피했어. 나는 어떻게 하면 좋을까?',
          mission: state.missionPending ? _mission : null,
        );
      case 2:
        return const PlaySessionSnapshot(
          phase: PlayPhase.story,
          currentScene: _scene3Story,
        );
      case 3:
        return const PlaySessionSnapshot(
          phase: PlayPhase.dialogue,
          currentScene: _scene4Dialogue,
          openingText: '네 덕분에 오늘 정말 행복했어. 오늘 이야기에서 어떤 점이 가장 기억에 남니?',
        );
      default:
        return const PlaySessionSnapshot(
          phase: PlayPhase.postActivity,
          currentScene: null,
        );
    }
  }

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) async {
    await Future<void>.delayed(latency);
    final _MockSessionState state = _stateOf(sessionId);
    // 이야기 장면(내레이션)이 끝났을 때만 불립니다. 다음 대화 장면으로
    // 넘어가고, 해당 장면의 턴 카운트는 새로 시작합니다.
    if (state.stage == 0 || state.stage == 2) {
      state.stage++;
      state.turnCount = 0;
    }
    return _snapshotFor(state);
  }

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async {
    await Future<void>.delayed(latency);
    final PlaySessionSnapshot snapshot = _snapshotFor(_stateOf(sessionId));
    return PlayOpeningMessage(
      text: snapshot.openingText ?? '',
      audioUrl: null,
      alreadyOpened: true,
    );
  }

  @override
  Future<PlayMission?> currentMission(String sessionId) async =>
      _stateOf(sessionId).missionPending ? _mission : null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    // 진짜 음성 인식 서버가 없으니, 데모가 계속 진행되도록 이야기 순서에
    // 맞는 그럴듯한 문장을 돌아가며 돌려줍니다. 실제로 녹음된 소리는
    // 사용하지 않습니다.
    final String text =
        _demoChildAnswers[_transcriptionCount++ % _demoChildAnswers.length];
    return PlayTranscription(text: text, confidence: .95, lowConfidence: false);
  }

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    required String characterName,
  }) async {
    // 실제 음성 파일을 만들 수 없어 빈 URL을 돌려줍니다. `PlayPage` 는 재생할
    // 오디오가 없으면(빈 문자열) 자막을 읽는 시간만큼 기다렸다가 다음
    // 문장으로 넘어가므로 화면이 죽지 않습니다.
    return const PlaySpeechAudio(audioUrl: '');
  }

  @override
  Future<PlayTurnResult> submitUtterance(
    String sessionId, {
    required String text,
    String? missionId,
    String? sttRawText,
    double? sttConfidence,
    int sttRetryCount = 0,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final _MockSessionState state = _stateOf(sessionId);

    if (state.stage == 1) {
      if (missionId != null) {
        // 미션에 답했으니 다음 이야기 장면으로 넘어갑니다.
        state.missionPending = false;
        state.stage = 2;
        state.turnCount = 0;
        return const PlayTurnResult(
          characterText: '정말 멋진 생각이야! 네 마음 덕분에 힘이 났어.',
          characterAudioUrl: null,
          mission: null,
          sceneTransition: PlaySceneTransition(
            next: PlayTransitionTarget.scene,
            nextSceneType: PlaySceneType.story,
          ),
        );
      }
      // 미션을 내주기 전에 대화를 두 턴 주고받아 "쌓이는 대화" 느낌을 줍니다.
      state.turnCount++;
      if (state.turnCount == 1) {
        return const PlayTurnResult(
          characterText: '정말 그렇게 생각해? 왜 그렇게 생각했는지 더 말해 줄래?',
          characterAudioUrl: null,
          mission: null,
          sceneTransition: null,
        );
      }
      state.missionPending = true;
      return const PlayTurnResult(
        characterText: '네 이야기를 들으니 도움이 될 것 같아. 함께 방법을 찾아볼까?',
        characterAudioUrl: null,
        mission: _mission,
        sceneTransition: null,
      );
    }

    if (state.stage == 3) {
      // 마지막 대화 장면도 두 턴을 주고받은 뒤 말하기 후 활동으로 넘어갑니다.
      state.turnCount++;
      if (state.turnCount == 1) {
        return const PlayTurnResult(
          characterText: '정말 다행이야. 그때 기분이 어땠는지 조금 더 말해 줄래?',
          characterAudioUrl: null,
          mission: null,
          sceneTransition: null,
        );
      }
      state.stage = 4;
      return const PlayTurnResult(
        characterText: '그 마음, 나도 오래오래 기억할게. 이야기를 끝까지 들어줘서 고마워!',
        characterAudioUrl: null,
        mission: null,
        sceneTransition: PlaySceneTransition(
          next: PlayTransitionTarget.postActivity,
        ),
      );
    }

    // 이야기 장면 중에는 대화창이 열리지 않으므로 이 경로는 정상 흐름에서
    // 호출되지 않습니다. 방어적으로 안전한 값을 돌려줍니다.
    return const PlayTurnResult(
      characterText: null,
      characterAudioUrl: null,
      mission: null,
      sceneTransition: null,
    );
  }
}

/// sessionId 하나가 지금 어느 장면(stage)에 있는지, 미션을 기다리는 중인지를
/// 들고 있습니다.
///
/// stage 값: 0=이야기1, 1=대화1(미션 포함), 2=이야기2, 3=대화2, 4=완료(recap 이동).
class _MockSessionState {
  int stage = 0;
  int turnCount = 0;
  bool missionPending = false;
}
