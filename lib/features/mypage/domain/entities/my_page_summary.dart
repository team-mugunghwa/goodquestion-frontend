/// 마이페이지 카드에 필요한 것 전부.
///
/// 이 화면은 **허브**이지 통계 화면이 아닙니다. 활동 요약에 숫자를 셋 이상
/// 넣지 마세요 — 보호자용 미니 피드백이지 대시보드가 아닙니다.
class MyPageSummary {
  const MyPageSummary({
    required this.childCount,
    required this.completedStories,
    required this.stardust,
    required this.hasNewReport,
    this.child,
  });

  /// 아직 아이를 등록하지 않았으면 `null`.
  final MyPageChild? child;

  /// 보호자 계정에 등록된 아이 수. 2명 이상일 때만 전환 버튼을 강조합니다.
  final int childCount;

  final int completedStories;
  final int stardust;

  /// 안 읽은 리포트가 있는가. 메뉴에 빨간 점으로 붙습니다.
  final bool hasNewReport;

  bool get hasChild => child != null;

  /// 전환할 다른 아이가 있는가.
  bool get canSwitchChild => childCount > 1;
}

/// 마이페이지가 보여 주는 아이. 홈의 `ChildProfile` 과 달리 **나이**가 있습니다
/// — 보호자가 "지금 누구 계정을 보고 있는지" 확인하는 정보이기 때문입니다.
class MyPageChild {
  const MyPageChild({
    required this.childId,
    required this.name,
    required this.age,
    this.avatar,
  });

  final String childId;
  final String name;
  final int age;
  final String? avatar;
}
