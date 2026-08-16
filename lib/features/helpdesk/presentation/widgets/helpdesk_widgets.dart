import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// 고객 지원 화면들이 함께 쓰는 조각.
///
/// 보호자 화면 문법을 따릅니다 — 흰 카드 + 얇은 테두리, 본문 16sp, 모서리 16.
/// (`docs/DESIGN_SYSTEM.md` 2장)

/// 상태 배지. 답변 여부, 공지 분류처럼 한 단어짜리 표시에 씁니다.
///
/// **색만으로 뜻을 전하지 않습니다.** 항상 글자가 함께 있습니다.
class HelpdeskBadge extends StatelessWidget {
  const HelpdeskBadge({
    super.key,
    required this.label,
    this.color = AppColors.ink500,
    this.background,
  });

  final String label;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: background ?? AppColors.ink100,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 본문을 담는 흰 카드.
class HelpdeskCard extends StatelessWidget {
  const HelpdeskCard({super.key, required this.child, this.padding});

  final EdgeInsets? padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.ink100),
      ),
      child: child,
    );
  }
}

/// 날짜를 `2026. 8. 16.` 으로 적습니다.
///
/// `intl` 을 새로 들이지 않으려고 직접 만듭니다. 이 앱에서 날짜를 쓰는 곳은
/// 리포트와 여기뿐이고, 패키지 하나를 더 얹을 만큼은 아닙니다.
String formatDate(DateTime? value) {
  if (value == null) return '';
  final DateTime local = value.toLocal();
  return '${local.year}. ${local.month}. ${local.day}.';
}
