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
      mission: mission(json['exposedMission']),
      messages: _messages(json['messages']),
    );
  }

  static PlaySessionSnapshot fromAdvanceJson(Map<String, dynamic> json) =>
      PlaySessionSnapshot(
        phase: _phase(json['phase']),
        currentScene: _scene(json['currentScene']),
        openingText: _messageText(json['openingMessage']),
        openingAudioUrl: _messageAudioUrl(json['openingMessage']),
      );

  static PlayMission? mission(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      throw const ParseException('미션 응답 형식이 올바르지 않습니다.');
    }
    final String? missionId = value['missionId'] as String?;
    final String? missionType = value['missionType'] as String?;
    if (missionId == null || missionType == null) {
      throw const ParseException('미션 식별 정보가 없습니다.');
    }
    final Object? payloadValue = value['payload'];
    final Map<String, dynamic> payload = payloadValue is Map<String, dynamic>
        ? payloadValue
        : const <String, dynamic>{};
    return PlayMission(
      missionId: missionId,
      missionType: switch (missionType) {
        'PROBLEM_SOLVING' => PlayMissionType.problemSolving,
        'PERSPECTIVE_SHIFT' => PlayMissionType.perspectiveShift,
        _ => throw ParseException('알 수 없는 미션 종류입니다: $missionType'),
      },
      title: value['title'] as String? ?? '생각 미션',
      description: value['description'] as String? ?? '천천히 생각하고 답해 보세요.',
      questions: _questions(payload['questions']),
      cards: _cards(payload['cards']),
    );
  }

  static PlayTurnResult fromUtteranceJson(Map<String, dynamic> json) =>
      PlayTurnResult(
        characterText: _messageText(json['characterMessage']),
        characterAudioUrl: _messageAudioUrl(json['characterMessage']),
        mission: mission(json['mission']),
        sceneTransition: _transition(json['sceneTransition']),
        closingReactionText: _messageText(json['closingReaction']),
        closingReactionAudioUrl: _messageAudioUrl(json['closingReaction']),
        analysis: _analysis(json['analysis']),
        progress: _progress(json['progress']),
      );

  static PlayAnalysis? _analysis(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    return PlayAnalysis(
      childIntent: value['childIntent'] as String?,
      mainPoint: value['mainPoint'] as String?,
      detectedElements:
          (value['detectedElements'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map((item) => item['type'] as String?)
              .whereType<String>()
              .toList(growable: false),
      utteranceValidity: value['utteranceValidity'] as String?,
    );
  }

  static PlayProgress? _progress(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    return PlayProgress(
      mode: switch (value['mode']) {
        'NORMAL' => PlayResponseMode.normal,
        'GUIDED' => PlayResponseMode.guided,
        'CLOSING' => PlayResponseMode.closing,
        _ => null,
      },
      accumulatedElements: _elementNames(value['accumulatedElements']),
      missingElements: _elementNames(value['missingElements']),
      turnCount: (value['turnCount'] as num?)?.toInt() ?? 0,
      maxTurns: (value['maxTurns'] as num?)?.toInt() ?? 0,
      guidanceTarget: value['guidanceTarget'] as String?,
    );
  }

  static List<String> _elementNames(Object? value) => value is List
      ? value.whereType<String>().toList(growable: false)
      : const <String>[];

  static List<PlayMessage> _messages(Object? value) => value is List
      ? value
            .whereType<Map<String, dynamic>>()
            .map((item) {
              return PlayMessage(
                messageId: item['messageId']?.toString() ?? '',
                speaker: switch (item['speakerType']) {
                  'CHILD' => PlaySpeaker.child,
                  'CHARACTER' => PlaySpeaker.character,
                  _ => PlaySpeaker.system,
                },
                turnOrder: (item['turnOrder'] as num?)?.toInt() ?? 0,
                text: item['text'] as String? ?? '',
                sttLowConfidence: item['sttLowConfidence'] as bool? ?? false,
              );
            })
            .where((item) => item.text.isNotEmpty)
            .toList(growable: false)
      : const <PlayMessage>[];

  static PlaySceneTransition? _transition(Object? value) {
    if (value == null) return null;
    if (value is! Map<String, dynamic>) {
      throw const ParseException('장면 전환 응답 형식이 올바르지 않습니다.');
    }
    final String? next = value['next'] as String?;
    if (next == null) throw const ParseException('다음 장면 정보가 없습니다.');
    return PlaySceneTransition(
      next: switch (next) {
        'SCENE' => PlayTransitionTarget.scene,
        'POST_ACTIVITY' => PlayTransitionTarget.postActivity,
        'COMPLETED' => PlayTransitionTarget.completed,
        _ => throw ParseException('알 수 없는 장면 전환입니다: $next'),
      },
      nextSceneId: value['nextSceneId']?.toString(),
      nextSceneOrder: (value['nextSceneOrder'] as num?)?.toInt(),
      nextSceneType: switch (value['nextSceneType']) {
        'STORY' => PlaySceneType.story,
        'DIALOGUE' => PlaySceneType.dialogue,
        _ => null,
      },
      closingReason: value['closingReason'] as String?,
      resultImageUrl: value['resultImageUrl'] as String?,
    );
  }

  static List<PlayMissionQuestion> _questions(Object? value) => value is List
      ? value
            .whereType<Map<String, dynamic>>()
            .map((item) {
              return PlayMissionQuestion(
                key: item['key'] as String? ?? '',
                label: item['label'] as String? ?? '',
              );
            })
            .where((item) => item.key.isNotEmpty)
            .toList(growable: false)
      : const <PlayMissionQuestion>[];

  static List<PlayMissionCard> _cards(Object? value) => value is List
      ? value
            .whereType<Map<String, dynamic>>()
            .map((item) {
              return PlayMissionCard(
                key: item['key'] as String? ?? '',
                label: item['label'] as String? ?? '',
                imageUrl: item['imageUrl'] as String?,
                template: item['template'] as String?,
              );
            })
            .where((item) => item.key.isNotEmpty)
            .toList(growable: false)
      : const <PlayMissionCard>[];

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
