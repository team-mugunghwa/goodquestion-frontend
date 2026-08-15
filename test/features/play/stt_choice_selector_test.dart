import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/features/play/data/stt_choice_catalog.dart';
import 'package:goodquestion/features/play/data/stt_choice_selector.dart';
import 'package:goodquestion/features/play/domain/entities/play_session.dart';

void main() {
  group('보여줄 문장 카드 고르기', () {
    test('음성이 없는 장면에서는 한 장도 만들지 않는다', () {
      // 빈 판을 띄우느니 재녹음 안내를 유지하는 편이 낫습니다.
      expect(SttChoiceSelector.cardsFor(sceneOrder: 4), isEmpty);
      expect(SttChoiceSelector.cardsFor(sceneOrder: null), isEmpty);
      expect(
        SttChoiceSelector.cardsFor(
          sceneOrder: 4,
          lastProgress: const PlayProgress(
            missingElements: <String>['EMOTION'],
          ),
        ),
        isEmpty,
      );
    });

    test('이 장면의 첫 턴이면 정해진 3문장을 그대로 준다', () {
      final List<SttChoiceSentence> cards = SttChoiceSelector.cardsFor(
        sceneOrder: 3,
      );

      expect(cards.length, 3);
      expect(
        cards.map((SttChoiceSentence item) => item.id),
        SttChoiceCatalog.firstTurn[3]!.map((SttChoiceSentence item) => item.id),
      );
    });

    test('두 번째 턴부터는 아직 못 채운 요소로 고르고, 최대 3장을 넘지 않는다', () {
      final List<SttChoiceSentence> cards = SttChoiceSelector.cardsFor(
        sceneOrder: 3,
        lastProgress: const PlayProgress(
          missingElements: <String>[
            'EMOTION',
            'PERSPECTIVE',
            'REASON',
            'SOLUTION',
          ],
        ),
      );

      expect(cards.length, SttChoiceSelector.maxCards);
      expect(cards.map((SttChoiceSentence item) => item.id), <String>[
        'c3_EMOTION',
        'c3_PERSPECTIVE',
        'c3_REASON',
      ]);
    });

    test('남은 요소가 하나면 한 장만 보여준다', () {
      final List<SttChoiceSentence> cards = SttChoiceSelector.cardsFor(
        sceneOrder: 3,
        lastProgress: const PlayProgress(missingElements: <String>['SOLUTION']),
      );

      expect(cards.length, 1);
      expect(cards.single.id, 'c3_SOLUTION');
    });

    test('그 장면에 녹음이 없는 요소와 모르는 코드는 건너뛴다', () {
      // 7장면에는 EMOTION 문장이 없습니다. 새로 생긴 코드(FRIENDSHIP)도
      // 화면을 죽이지 않고 조용히 지나가야 합니다.
      final List<SttChoiceSentence> cards = SttChoiceSelector.cardsFor(
        sceneOrder: 7,
        lastProgress: const PlayProgress(
          missingElements: <String>['EMOTION', 'FRIENDSHIP', 'REASON'],
        ),
      );

      expect(cards.map((SttChoiceSentence item) => item.id), <String>[
        'c7_REASON',
      ]);
    });

    test('못 채운 요소가 비어 있으면 한 장도 만들지 않는다', () {
      expect(
        SttChoiceSelector.cardsFor(
          sceneOrder: 3,
          lastProgress: const PlayProgress(),
        ),
        isEmpty,
      );
    });
  });

  group('다시 물어보는 안내 음성 고르기', () {
    test('1회는 첫 안내, 2회는 두 번째 안내, 3회는 선택지 안내', () {
      expect(
        SttChoiceSelector.voiceFor(
          sceneOrder: 3,
          attempt: 1,
          hasCards: false,
        )?.id,
        'retry_1_c3',
      );
      expect(
        SttChoiceSelector.voiceFor(
          sceneOrder: 3,
          attempt: 2,
          hasCards: false,
        )?.id,
        'retry_2_c3',
      );
      expect(
        SttChoiceSelector.voiceFor(
          sceneOrder: 3,
          attempt: 3,
          hasCards: true,
        )?.id,
        'choice_intro_c3',
      );
    });

    test('고를 카드가 없으면 3회째여도 "골라 볼래?"라고 하지 않는다', () {
      expect(
        SttChoiceSelector.voiceFor(
          sceneOrder: 3,
          attempt: 3,
          hasCards: false,
        )?.id,
        'retry_2_c3',
      );
    });

    test('음성이 없는 장면에서는 들려줄 말이 없다', () {
      expect(
        SttChoiceSelector.voiceFor(sceneOrder: 4, attempt: 1, hasCards: false),
        isNull,
      );
    });
  });
}
