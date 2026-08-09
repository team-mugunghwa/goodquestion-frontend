import 'child_profile.dart';
import 'in_progress_session.dart';
import 'planet_summary.dart';
import 'recommended_story.dart';

/// 홈 화면이 한 번에 받는 데이터 묶음.
///
/// 홈은 "이어하기 / 새 이야기 / 내 행성" 세 갈래의 출발점이라, 세 섹션이
/// 따로 로딩되면 화면이 세 번 덜컹입니다. **요청 하나로 묶어서** 받습니다.
class HomeSummary {
  const HomeSummary({
    required this.recommendedStories,
    required this.planet,
    this.child,
    this.inProgressSession,
  });

  /// 현재 선택된 아이. **아직 아이 프로필이 없으면 `null`** 입니다.
  ///
  /// 이때도 홈은 그대로 보여 주고, 이야기에 들어가려 할 때만 프로필 생성으로
  /// 유도합니다. 빈 화면으로 막으면 아이가 무엇을 하는 앱인지 볼 기회를
  /// 잃습니다. (PRD F-01)
  final ChildProfile? child;

  /// 중단된 세션. 없으면 `null` 이고, 섹션2가 "새 이야기 시작" 카드로 바뀝니다.
  final InProgressSession? inProgressSession;

  /// 고정 큐레이션 2~3개. 없으면 빈 목록입니다.
  final List<RecommendedStory> recommendedStories;

  final PlanetSummary planet;

  /// 이어하기 카드를 보여 줄 수 있는 상태인지.
  bool get hasInProgressSession => inProgressSession != null;

  /// 아이 프로필이 있는지. 이야기 진입 게이트의 판단 근거입니다.
  bool get hasChild => child != null;
}
