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

  /// 화면 좌우 여백. 태블릿에서는 더 넓게 잡습니다.
  static const double screenPaddingCompact = md;
  static const double screenPaddingExpanded = xl;
}

/// 모서리 둥글기 토큰.
abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
}
