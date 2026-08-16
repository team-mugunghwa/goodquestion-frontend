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
          'videoUrl': '/stories/banggui/scenes/01_intro.mp4',
          'characterName': null,
          'maxTurns': null,
        },
        'lastCharacterMessage': null,
        'messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'messageId': 'child-1',
            'speakerType': 'CHILD',
            'turnOrder': 1,
            'text': '나도 도와줄래요.',
            'sttLowConfidence': false,
          },
        ],
      },
    );

    expect(result.phase, PlayPhase.story);
    expect(result.currentScene?.sceneType, PlaySceneType.story);
    expect(result.currentScene?.narrationSentences, <String>['첫 문장', '둘째 문장']);
    expect(
      result.currentScene?.videoUrl,
      '/stories/banggui/scenes/01_intro.mp4',
    );
    expect(result.messages.single.text, '나도 도와줄래요.');
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
    // videoUrl 키가 없는 응답(백엔드 #104 이전 서버·영상 없는 장면)은
    // null로 파싱되어 이미지 배경으로 동작해야 한다.
    expect(result.currentScene?.videoUrl, isNull);
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

  test('resume의 exposedMission을 복원한다', () {
    final PlaySessionSnapshot snapshot = PlaySessionDto.fromResumeJson(
      <String, dynamic>{
        'session': <String, dynamic>{'phase': 'DIALOGUE'},
        'currentScene': <String, dynamic>{
          'sceneId': 'scene-3',
          'sceneOrder': 3,
          'sceneType': 'DIALOGUE',
          'narrationSentences': <String>[],
        },
        'lastCharacterMessage': <String, dynamic>{'text': '같이 생각해 볼까?'},
        'exposedMission': <String, dynamic>{
          'missionId': 'mission_1',
          'missionType': 'PROBLEM_SOLVING',
          'title': '안전한 방법 찾기',
          'description': '네 가지 질문에 답해 보세요.',
          'payload': <String, dynamic>{
            'questions': <Map<String, dynamic>>[
              <String, dynamic>{'key': 'tool', 'label': '도구'},
            ],
            'cards': null,
          },
        },
      },
    );

    expect(snapshot.mission?.missionId, 'mission_1');
    expect(snapshot.mission?.missionType, PlayMissionType.problemSolving);
    expect(snapshot.mission?.questions.single.key, 'tool');
  });

  test('utterance의 mission과 장면 전환 여부를 파싱한다', () {
    final PlayTurnResult result = PlaySessionDto.fromUtteranceJson(
      <String, dynamic>{
        'characterMessage': <String, dynamic>{'text': '정말 좋은 생각이야!'},
        'mission': null,
        'closingReaction': <String, dynamic>{'text': '그렇구나!'},
        'sceneTransition': <String, dynamic>{
          'next': 'SCENE',
          'nextSceneType': 'STORY',
          'resultImageUrl': '/stories/banggui/scenes/07_result.jpg',
        },
      },
    );

    expect(result.characterText, '정말 좋은 생각이야!');
    expect(result.mission, isNull);
    expect(result.hasSceneTransition, isTrue);
    expect(result.closingReactionText, '그렇구나!');
    expect(result.sceneTransition?.nextSceneType, PlaySceneType.story);
    expect(
      result.sceneTransition?.resultImageUrl,
      '/stories/banggui/scenes/07_result.jpg',
    );
  });
}
