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
    this.videoUrl,
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

  /// 장면 배경 영상(무음). 이미지를 대체하지 않고 위에 얹는다 — null이거나
  /// 재생에 실패하면 [imageUrl]로 떨어진다. 반복 여부는 별도 플래그가 아니라
  /// [sceneType]이 정한다(STORY 1회, DIALOGUE 반복).
  /// → 팀원공유 `전달_장면영상과_추가요청.md` §2-1
  final String? videoUrl;
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
    this.storyId,
    this.openingText,
    this.openingAudioUrl,
    this.openingAudioTimings = const <PlayAudioTiming>[],
    this.mission,
    this.messages = const <PlayMessage>[],
  });

  final PlayPhase phase;
  final PlayScene? currentScene;

  /// 이 세션이 어느 이야기인지. `SessionResponse.storyId` 에서 옵니다 —
  /// 이어하기 응답에만 있고 **장면 전환 응답에는 없습니다**(`SceneAdvanceResponse`).
  /// 그래서 장면이 넘어가면 `null` 이 되고, 화면이 처음 받은 값을 들고
  /// 있어야 합니다. → `docs/API.md` `SessionResponse`
  ///
  /// 쓰는 곳은 하나뿐입니다 — 이야기가 끝난 뒤 완료 화면이 후속 자유 대화로
  /// 넘어갈 때(`AppRoutes.freeTalkOf`).
  final String? storyId;
  final String? openingText;
  final String? openingAudioUrl;
  final List<PlayAudioTiming> openingAudioTimings;
  final PlayMission? mission;
  final List<PlayMessage> messages;
}

// ─────────────────────────────────────────────────────────
// 말하기 후 활동 (`/api/sessions/{id}/post-activity`)
// → `docs/API.md` 2.10 · `docs/이야기_전개_가이드.md` 3.7
// ─────────────────────────────────────────────────────────

/// 순서 맞추기 카드 한 장. **그림 경로는 서버가 주지 않습니다** - 화면이
/// [cardId] 의 번호로 프런트 에셋을 찾습니다.
class PlayPostActivityCard {
  const PlayPostActivityCard({required this.cardId, required this.text});

  final String cardId;

  /// 장면 설명. 화면에는 그리지 않고 스크린리더 라벨로만 씁니다 - 글로
  /// 보여 주면 그림만 보고 맞추는 활동에서 정답이 새어 나갑니다.
  final String text;
}

/// `POST .../post-activity/start` 응답.
class PlayPostActivityStart {
  const PlayPostActivityStart({
    required this.cards,
    required this.attemptCount,
  });

  /// **서버가 이미 섞어서 준 순서**입니다(세션마다 시드 고정). 프런트가 또
  /// 섞으면 다시 들어올 때마다 배치가 달라집니다.
  final List<PlayPostActivityCard> cards;

  final int attemptCount;
}

/// `POST .../post-activity/order` 응답. **정답 판정은 서버만 합니다.**
class PlayCardOrderResult {
  const PlayCardOrderResult({
    required this.correct,
    this.retellingKeywords = const <String>[],
  });

  final bool correct;

  /// 맞혔을 때만 값이 있습니다(오답이면 서버가 null → 빈 목록). 순서를 맞히기
  /// 전에는 화면에 내보내면 안 됩니다 - 낱말이 곧 순서의 단서입니다.
  final List<String> retellingKeywords;
}

class PlayStardust {
  const PlayStardust({required this.earned, required this.balance});

  final int earned;
  final int balance;
}

class PlayUnlockedItem {
  const PlayUnlockedItem({
    required this.itemId,
    required this.name,
    this.thumbnailUrl,
  });

  final String itemId;
  final String name;
  final String? thumbnailUrl;
}

/// `POST .../post-activity/retelling` 응답. 이 호출 하나로 **세션 완료 ·
/// 별가루 지급 · 아이템 해금**이 끝납니다.
class PlayRetellingResult {
  const PlayRetellingResult({
    required this.sessionStatus,
    this.completedAt,
    this.stardust,
    this.unlockedItems = const <PlayUnlockedItem>[],
  });

  final String sessionStatus;
  final DateTime? completedAt;

  /// 지급 내역(`breakdown`)은 아이 화면에서 쓰지 않아 받은 개수와 잔액만
  /// 들고 옵니다.
  final PlayStardust? stardust;
  final List<PlayUnlockedItem> unlockedItems;
}
