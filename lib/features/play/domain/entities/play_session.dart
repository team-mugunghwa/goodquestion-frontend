enum PlayPhase { story, dialogue, postActivity, ended }

enum PlaySceneType { story, dialogue }

enum PlayMissionType { problemSolving, perspectiveShift }

enum PlaySpeaker { child, character, system }

enum PlayTransitionTarget { scene, postActivity, completed }

class PlayMessage {
  const PlayMessage({
    required this.messageId,
    required this.speaker,
    required this.turnOrder,
    required this.text,
    this.sttLowConfidence = false,
  });

  final String messageId;
  final PlaySpeaker speaker;
  final int turnOrder;
  final String text;
  final bool sttLowConfidence;
}

class PlayOpeningMessage {
  const PlayOpeningMessage({
    required this.text,
    required this.audioUrl,
    required this.alreadyOpened,
  });

  final String text;
  final String? audioUrl;
  final bool alreadyOpened;
}

class PlaySpeechAudio {
  const PlaySpeechAudio({required this.audioUrl});

  final String audioUrl;
}

class PlayTranscription {
  const PlayTranscription({
    required this.text,
    required this.confidence,
    required this.lowConfidence,
    String? rawText,
  }) : rawText = rawText ?? text;

  final String text;

  /// 벤더가 돌려준 원문. 서버가 이야기 어휘 오인식을 교정해 내려주므로([text]),
  /// 발화 제출의 sttRawText에는 **이 값을** 되올린다 - text를 되올리면 교정
  /// 전에 실제로 무엇이 인식됐는지가 유실된다. 서버가 아직 rawText를 안 주면
  /// text와 같다.
  final String rawText;

  final double? confidence;
  final bool lowConfidence;
}

class PlaySceneTransition {
  const PlaySceneTransition({
    required this.next,
    this.nextSceneId,
    this.nextSceneOrder,
    this.nextSceneType,
    this.closingReason,
    this.resultImageUrl,
  });

  final PlayTransitionTarget next;
  final String? nextSceneId;
  final int? nextSceneOrder;
  final PlaySceneType? nextSceneType;
  final String? closingReason;
  final String? resultImageUrl;
}

class PlayMissionQuestion {
  const PlayMissionQuestion({required this.key, required this.label});

  final String key;
  final String label;
}

class PlayMissionCard {
  const PlayMissionCard({
    required this.key,
    required this.label,
    this.imageUrl,
    this.template,
  });

  final String key;
  final String label;
  final String? imageUrl;
  final String? template;
}

class PlayMission {
  const PlayMission({
    required this.missionId,
    required this.missionType,
    required this.title,
    required this.description,
    required this.questions,
    required this.cards,
  });

  final String missionId;
  final PlayMissionType missionType;
  final String title;
  final String description;
  final List<PlayMissionQuestion> questions;
  final List<PlayMissionCard> cards;
}

enum PlayResponseMode { normal, guided, closing }

/// 서버 `AnalysisResponse`. 캐릭터 표정·태도 연출의 유일한 트리거다 —
/// 프런트가 발화 내용을 자체 해석하지 않는다(이야기 전개 가이드 3.0절 4번).
class PlayAnalysis {
  const PlayAnalysis({
    this.childIntent,
    this.mainPoint,
    this.detectedElements = const <String>[],
    this.utteranceValidity,
  });

  final String? childIntent;
  final String? mainPoint;

  /// 이번 발화에서 확인된 사고 요소(`DetectedElement.type`). 근거 문구는 연출에 쓰지 않아 버린다.
  final List<String> detectedElements;

  /// `VALID` / `SHORT` / `UNCLEAR` / `OFF_TOPIC` / `PLAYFUL`
  final String? utteranceValidity;
}

/// 서버 `ProgressResponse`.
class PlayProgress {
  const PlayProgress({
    this.mode,
    this.accumulatedElements = const <String>[],
    this.missingElements = const <String>[],
    this.turnCount = 0,
    this.maxTurns = 0,
    this.guidanceTarget,
  });

  final PlayResponseMode? mode;

  /// 현재 장면에서 지금까지 채운 요소. **이번 턴이 반영된 뒤의 값**이다.
  final List<String> accumulatedElements;
  final List<String> missingElements;
  final int turnCount;
  final int maxTurns;

  /// GUIDED이거나 약한 유도(soft-cue) 턴일 때만 값이 있다.
  final String? guidanceTarget;

  bool get isClosing => mode == PlayResponseMode.closing;
}

class PlayTurnResult {
  const PlayTurnResult({
    required this.characterText,
    required this.characterAudioUrl,
    required this.mission,
    required this.sceneTransition,
    this.closingReactionText,
    this.closingReactionAudioUrl,
    this.analysis,
    this.progress,
  });

  final String? characterText;
  final String? characterAudioUrl;
  final PlayMission? mission;
  final PlaySceneTransition? sceneTransition;
  final String? closingReactionText;
  final String? closingReactionAudioUrl;

  /// 표정 연출 입력. 서버가 항상 내려주지만, 안전 개입 턴 등에서 비어 올 수 있어 nullable로 둔다.
  final PlayAnalysis? analysis;
  final PlayProgress? progress;

  bool get hasSceneTransition => sceneTransition != null;
}

/// 내레이션 음성에서 문장 하나가 차지하는 구간(초). [index]는
/// [PlayScene.narrationSentences]의 순서와 같습니다.
class PlayNarrationTiming {
  const PlayNarrationTiming({
    required this.index,
    required this.start,
    required this.end,
  });

  final int index;
  final double start;
  final double end;
}

class PlayScene {
  const PlayScene({
    required this.sceneId,
    required this.sceneOrder,
    required this.sceneType,
    required this.narrationSentences,
    this.imageUrl,
    this.characterName,
    this.maxTurns,
    this.narrationAudioUrl,
    this.narrationTimings = const <PlayNarrationTiming>[],
  });

  final String sceneId;
  final int sceneOrder;
  final PlaySceneType sceneType;
  final List<String> narrationSentences;
  final String? imageUrl;
  final String? characterName;
  final int? maxTurns;

  /// 사전 렌더된 내레이션 음성. null이면 음성 없이 글자수 타이머로 넘깁니다.
  final String? narrationAudioUrl;

  /// 문장별 실측 구간. [narrationAudioUrl]이 있을 때만 값이 있습니다.
  ///
  /// 이게 없으면 글자수 비례로 추정할 수밖에 없는데, 그러면 소리와 자막이
  /// 어긋납니다 - 장면 1은 음성이 20초인데 추정값은 8.4초입니다.
  final List<PlayNarrationTiming> narrationTimings;

  /// 실측 타이밍으로 재생 가능한 상태인지. 음성만 있고 타이밍이 비면
  /// 문장을 언제 넘길지 알 수 없으므로 기존 타이머 경로를 씁니다.
  bool get hasTimedNarration =>
      narrationAudioUrl != null &&
      narrationAudioUrl!.isNotEmpty &&
      narrationTimings.length == narrationSentences.length &&
      narrationSentences.isNotEmpty;
}

class PlaySessionSnapshot {
  const PlaySessionSnapshot({
    required this.phase,
    required this.currentScene,
    this.openingText,
    this.openingAudioUrl,
    this.mission,
    this.messages = const <PlayMessage>[],
  });

  final PlayPhase phase;
  final PlayScene? currentScene;
  final String? openingText;
  final String? openingAudioUrl;
  final PlayMission? mission;
  final List<PlayMessage> messages;
}
