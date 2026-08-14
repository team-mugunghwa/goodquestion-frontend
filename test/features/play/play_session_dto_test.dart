import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/features/play/data/dtos/play_session_dto.dart';
import 'package:goodquestion/features/play/domain/entities/play_session.dart';

void main() {
  test('이어하기 응답의 STORY 장면을 파싱한다', () {
    final PlaySessionSnapshot result = PlaySessionDto.fromResumeJson(
      <String, dynamic>{
        'session': <String, dynamic>{'phase': 'STORY'},
        'currentScene': <String, dynamic>{
          'sceneId': 'scene-1',
          'sceneOrder': 1,
          'sceneType': 'STORY',
          'narrationSentences': <String>['첫 문장', '둘째 문장'],
          'imageUrl': 'https://example.com/scene.png',
          'characterName': null,
          'maxTurns': null,
        },
        'lastCharacterMessage': null,
      },
    );

    expect(result.phase, PlayPhase.story);
    expect(result.currentScene?.sceneType, PlaySceneType.story);
    expect(result.currentScene?.narrationSentences, <String>['첫 문장', '둘째 문장']);
  });

  test('장면 전환 응답의 DIALOGUE 첫 대사를 파싱한다', () {
    final PlaySessionSnapshot result = PlaySessionDto.fromAdvanceJson(
      <String, dynamic>{
        'phase': 'DIALOGUE',
        'currentScene': <String, dynamic>{
          'sceneId': 'scene-2',
          'sceneOrder': 2,
          'sceneType': 'DIALOGUE',
          'narrationSentences': <String>[],
          'imageUrl': null,
          'characterName': '토리',
          'maxTurns': 3,
        },
        'openingMessage': <String, dynamic>{
          'messageId': 'message-1',
          'text': '넌 어떻게 생각해?',
          'audioUrl': 'https://example.com/opening.mp3',
        },
      },
    );

    expect(result.phase, PlayPhase.dialogue);
    expect(result.currentScene?.characterName, '토리');
    expect(result.openingText, '넌 어떻게 생각해?');
  });

  test('마지막 STORY 완료 응답은 후속 활동 단계가 된다', () {
    final PlaySessionSnapshot result = PlaySessionDto.fromAdvanceJson(
      <String, dynamic>{
        'phase': 'POST_ACTIVITY',
        'currentScene': null,
        'openingMessage': null,
      },
    );

    expect(result.phase, PlayPhase.postActivity);
    expect(result.currentScene, isNull);
  });
}
