/// 목록 카드 한 장이 필요로 하는 것 전부.
///
/// **여기에 필드를 더하지 마세요.** 난이도·요약·역할을 목록에 얹고 싶어지는데,
/// PRD F-03 은 목록 노출을 이미지·제목·예상 시간·주제로 못 박았습니다.
/// 정보를 더하면 아이는 카드를 "읽어야" 하고, 그 순간 그림으로 고르는
/// 탐색이 글 읽기 과제로 바뀝니다.
class StorySummary {
  const StorySummary({
    required this.storyId,
    required this.title,
    required this.estimatedMinutes,
    required this.topicIds,
    this.image,
  });

  final int storyId;
  final String title;

  /// 대표 이미지. `null` 이면 화면이 브랜드 그라디언트로 대체합니다.
  final String? image;

  final int estimatedMinutes;

  /// 이 이야기가 속한 주제들. 하나가 여러 주제에 걸릴 수 있습니다.
  final List<String> topicIds;

  /// 필터 판정. `all` 은 전부 통과입니다.
  bool matches(String topicId) =>
      topicId == 'all' || topicIds.contains(topicId);
}
