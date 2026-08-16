/// 간격 토큰. 4의 배수로 통일합니다.
///
/// 위젯에 `EdgeInsets.all(13)` 같은 임의의 숫자를 쓰지 마세요.
/// 4명이 각자 다른 값을 쓰면 화면마다 여백이 미묘하게 달라집니다.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// 아이 화면의 섹션 사이. 요소가 크니까 여백도 커야 덜 답답합니다.
  static const double xxxl = 64;

  /// 화면 좌우 여백. 태블릿에서는 더 넓게 잡습니다.
  static const double screenPaddingCompact = md;
  static const double screenPaddingExpanded = xl;
}

/// 모서리 둥글기 토큰.
///
/// 로고의 Q가 부풀어 오른 3D 형태라서, 이 앱의 모서리는 전반적으로 큽니다.
/// **아이 화면은 [lg] 이상, 보호자 화면은 [md]** 를 기본으로 쓰세요.
/// 같은 화면에서 반경을 3종류 이상 섞지 마세요.
abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;

  /// 아이 화면의 큰 카드·이야기 썸네일·말풍선.
  static const double xl = 32;

  /// 완전히 둥근 모양. 마이크 버튼, 별가루 칩, 아바타.
  static const double pill = 999;
}

/// 터치 타겟과 고정 크기.
///
/// 초1~3의 손가락은 어른보다 크게 흔들립니다. 아이가 누르는 것은
/// **48dp 로 충분하지 않습니다.**
abstract final class AppSizes {
  /// 보호자·시스템 화면의 최소 터치 타겟. (Material 기준)
  static const double tapGuardian = 48;

  /// 아이 화면의 보조 버튼. 다시 듣기, 단어 담기, 뒤로.
  static const double tapChildSecondary = 64;

  /// 아이 화면의 주 버튼. 다음, 보내기, 이야기 시작하기.
  static const double tapChildPrimary = 88;

  /// 마이크 버튼. 화면에서 가장 큰 조작 요소이고, 늘 같은 자리에 있어야
  /// 아이가 눈으로 찾지 않고 손이 먼저 갑니다.
  static const double mic = 120;

  /// 아이 화면 아이콘.
  static const double iconChild = 40;

  /// 하단 내비게이션 아이콘. [iconChild] 40 은 라벨과 함께 두면 내비가
  /// 둔해 보여서, 내비에서만 한 단계 줄입니다. 터치 타겟은 탭 전체입니다.
  static const double iconNav = 32;

  /// 보호자 화면 아이콘.
  static const double iconGuardian = 24;

  /// 하단 내비게이션 높이. (홈·이야기·단어장·마이페이지)
  static const double bottomNav = 80;

  /// 칩·버튼 라벨 옆에 붙는 인라인 글리프. (별가루 개수 앞의 ✦, "더 보기 ›")
  ///
  /// 아이 화면이라고 이걸 [iconChild] 로 키우지 마세요. 18sp 라벨 옆에 40 짜리
  /// 아이콘이 붙으면 글자가 아이콘의 부속처럼 보입니다.
  /// **아이가 누르는 버튼의 아이콘**은 [iconChild] 가 맞습니다.
  static const double iconInline = iconGuardian;

  /// 빈 화면·에러 화면의 캐릭터 일러스트 지름.
  static const double illustration = 160;

  /// 말풍선 최대 폭. 이보다 넓으면 한 줄이 길어져 아이가 눈으로 놓칩니다.
  static const double bubbleMaxWidth = 560;

  /// 행성 조작 버튼(회전·확대·되돌리기)의 지름.
  static const double planetControl = 72;
}
