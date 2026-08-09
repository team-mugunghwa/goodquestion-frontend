/// 홈에 고정으로 노출되는 추천 이야기.
///
/// MVP 에서 **개인화 추천은 범위 밖**입니다. 서버가 내려주는 고정 큐레이션
/// 2~3개를 그대로 보여 줍니다.
class RecommendedStory {
  const RecommendedStory({
    required this.storyId,
    required this.title,
    required this.estimatedMinutes,
    required this.topicTag,
    this.image,
  });

  final int storyId;
  final String title;

  /// 대표 이미지. `null` 이면 화면이 브랜드 그라디언트로 대체합니다.
  final String? image;

  /// 예상 소요 시간(분).
  final int estimatedMinutes;

  /// 주제 태그 한 단어. ("우정", "용기", "가족")
  final String topicTag;
}
