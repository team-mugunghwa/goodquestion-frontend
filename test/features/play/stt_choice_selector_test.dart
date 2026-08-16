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
        // 넷이 다 비어 있으면 한 장으로는 못 닫습니다. 그래도 둘을 덮는
        // 조합 문장을 맨 앞에 두고, 나머지는 낱장으로 채웁니다.
        'c3_t2_1',
        'c3_EMOTION',
        'c3_PERSPECTIVE',
      ]);
    });

    test('남은 요소 둘을 한 번에 채우는 문장이 있으면 맨 앞에 놓는다', () {
      final List<SttChoiceSentence> cards = SttChoiceSelector.cardsFor(
        sceneOrder: 3,
        lastProgress: const PlayProgress(
          missingElements: <String>['REASON', 'SOLUTION'],
        ),
      );

      expect(cards.first.id, 'c3_t2_1', reason: '이 한 장이면 장면이 닫힙니다');
      expect(cards.first.elements, <SttChoiceElement>[
        SttChoiceElement.reason,
        SttChoiceElement.solution,
      ]);
      // 낱장도 함께 둡니다 - 고르는 의미가 남아 있어야 합니다.
      expect(cards.map((SttChoiceSentence item) => item.id), <String>[
        'c3_t2_1',
        'c3_REASON',
        'c3_SOLUTION',
      ]);
    });

    test('1턴차에 무엇을 골랐든, 남은 요소를 한 장으로 덮는 문장이 있다', () {
      // 조합 문장이 존재하는 이유 자체를 검증합니다. 이게 깨지면 아이가
      // 2턴에 장면을 닫지 못하고 한 턴을 더 써야 합니다.
      for (final int scene in SttChoiceCatalog.supportedScenes) {
        final Set<SttChoiceElement> required = SttChoiceCatalog
            .byElement[scene]!
            .keys
            .toSet();
        for (final SttChoiceSentence chosen
            in SttChoiceCatalog.firstTurn[scene]!) {
          final Set<SttChoiceElement> missing = required.difference(
            chosen.elements.toSet(),
          );
          final List<SttChoiceSentence> cards = SttChoiceSelector.cardsFor(
            sceneOrder: scene,
            lastProgress: PlayProgress(
              missingElements: missing
                  .map((SttChoiceElement item) => item.code)
                  .toList(),
            ),
          );

          expect(
            cards.first.elements.toSet(),
            containsAll(missing),
            reason:
                '장면 $scene 에서 ${chosen.id} 를 고른 뒤 남은 $missing 를 한 장이 덮어야 합니다',
          );
        }
      }
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
