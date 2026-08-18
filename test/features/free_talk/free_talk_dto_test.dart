import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/exceptions.dart';
import 'package:goodquestion/features/free_talk/data/dtos/free_talk_dto.dart';
import 'package:goodquestion/features/free_talk/domain/entities/free_talk.dart';

/// 백엔드가 아직 배포 전이라 **계약 문서만 보고** 만든 파서입니다.
/// 그래서 "있어야 하는 것"과 "없어도 되는 것"을 여기서 못 박아 둡니다 —
/// 실제 응답이 오면 이 테스트가 어긋난 자리를 먼저 알려 줍니다.
void main() {
  group('인물 목록', () {
    test('필수 값만 있으면 파싱된다', () {
      final List<FreeTalkCharacter> characters = FreeTalkDto.characters(
        <dynamic>[
          <String, dynamic>{
            'characterId': 'c-1',
            'name': '방귀쟁이 며느리',
            'characterKey': 'daughter_in_law',
          },
        ],
      );

      expect(characters, hasLength(1));
      expect(characters.first.characterId, 'c-1');
      expect(characters.first.name, '방귀쟁이 며느리');
      // 없어도 되는 값은 null 로 남습니다 - 카드가 그 줄을 안 그릴 뿐입니다.
      expect(characters.first.thumbnailUrl, isNull);
      expect(characters.first.lastTalkedAt, isNull);
    });

    test('썸네일과 마지막 대화 시각을 읽는다', () {
      final List<FreeTalkCharacter> characters = FreeTalkDto.characters(
        <dynamic>[
          <String, dynamic>{
            'characterId': 'c-1',
            'name': '시아버지',
            'characterKey': 'father_in_law',
            'thumbnailUrl': '/media/c1.webp',
            'lastTalkedAt': '2026-08-17T09:00:00Z',
          },
        ],
      );

      expect(characters.first.thumbnailUrl, '/media/c1.webp');
      expect(characters.first.lastTalkedAt, isNotNull);
    });

    test('시각 형식이 깨져도 목록 전체가 막히지 않는다', () {
      // 카드에 한 줄 덧붙이는 값 때문에 인물이 통째로 사라지면 안 됩니다.
      final List<FreeTalkCharacter> characters = FreeTalkDto.characters(
        <dynamic>[
          <String, dynamic>{
            'characterId': 'c-1',
            'name': '마을 이장',
            'characterKey': 'chief',
            'lastTalkedAt': '어제쯤',
          },
        ],
      );

      expect(characters.first.lastTalkedAt, isNull);
    });

    test('식별자나 이름이 없으면 예외', () {
      expect(
        () => FreeTalkDto.characters(<dynamic>[
          <String, dynamic>{'name': '이름만'},
        ]),
        throwsA(isA<ParseException>()),
      );
    });

    test('목록이 아니면 예외', () {
      expect(
        () => FreeTalkDto.characters(<String, dynamic>{}),
        throwsA(isA<ParseException>()),
      );
    });
  });

  group('대화 시작', () {
    test('freeTalkId · 인물 · 첫 대사를 읽는다', () {
      final FreeTalkSession session = FreeTalkDto.session(<String, dynamic>{
        'freeTalkId': 'ft-1',
        'character': <String, dynamic>{
          'characterId': 'c-1',
          'name': '방귀쟁이 며느리',
          'characterKey': 'daughter_in_law',
        },
        'opening': <String, dynamic>{
          'text': '또 왔구나! 반가워.',
          'audioUrl': '/tts/opening.mp3',
          'emotion': 'hopeful',
        },
        'maxTurns': 10,
      });

      expect(session.freeTalkId, 'ft-1');
      expect(session.character.name, '방귀쟁이 며느리');
      expect(session.opening.text, '또 왔구나! 반가워.');
      expect(session.opening.emotion, 'hopeful');
      expect(session.maxTurns, 10);
    });

    test('인물 정보가 비어 오면 우리가 고른 인물로 채운다', () {
      // 이름을 잃고 "이야기 친구"로 되돌아가는 것보다 낫습니다.
      const FreeTalkCharacter requested = FreeTalkCharacter(
        characterId: 'c-1',
        name: '시아버지',
        characterKey: 'father_in_law',
      );
      final FreeTalkSession session = FreeTalkDto.session(<String, dynamic>{
        'freeTalkId': 'ft-2',
        'opening': <String, dynamic>{'text': '어험, 왔느냐.'},
      }, requested: requested);

      expect(session.character.name, '시아버지');
    });

    test('첫 대사가 비면 예외 - 그 응답으로는 화면을 못 연다', () {
      expect(
        () => FreeTalkDto.session(<String, dynamic>{
          'freeTalkId': 'ft-3',
          'character': <String, dynamic>{
            'characterId': 'c-1',
            'name': '이장',
            'characterKey': 'chief',
          },
          'opening': <String, dynamic>{'text': '   '},
        }),
        throwsA(isA<ParseException>()),
      );
    });
  });

  group('턴 응답', () {
    test('ended 가 없으면 false 로 본다 - 서버가 안 닫았다는 뜻', () {
      final FreeTalkTurn turn = FreeTalkDto.turn(<String, dynamic>{
        'characterMessage': <String, dynamic>{'text': '그랬구나!'},
        'turnCount': 3,
      });

      expect(turn.characterMessage.text, '그랬구나!');
      expect(turn.turnCount, 3);
      expect(turn.ended, isFalse);
    });

    test('ended 를 읽는다', () {
      final FreeTalkTurn turn = FreeTalkDto.turn(<String, dynamic>{
        'characterMessage': <String, dynamic>{'text': '오늘은 여기까지 하자. 또 보자!'},
        'turnCount': 10,
        'ended': true,
      });

      expect(turn.ended, isTrue);
    });
  });

  test('마무리 인사는 closing 안에 있다', () {
    final FreeTalkSpeech closing = FreeTalkDto.closing(<String, dynamic>{
      'closing': <String, dynamic>{
        'text': '잘 가! 또 놀러 와.',
        'audioUrl': '/tts/closing.mp3',
      },
    });

    expect(closing.text, '잘 가! 또 놀러 와.');
    expect(closing.audioUrl, '/tts/closing.mp3');
  });
}
