import '../../../../core/error/exceptions.dart';
import '../../domain/entities/play_session.dart';

class PlaySessionDto {
  const PlaySessionDto._();

  static PlaySessionSnapshot fromResumeJson(Map<String, dynamic> json) {
    final Object? sessionValue = json['session'];
    if (sessionValue is! Map<String, dynamic>) {
      throw const ParseException('이어하기 응답에 세션 정보가 없습니다.');
    }
    return PlaySessionSnapshot(
      phase: _phase(sessionValue['phase']),
      currentScene: _scene(json['currentScene']),
      openingText: _messageText(json['lastCharacterMessage']),
      openingAudioUrl: _messageAudioUrl(json['lastCharacterMessage']),
    );
  }

  static PlaySessionSnapshot fromAdvanceJson(Map<String, dynamic> json) =>
      PlaySessionSnapshot(
        phase: _phase(json['phase']),
        currentScene: _scene(json['currentScene']),
        openingText: _messageText(json['openingMessage']),
        openingAudioUrl: _messageAudioUrl(json['openingMessage']),
      );

  static PlayPhase _phase(Object? value) => switch (value) {
    'STORY' => PlayPhase.story,
    'DIALOGUE' => PlayPhase.dialogue,
    'POST_ACTIVITY' => PlayPhase.postActivity,
    'ENDED' => PlayPhase.ended,
    _ => throw ParseException('알 수 없는 재생 단계입니다: $value'),
  };

  static PlayScene? _scene(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      throw const ParseException('장면 응답 형식이 올바르지 않습니다.');
    }
    final String? sceneId = value['sceneId'] as String?;
    final num? sceneOrder = value['sceneOrder'] as num?;
    final String? sceneType = value['sceneType'] as String?;
    if (sceneId == null || sceneOrder == null || sceneType == null) {
      throw const ParseException('장면 식별 정보가 없습니다.');
    }
    final Object? sentencesValue = value['narrationSentences'];
    final List<String> sentences = sentencesValue is List
        ? sentencesValue.whereType<String>().toList(growable: false)
        : const <String>[];
    return PlayScene(
      sceneId: sceneId,
      sceneOrder: sceneOrder.toInt(),
      sceneType: switch (sceneType) {
        'STORY' => PlaySceneType.story,
        'DIALOGUE' => PlaySceneType.dialogue,
        _ => throw ParseException('알 수 없는 장면 종류입니다: $sceneType'),
      },
      narrationSentences: sentences,
      imageUrl: value['imageUrl'] as String?,
      characterName: value['characterName'] as String?,
      maxTurns: (value['maxTurns'] as num?)?.toInt(),
    );
  }

  static String? _messageText(Object? value) =>
      value is Map<String, dynamic> ? value['text'] as String? : null;

  static String? _messageAudioUrl(Object? value) =>
      value is Map<String, dynamic> ? value['audioUrl'] as String? : null;
}
