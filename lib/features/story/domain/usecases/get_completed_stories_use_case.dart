import '../../../mypage/domain/entities/report_summary.dart';
import '../../../mypage/domain/repositories/my_page_repository.dart';
import '../entities/completed_stories.dart';
import '../repositories/story_repository.dart';

/// 이 아이가 끝까지 들은 이야기들.
///
/// ## 정식 경로
///
/// `GET /children/{childId}/stories/completed` 하나입니다. 서버가 COMPLETED
/// 세션으로 판정하고, 그것은 후속 자유 대화의 진입 조건과 **같은 근거**입니다 —
/// 갈리면 도장은 찍혔는데 친구는 못 만나는 화면이 나옵니다.
///
/// ## 폴백 — 지울 코드입니다
///
/// 위 API 는 백엔드 PR
/// [#125](https://github.com/team-mugunghwa/goodquestion-backend/pull/125) 로
/// 막 올라갔고, `develop` 에 머지되어 Railway 에 배포되기 전까지 실서버에는
/// 없습니다(404). 그동안 목록의 도장이 통째로 사라지지 않게, 보호자 리포트
/// 목록에 남은 **이야기 제목**으로 맞춥니다.
///
/// 제목 매칭은 같은 제목의 이야기가 둘 생기거나 제목이 한 글자만 바뀌어도
/// 조용히 틀립니다. **배포가 확인되면 [_titlesFromReports] 와 이 폴백 분기를
/// 통째로 지우세요.** 그때 `ReportRepository` 의존도 함께 사라집니다.
///
/// ## 실패는 삼킵니다
///
/// 둘 다 실패하면 [CompletedStories.none] 입니다. 도장은 있으면 좋은 정보고,
/// 못 불렀다고 이야기 목록을 에러로 만들 이유가 없습니다.
class GetCompletedStoriesUseCase {
  const GetCompletedStoriesUseCase(this._stories, this._reports);

  final StoryRepository _stories;

  /// 폴백 전용. → 클래스 주석
  final ReportRepository _reports;

  Future<CompletedStories> call() async {
    try {
      return CompletedStories(storyIds: await _stories.getCompletedStoryIds());
    } on Object {
      return CompletedStories(titles: await _titlesFromReports());
    }
  }

  /// 폴백. 리포트 카드에는 `storyId` 가 없어 제목만 모읍니다.
  Future<Set<String>> _titlesFromReports() async {
    try {
      final ReportList list = await _reports.getReportList();
      return <String>{
        for (final ReportSummary report in list.reports)
          if (report.storyTitle.trim().isNotEmpty) report.storyTitle.trim(),
      };
    } on Object {
      return const <String>{};
    }
  }
}
