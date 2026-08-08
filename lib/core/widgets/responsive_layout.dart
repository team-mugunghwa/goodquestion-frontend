import 'package:flutter/material.dart';

import '../constants/app_breakpoints.dart';

/// 폭에 따라 다른 위젯을 그립니다.
///
/// `MediaQuery` 대신 [LayoutBuilder] 를 쓰는 이유는 iPad 의 Split View 나
/// 중첩 레이아웃에서도 **실제로 주어진 폭**을 기준으로 판단하기 위해서입니다.
///
/// ```dart
/// ResponsiveLayout(
///   compact: (_) => const QuestionListView(),
///   expanded: (_) => const QuestionSplitView(),  // 태블릿 2단
/// )
/// ```
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
  });

  /// `< 600` — 폰
  final WidgetBuilder compact;

  /// `600 ~ 839` — 작은 태블릿·폴더블. 생략하면 [compact] 사용
  final WidgetBuilder? medium;

  /// `>= 840` — 태블릿·iPad (주 타겟). 생략하면 [medium] → [compact] 순으로 대체
  final WidgetBuilder? expanded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return switch (WindowSizeClass.fromWidth(constraints.maxWidth)) {
          WindowSizeClass.expanded => (expanded ?? medium ?? compact)(context),
          WindowSizeClass.medium => (medium ?? compact)(context),
          WindowSizeClass.compact => compact(context),
        };
      },
    );
  }
}

/// 콘텐츠 폭을 제한하고 가운데 정렬합니다.
///
/// 태블릿에서 본문을 화면 끝까지 늘리면 한 줄이 너무 길어져 읽기 어렵습니다.
/// 목록·폼·본문 화면은 이걸로 감싸세요.
class ContentContainer extends StatelessWidget {
  const ContentContainer({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// 현재 폭 구간을 편하게 읽기 위한 확장.
extension WindowSizeClassX on BuildContext {
  /// ⚠️ 화면 전체 크기 기준입니다. 레이아웃 분기는 가급적 [ResponsiveLayout]
  /// (= LayoutBuilder) 을 쓰고, 이건 폰트 크기·패딩 같은 소소한 조정에만 쓰세요.
  WindowSizeClass get windowSize =>
      WindowSizeClass.fromWidth(MediaQuery.sizeOf(this).width);
}
