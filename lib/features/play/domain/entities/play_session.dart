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

class PlayTurnResult {
  const PlayTurnResult({
    required this.characterText,
    required this.characterAudioUrl,
    required this.mission,
    required this.sceneTransition,
    this.closingReactionText,
    this.closingReactionAudioUrl,
  });

  final String? characterText;
  final String? characterAudioUrl;
  final PlayMission? mission;
  final PlaySceneTransition? sceneTransition;
  final String? closingReactionText;
  final String? closingReactionAudioUrl;

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
  });

  final String sceneId;
  final int sceneOrder;
  final PlaySceneType sceneType;
  final List<String> narrationSentences;
  final String? imageUrl;
  final String? characterName;
  final int? maxTurns;
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
