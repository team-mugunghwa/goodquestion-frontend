/// 따라 말하기에 쓰는 예문의 종류. 서버 `sentenceType` 과 1:1 입니다.
enum SentenceType {
  /// 이야기 속에서 이 단어가 나온 문장. (`exampleSentence`)
  story('STORY'),

  /// 일상 대화 예문. (`exampleSentenceDaily`)
  daily('DAILY'),

  /// 한 단계 어려운 심화 예문. (`exampleSentenceAdvanced`)
  advanced('ADVANCED');

  const SentenceType(this.serverValue);

  /// 서버로 보내는 값. `STORY` / `DAILY` / `ADVANCED`
  final String serverValue;
}

/// 문장은 맞았지만 별가루를 주지 않은 이유.
enum SentencePracticeSkipReason {
  /// 이 문장으로는 이미 별가루를 받았습니다. (문장당 1회)
  alreadyRewarded,

  /// 오늘 받을 수 있는 횟수를 다 채웠습니다. (하루 2회)
  dailyLimit,
}

/// 따라 말하기 채점 결과. `POST .../sentence-practice` 응답과 1:1 입니다.
class SentencePracticeResult {
  const SentencePracticeResult({
    required this.matched,
    required this.similarity,
    required this.targetSentence,
    required this.rewarded,
    required this.stardustAmount,
    required this.stardustBalance,
    this.skipReason,
  });

  /// 유사도가 기준(90%)을 넘었는가.
  final bool matched;

  /// 0.00 ~ 1.00 사이의 글자 유사도.
  final double similarity;

  /// 아이가 따라 말했어야 하는 문장. 결과 화면이 다시 보여 줍니다.
  final String targetSentence;

  /// 이번에 별가루를 받았는가.
  final bool rewarded;

  /// [matched] 인데 [rewarded] 가 아니면 이유가 들어 있습니다.
  final SentencePracticeSkipReason? skipReason;

  /// 이번에 받은 별가루. 못 받았으면 0.
  final int stardustAmount;

  /// 반영이 끝난 별가루 잔액.
  final int stardustBalance;

  /// 결과 화면에 보여 줄 백분율. 반올림한 정수입니다.
  int get similarityPercent => (similarity * 100).round();
}
