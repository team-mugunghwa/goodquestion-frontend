enum PlayPhase { story, dialogue, postActivity, ended }

enum PlaySceneType { story, dialogue }

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
  });

  final PlayPhase phase;
  final PlayScene? currentScene;
  final String? openingText;
  final String? openingAudioUrl;
}
