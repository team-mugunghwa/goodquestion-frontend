import 'package:flutter/material.dart';

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
  });

  final IconData icon;

  /// 짧을수록 좋습니다. 한 단어를 기본으로 하세요.
  final String label;

  final VoidCallback? onPressed;

  /// 좁은 화면에서 `AppTypography.scaled` 로 줄인 스타일을 넘기는 자리입니다.
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onPressed,
      borderRadius: AppRadius.pill,
      semanticLabel: label,
      child: Container(
        height: AppSizes.tapChildPrimary,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.brandBlueDeep,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: AppSizes.iconChild,
              color: AppColors.surface,
              // 라벨과 함께 하나의 뜻이라 아이콘은 따로 읽지 않습니다.
              semanticLabel: null,
            ),
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
