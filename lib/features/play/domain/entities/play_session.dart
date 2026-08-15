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

/// 사전 렌더 음성 안에서 문장 하나가 차지하는 구간(초).
///
/// 서버가 문장마다 따로 합성해 이어 붙이며 잰 **실측값**이다 — 글자수 비례
/// 추정이 아니다. 파일 하나를 재생하면서 재생 위치가 [start]를 지날 때 자막을
/// [index] 문장으로 넘긴다.
class PlayAudioTiming {
  const PlayAudioTiming({
    required this.index,
    required this.start,
    required this.end,
  });

  final int index;
  final double start;
  final double end;
}

class PlayOpeningMessage {
  const PlayOpeningMessage({
    required this.text,
    required this.audioUrl,
    required this.alreadyOpened,
    this.audioTimings = const <PlayAudioTiming>[],
  });

  final String text;
  final String? audioUrl;
  final bool alreadyOpened;

  /// [audioUrl]의 문장별 실측 구간. 비어 있으면 문장별 합성으로 폴백한다.
  final List<PlayAudioTiming> audioTimings;
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
  });

  final String text;
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
    this.characterAudioTimings = const <PlayAudioTiming>[],
    this.closingReactionAudioTimings = const <PlayAudioTiming>[],
    this.analysis,
    this.progress,
  });

  final String? characterText;
  final String? characterAudioUrl;
  final PlayMission? mission;
  final PlaySceneTransition? sceneTransition;
  final String? closingReactionText;
  final String? closingReactionAudioUrl;
  final List<PlayAudioTiming> characterAudioTimings;
  final List<PlayAudioTiming> closingReactionAudioTimings;

  /// 표정 연출 입력. 서버가 항상 내려주지만, 안전 개입 턴 등에서 비어 올 수 있어 nullable로 둔다.
  final PlayAnalysis? analysis;
  final PlayProgress? progress;

  bool get hasSceneTransition => sceneTransition != null;
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
    this.narrationTimings = const <PlayAudioTiming>[],
  });

  final String sceneId;
  final int sceneOrder;
  final PlaySceneType sceneType;
  final List<String> narrationSentences;
  final String? imageUrl;
  final String? characterName;
  final int? maxTurns;

  /// 사전 렌더 내레이션. null이면 지금처럼 문장별 실시간 합성으로 읽는다.
  final String? narrationAudioUrl;
  final List<PlayAudioTiming> narrationTimings;
}

class PlaySessionSnapshot {
  const PlaySessionSnapshot({
    required this.phase,
    required this.currentScene,
    this.openingText,
    this.openingAudioUrl,
    this.openingAudioTimings = const <PlayAudioTiming>[],
    this.mission,
    this.messages = const <PlayMessage>[],
  });

  final PlayPhase phase;
  final PlayScene? currentScene;
  final String? openingText;
  final String? openingAudioUrl;
  final List<PlayAudioTiming> openingAudioTimings;
  final PlayMission? mission;
  final List<PlayMessage> messages;
}
