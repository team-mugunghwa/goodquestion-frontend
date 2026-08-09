/// 사용자에게 보이는 문구.
///
/// 위젯 안에 한글 문자열을 직접 쓰지 마세요. (`docs/CONVENTIONS.md` 5장)
/// 문구는 디자인만큼 화면의 인상을 정하기 때문에, 한 곳에 모아 두고
/// **톤을 통째로 검토**할 수 있어야 합니다. (`docs/DESIGN_SYSTEM.md` 11장)
///
/// ## 규칙
///
/// - 공통 문구는 [AppStrings], 화면 전용 문구는 화면별 클래스(`HomeStrings` 등)
/// - 아이에게 보이는 문구는 **캐릭터가 말하듯이**. 시스템이 말하지 않습니다
/// - 실패를 실패라고 부르지 않습니다 — "인식하지 못했어요" ❌ / "잘 안 들렸어" ✅
/// - 값이 끼어드는 문구는 상수가 아니라 **함수**로 둡니다 ([HomeStrings.sceneProgress])
///
/// 다국어는 MVP 범위 밖입니다. 필요해지면 이 파일이 `l10n` 으로 넘어갑니다.
library;

/// 여러 화면이 함께 쓰는 문구.
abstract final class AppStrings {
  /// 아이 화면의 재시도. "다시 시도"(보호자 톤)와 구분합니다.
  static const String retryKid = '다시 불러오기';

  /// 아이 화면에서 무언가를 불러오지 못했을 때. 아이 탓이 아니라는 톤.
  static const String loadFailedKid = '앗, 지금은 못 가져왔어.\n한 번만 더 해볼까?';
}

/// 하단 내비게이션 탭 이름. 네 화면이 같은 라벨을 씁니다.
abstract final class NavStrings {
  static const String home = '홈';
  static const String stories = '이야기';
  static const String words = '단어장';
  static const String myPage = '마이';
}

/// 홈(`/`) 전용 문구.
abstract final class HomeStrings {
  // ── 섹션1 상단 바 ──
  static const String profileSemantics = '아이 바꾸기';
  static const String stardust = '별가루';

  // ── 섹션2 이어하기 / 새 이야기 ──
  static const String resume = '이어서 말하기';

  /// "3번째 장면까지 했어요" — 마지막으로 **완료한** 장면 번호입니다.
  static String sceneProgress(int lastCompletedScene) =>
      '$lastCompletedScene번째 장면까지 했어요';

  /// 진행 중인 이야기가 없을 때 섹션2를 대신하는 카드.
  static const String startTitle = '새 이야기를 골라볼까?';
  static const String startAction = '이야기 고르기';

  // ── 섹션3 추천 ──
  static const String recommendedTitle = '새로운 이야기';
  static const String more = '더 보기';

  /// 큐레이션이 비었을 때. 아이 탓도, 고장도 아니라는 톤.
  static const String recommendedEmpty = '새 이야기를 준비하고 있어!';

  /// "15분" — 예상 소요 시간.
  static String minutes(int value) => '$value분';

  // ── 섹션4 행성 위젯 ──
  static const String planetTitle = '내 행성';
  static const String planetAction = '가기';

  // ── 프로필 없음 게이트 (F-01) ──
  static const String profileNeededTitle = '먼저 누가 이야기할지 알려줄래?';
  static const String profileNeededAction = '내 이름 만들기';

  // ── 아이 프로필 전환 모달(모달 6) 호출 지점 ──
  static const String switchChildTitle = '누가 이야기할 거야?';
  static const String close = '닫기';
}
