import '../domain/entities/play_session.dart';
import 'stt_choice_catalog.dart';

/// "지금 무엇을 들려주고, 어떤 문장 카드를 보여줄지"를 정하는 규칙.
///
/// 화면(`play_view.dart`)에 두지 않고 따로 뺐습니다 - 규칙이 순수 함수라야
/// 위젯을 띄우지 않고 표로 검증할 수 있고, 나중에 문장 테이블이 서버(DB)로
/// 옮겨 가도 [SttChoiceCatalog] 를 리포지토리로 바꿔 끼우는 것만으로 끝납니다.
/// → `docs/이야기_전개_가이드.md` 3.4
abstract final class SttChoiceSelector {
  /// 한 화면에 놓는 선택지는 최대 3개입니다. (`docs/DESIGN_SYSTEM.md` 2장)
  static const int maxCards = 3;

  /// 몇 번 이어서 못 알아들었을 때 문장 카드를 내릴지.
  static const int attemptsBeforeChoices = 3;

  /// 카드로 고른 발화가 서버에 싣고 가는 `sttRetryCount`.
  ///
  /// 카운터가 4든 5든 **항상 3** 입니다 - 이 값은 "몇 번 다시 말했나"가
  /// 아니라 "세 번 만에 고르기로 내려왔다"는 사실을 가리킵니다.
  static const int choiceRetryCount = attemptsBeforeChoices;

  /// [attempt] 번째로 못 알아들었을 때 캐릭터가 건넬 말.
  ///
  /// 음성이 준비된 장면(3·5·7·9)이 아니면 `null` 입니다 - 그때는 화면이
  /// 예전처럼 짧은 글 안내만 답니다.
  ///
  /// [hasCards] 가 false 면 3회째여도 선택지 안내를 쓰지 않습니다. 고를 것이
  /// 없는데 "이 중에서 골라 볼래?"라고 물으면 아이가 화면을 뒤집니다.
  static SttChoiceVoice? voiceFor({
    required int? sceneOrder,
    required int attempt,
    required bool hasCards,
  }) {
    if (!SttChoiceCatalog.supports(sceneOrder)) return null;
    if (attempt <= 1) return SttChoiceCatalog.retryFirst[sceneOrder];
    if (attempt < attemptsBeforeChoices || !hasCards) {
      return SttChoiceCatalog.retrySecond[sceneOrder];
    }
    return SttChoiceCatalog.choiceIntro[sceneOrder];
  }

  /// 이 장면에서 보여줄 문장 카드. 빈 목록이면 **선택지 화면을 띄우지
  /// 않습니다** - 빈 판을 내리느니 재녹음 안내를 유지하는 편이 낫습니다.
  ///
  /// - 음성이 없는 장면이면 비어 있습니다.
  /// - [lastProgress] 가 없으면 이 장면의 첫 발화 턴이라 정해진 3문장을 줍니다.
  /// - 있으면 아직 못 채운 요소(`missingElements`)를 보고 고릅니다. **남은
  ///   요소를 둘 다 덮는 조합 문장을 앞에 놓고**, 남은 자리를 요소별 낱장으로
  ///   메워 최대 [maxCards] 장을 줍니다.
  ///
  /// 조합 문장을 앞세우는 이유는 그 한 장으로 장면이 닫히기 때문입니다.
  /// 낱장만 주면 요소를 하나씩만 채워서 턴이 한 번 더 듭니다 - 장면당 턴이
  /// 4~5회뿐이라 세 번이나 못 알아들은 아이에게는 그 한 턴이 큽니다.
  ///
  /// **직전에 아이가 무엇을 골랐는지 기억하지 않습니다.** 남은 요소만 보고
  /// 고르므로 1턴차를 목소리로 말한 아이(카드를 안 거친 경우)에게도 같은
  /// 규칙이 그대로 맞습니다.
  static List<SttChoiceSentence> cardsFor({
    required int? sceneOrder,
    PlayProgress? lastProgress,
  }) {
    if (!SttChoiceCatalog.supports(sceneOrder)) {
      return const <SttChoiceSentence>[];
    }
    if (lastProgress == null) {
      final List<SttChoiceSentence> first =
          SttChoiceCatalog.firstTurn[sceneOrder] ?? const <SttChoiceSentence>[];
      return first.length <= maxCards
          ? first
          : first.sublist(0, maxCards).toList(growable: false);
    }

    // 서버에 새 요소가 생겨도 화면이 죽지 않게, 모르는 코드는 조용히 버립니다.
    final List<SttChoiceElement> missing = <SttChoiceElement>[];
    for (final String code in lastProgress.missingElements) {
      final SttChoiceElement? element = SttChoiceElement.fromCode(code);
      if (element != null && !missing.contains(element)) missing.add(element);
    }
    if (missing.isEmpty) return const <SttChoiceSentence>[];

    final List<SttChoiceSentence> picked = <SttChoiceSentence>[];

    // 1) 남은 요소를 두 개 이상 한 번에 채우는 조합 문장. 많이 덮는 순서로,
    //    같으면 id 순으로 - 같은 상황에서 늘 같은 카드가 나와야 합니다.
    final List<SttChoiceSentence> combos =
        (SttChoiceCatalog.secondTurnCombos[sceneOrder] ??
                const <SttChoiceSentence>[])
            .where((SttChoiceSentence item) => _covered(item, missing) >= 2)
            .toList()
          ..sort((SttChoiceSentence a, SttChoiceSentence b) {
            final int byCover = _covered(b, missing) - _covered(a, missing);
            return byCover != 0 ? byCover : a.id.compareTo(b.id);
          });
    // 조합 문장은 **한 장만** 놓습니다. 서로 비슷한 문장 세 장을 늘어놓는 것보다
    // "한 번에 끝나는 것 하나 + 낱장"이 고르는 의미가 살아 있습니다.
    if (combos.isNotEmpty) picked.add(combos.first);

    // 2) 남은 자리는 요소별 낱장으로. 녹음이 없는 요소는 건너뜁니다.
    final Map<SttChoiceElement, SttChoiceSentence> byElement =
        SttChoiceCatalog.byElement[sceneOrder] ??
        const <SttChoiceElement, SttChoiceSentence>{};
    for (final SttChoiceElement element in missing) {
      if (picked.length == maxCards) break;
      final SttChoiceSentence? sentence = byElement[element];
      if (sentence == null) continue;
      if (picked.any((SttChoiceSentence item) => item.id == sentence.id)) {
        continue;
      }
      picked.add(sentence);
    }
    return List<SttChoiceSentence>.unmodifiable(picked);
  }

  /// [sentence] 가 [missing] 중 몇 개를 덮는지.
  static int _covered(
    SttChoiceSentence sentence,
    List<SttChoiceElement> missing,
  ) => sentence.elements
      .where((SttChoiceElement element) => missing.contains(element))
      .length;
}
