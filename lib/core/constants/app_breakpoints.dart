/// 반응형 브레이크포인트.
///
/// 이 앱의 주 타겟은 **태블릿/iPad**입니다. 레이아웃은 [expanded] 기준으로 먼저
/// 설계하고 좁은 화면으로 좁혀 나갑니다.
///
/// 화면 분기는 `MediaQuery.of(context).size` 가 아니라 `LayoutBuilder` 의
/// `constraints.maxWidth` 로 판단하세요. MediaQuery 는 화면 전체 크기라서
/// iPad 의 Split View 나 중첩 레이아웃에서 잘못된 값을 줍니다.
abstract final class AppBreakpoints {
  /// 폰 세로. `< 600`
  static const double compact = 600;

  /// 작은 태블릿 · 폴더블 · 폰 가로. `600 ~ 839`
  static const double medium = 600;

  /// 태블릿 · iPad (주 타겟). `>= 840`
  static const double expanded = 840;

  /// 본문 콘텐츠의 최대 폭.
  ///
  /// 태블릿에서 텍스트를 화면 끝까지 늘리면 한 줄이 너무 길어져 읽기 힘듭니다.
  static const double maxContentWidth = 720;
}

/// 현재 폭이 어느 구간인지 나타냅니다.
enum WindowSizeClass {
  compact,
  medium,
  expanded;

  static WindowSizeClass fromWidth(double width) {
    if (width >= AppBreakpoints.expanded) return WindowSizeClass.expanded;
    if (width >= AppBreakpoints.medium) return WindowSizeClass.medium;
    return WindowSizeClass.compact;
  }

  bool get isCompact => this == WindowSizeClass.compact;

  /// 태블릿 2단 레이아웃을 쓸 수 있는 폭인지.
  bool get isExpanded => this == WindowSizeClass.expanded;
}
