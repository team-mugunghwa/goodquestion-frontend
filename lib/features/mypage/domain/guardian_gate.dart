/// 보호자 확인 게이트(모달 5)의 통과 상태.
///
/// ## 왜 상태를 따로 두는가
///
/// 리포트는 아이가 혼자 열면 안 되지만, 보호자가 목록 → 상세 → 목록을 오갈
/// 때마다 확인을 요구하면 못 씁니다. **같은 세션 안에서 한 번만** 묻습니다.
///
/// ⚠️ 지금은 마이페이지의 호출 지점에서만 검사합니다. 모달 5 가 확정되면
/// `app_router.dart` 의 `redirect` 로 옮기세요 — 화면마다 검사하면 딥링크로
/// 들어오는 경로를 반드시 빠뜨립니다. (`docs/ARCHITECTURE.md` 2장)
class GuardianGate {
  bool _passed = false;

  bool get isPassed => _passed;

  void pass() => _passed = true;

  /// 로그아웃·아이 전환처럼 보호자 세션이 끊기는 시점에 부릅니다.
  void reset() => _passed = false;
}
