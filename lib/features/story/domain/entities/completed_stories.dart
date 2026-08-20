import 'story_summary.dart';

/// 이 아이가 끝까지 들은 이야기들.
///
/// ## 왜 값이 둘인가 — 임시로 근거가 둘이라서
///
/// 정식 근거는 [storyIds] 하나입니다
/// (`GET /children/{childId}/stories/completed`). [titles] 는 **그 API 가 아직
/// 배포되지 않은 서버**를 위한 임시 폴백이고, 보호자 리포트 목록의 이야기 제목을
/// 그대로 담습니다 — 리포트에는 `storyId` 가 없어서 제목밖에 없습니다.
///
/// 제목 매칭은 같은 제목의 이야기가 둘 생기거나 제목이 한 글자만 바뀌어도 조용히
/// 틀립니다. 그래서 폴백이고, 정식 API 가 배포되면 **[titles] 와 폴백 경로를
/// 통째로 지웁니다.**
/// → 백엔드 PR team-mugunghwa/goodquestion-backend#125
class CompletedStories {
  const CompletedStories({
    this.storyIds = const <String>{},
    this.titles = const <String>{},
  });

  /// 아무것도 못 알아낸 상태. 도장을 하나도 안 찍습니다.
  static const CompletedStories none = CompletedStories();

  /// 서버가 준 완주한 이야기 id 들. 이것이 정식 근거입니다.
  final Set<String> storyIds;

  /// 폴백 전용. 리포트에 남은 이야기 제목들. → 클래스 주석
  final Set<String> titles;

  /// 이 이야기를 끝까지 들었는가.
  bool contains(StorySummary story) =>
      storyIds.contains(story.storyId) || titles.contains(story.title.trim());

  bool get isEmpty => storyIds.isEmpty && titles.isEmpty;
}
