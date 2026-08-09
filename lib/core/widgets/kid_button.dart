import 'package:flutter/material.dart';

import '../constants/app_icons.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'press_scale.dart';

/// 아이 화면의 주 버튼. 높이 88, 알약 모양, `brandBlueDeep` 면 + 흰 글자.
///
/// Material 의 `FilledButton` 을 쓰지 않는 이유: 앱 테마의 버튼은 **보호자
/// 화면 기준**(높이 48, 반경 12)입니다. 아이 손가락에는 48이 부족합니다.
/// (`docs/DESIGN_SYSTEM.md` 5장)
///
/// **아이콘만 있는 버튼을 만들지 마세요.** 초1~3은 아이콘 관습을 모릅니다.
/// 그래서 [icon] 과 [label] 이 둘 다 필수입니다.
class KidPrimaryButton extends StatelessWidget {
  const KidPrimaryButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.labelStyle,
    this.expand = false,
  });

  final IconData icon;

  /// 짧을수록 좋습니다. 한 단어를 기본으로 하세요.
  final String label;

  /// `null` 이면 비활성. 처리 중(중복 탭 방지)에도 `null` 을 넘기세요.
  final VoidCallback? onPressed;

  /// 좁은 화면에서 `AppTypography.scaled` 로 줄인 스타일을 넘기는 자리입니다.
  final TextStyle? labelStyle;

  /// 가로를 꽉 채울지. 화면 하단에 고정되는 단일 CTA 는 `true`.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return PressScale(
      onTap: onPressed,
      borderRadius: AppRadius.pill,
      semanticLabel: label,
      child: Container(
        height: AppSizes.tapChildPrimary,
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: enabled ? AppColors.brandBlueDeep : AppColors.ink300,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: AppSizes.iconChild, color: AppColors.surface),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                label,
                style: labelStyle ?? AppTypography.kidButton,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 아이 화면의 뒤로가기. 아이콘 + "뒤로" 한 단어, 터치 타겟 64.
///
/// `AppBar` 의 기본 back 버튼(24dp 아이콘, 라벨 없음)을 쓰지 않습니다 —
/// 아이 화면에서 아이콘 단독은 금지이고, 48조차 작습니다.
class KidBackButton extends StatelessWidget {
  const KidBackButton({super.key, required this.onPressed, this.labelStyle});

  final VoidCallback onPressed;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onPressed,
      borderRadius: AppRadius.pill,
      semanticLabel: AppStrings.back,
      child: Container(
        height: AppSizes.tapChildSecondary,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              AppIcons.back,
              size: AppSizes.iconChild,
              color: AppColors.brandBlueDeep,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              AppStrings.back,
              style: (labelStyle ?? AppTypography.kidLabel).copyWith(
                color: AppColors.brandBlueDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
