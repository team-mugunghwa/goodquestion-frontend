import 'package:flutter/widgets.dart';

import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// 홈의 여백·글자 크기를 폭 하나로 결정합니다.
///
/// 화면 기준은 **태블릿(≥840dp)** 이고, 좁아지면 여백과 글자를 같은 비율로
/// 줄입니다. 위젯마다 `if (isPhone)` 을 흩뿌리면 어느 위젯은 줄고 어느 위젯은
/// 안 줄어서, 폰에서만 레이아웃이 어긋납니다.
///
/// `MediaQuery` 가 아니라 [LayoutBuilder] 가 준 폭으로 만드세요 —
/// iPad Split View 에서 화면 전체 크기는 거짓말을 합니다.
/// (`docs/ARCHITECTURE.md` 7장)
@immutable
class HomeMetrics {
  const HomeMetrics._({
    required this.windowSize,
    required this.screenPadding,
    required this.sectionGap,
  });

  factory HomeMetrics.of(double maxWidth) {
    final WindowSizeClass size = WindowSizeClass.fromWidth(maxWidth);
    return switch (size) {
      WindowSizeClass.expanded => const HomeMetrics._(
        windowSize: WindowSizeClass.expanded,
        screenPadding: AppSpacing.screenPaddingExpanded,
        sectionGap: AppSpacing.xxxl,
      ),
      WindowSizeClass.medium => const HomeMetrics._(
        windowSize: WindowSizeClass.medium,
        screenPadding: AppSpacing.lg,
        sectionGap: AppSpacing.xxl,
      ),
      WindowSizeClass.compact => const HomeMetrics._(
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

  /// 추천 이야기를 가로로 나란히 놓을 수 있는 폭인지.
  ///
  /// 좁으면 카드를 줄이는 게 아니라 **레이아웃을 바꿉니다** — 세로 목록으로.
  bool get isWide => !windowSize.isCompact;

  /// 토큰 글자 크기를 현재 폭에 맞춰 줄입니다. (expanded 100% 기준)
  TextStyle text(TextStyle base) => AppTypography.scaled(base, windowSize);
}
