import 'package:flutter/widgets.dart';

import '../constants/app_breakpoints.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// 화면의 여백·글자 크기를 폭 하나로 결정합니다.
///
/// 기준은 **태블릿(≥840dp)** 이고, 좁아지면 여백과 글자를 같은 비율로 줄입니다.
/// 위젯마다 `if (isPhone)` 을 흩뿌리면 어느 위젯은 줄고 어느 위젯은 안 줄어서
/// 폰에서만 레이아웃이 어긋납니다.
///
/// ```dart
/// LayoutBuilder(
///   builder: (context, constraints) {
///     final m = ScreenMetrics.of(constraints.maxWidth);
///     return Padding(
///       padding: EdgeInsets.all(m.screenPadding),
///       child: Text('제목', style: m.text(AppTypography.kidTitle)),
///     );
///   },
/// )
/// ```
///
/// `MediaQuery` 가 아니라 [LayoutBuilder] 가 준 폭으로 만드세요 —
/// iPad Split View 에서 화면 전체 크기는 거짓말을 합니다.
/// (`docs/ARCHITECTURE.md` 7장)
@immutable
class ScreenMetrics {
  const ScreenMetrics._({
    required this.windowSize,
    required this.screenPadding,
    required this.sectionGap,
  });

  factory ScreenMetrics.of(double maxWidth) {
    final WindowSizeClass size = WindowSizeClass.fromWidth(maxWidth);
    return switch (size) {
      WindowSizeClass.expanded => const ScreenMetrics._(
        windowSize: WindowSizeClass.expanded,
        screenPadding: AppSpacing.screenPaddingExpanded,
        sectionGap: AppSpacing.xxxl,
      ),
      WindowSizeClass.medium => const ScreenMetrics._(
        windowSize: WindowSizeClass.medium,
        screenPadding: AppSpacing.lg,
        sectionGap: AppSpacing.xxl,
      ),
      WindowSizeClass.compact => const ScreenMetrics._(
        windowSize: WindowSizeClass.compact,
        screenPadding: AppSpacing.screenPaddingCompact,
        sectionGap: AppSpacing.xl,
      ),
    };
  }

  final WindowSizeClass windowSize;

  /// 화면 좌우 여백.
  final double screenPadding;

  /// 섹션과 섹션 사이. 아이 화면은 요소가 크니 여백도 커야 덜 답답합니다.
  final double sectionGap;

  /// 카드를 가로로 나란히 놓을 수 있는 폭인지.
  ///
  /// 좁으면 카드를 줄이는 게 아니라 **레이아웃을 바꿉니다.**
  bool get isWide => !windowSize.isCompact;

  /// 그리드 열 수. 태블릿 2열, 폰 1열. (`docs/DESIGN_SYSTEM.md`)
  int get gridColumns => isWide ? 2 : 1;

  /// 토큰 글자 크기를 현재 폭에 맞춰 줄입니다. (expanded 100% 기준)
  TextStyle text(TextStyle base) => AppTypography.scaled(base, windowSize);

  /// 글자 한 줄이 실제로 차지하는 높이. 기기의 글자 확대 설정까지 반영합니다.
  ///
  /// 그리드 셀 높이를 계산할 때 씁니다 — `childAspectRatio` 를 눈대중으로
  /// 정하면 카드 아래에 흰 여백이 남거나 글자가 잘립니다.
  double lineHeight(BuildContext context, TextStyle base) {
    final TextStyle style = text(base);
    final double size = MediaQuery.textScalerOf(
      context,
    ).scale(style.fontSize ?? 16);
    return size * (style.height ?? 1.2);
  }
}
