import '../../domain/entities/sentence_practice.dart';

/// `POST /children/{childId}/words/{wordId}/sentence-practice` 응답 그대로.
class SentencePracticeResultDto {
  const SentencePracticeResultDto({
    required this.matched,
    required this.similarity,
    required this.targetSentence,
    required this.rewarded,
    required this.stardustAmount,
    required this.stardustBalance,
    this.skipReason,
  });

  factory SentencePracticeResultDto.fromJson(Map<String, dynamic> json) =>
      SentencePracticeResultDto(
        matched: json['matched'] as bool? ?? false,
        similarity: (json['similarity'] as num?)?.toDouble() ?? 0,
        targetSentence: json['targetSentence'] as String? ?? '',
        rewarded: json['rewarded'] as bool? ?? false,
        skipReason: json['skipReason'] as String?,
        stardustAmount: json['stardustAmount'] as int? ?? 0,
        stardustBalance: json['stardustBalance'] as int? ?? 0,
      );

  final bool matched;
  final double similarity;
  final String targetSentence;
  final bool rewarded;

  /// `ALREADY_REWARDED` / `DAILY_LIMIT` / null.
  final String? skipReason;
  final int stardustAmount;
  final int stardustBalance;

  SentencePracticeResult toEntity() => SentencePracticeResult(
    matched: matched,
    similarity: similarity,
    targetSentence: targetSentence,
    rewarded: rewarded,
    // 모르는 값이 와도 화면이 죽지 않게 null 로 눕힙니다.
    skipReason: switch (skipReason) {
      'ALREADY_REWARDED' => SentencePracticeSkipReason.alreadyRewarded,
      'DAILY_LIMIT' => SentencePracticeSkipReason.dailyLimit,
      _ => null,
    },
    stardustAmount: stardustAmount,
    stardustBalance: stardustBalance,
  );
}
