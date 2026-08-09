import 'story_summary.dart';
import 'story_topic.dart';

/// 이야기 목록 화면이 한 번에 받는 것 — 주제 필터 + 이야기 전부.
///
/// 필터를 서버에 다시 물어보지 않습니다. MVP 콘텐츠 수가 적어서 전부 받아
/// **앱에서 거르는 게** 훨씬 빠르고, 칩을 누를 때마다 스켈레톤이 번쩍이지
/// 않습니다. 콘텐츠가 수백 개가 되면 그때 서버 필터로 바꿉니다.
class StoryCatalog {
  const StoryCatalog({required this.topics, required this.stories});

  final List<StoryTopic> topics;

  /// 서버가 준 순서 그대로. **앱에서 정렬하지 않습니다** —
  /// 추천·개인화 로직은 MVP 범위 밖입니다.
  final List<StorySummary> stories;

  /// 주제로 거른 목록.
  List<StorySummary> filtered(String topicId) => stories
      .where((StorySummary story) => story.matches(topicId))
      .toList(growable: false);
}
