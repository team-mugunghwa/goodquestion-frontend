import 'package:flutter/material.dart';

import '../constants/app_icons.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// 별가루 잔액 칩. 홈 상단 바·행성 위젯·상점·완료 화면에서 **같은 모양**입니다.
///
/// ## 낮에는 면으로, 밤에는 글자로
///
/// `stardust`(#FFC24B) 로 낮 배경에 글씨를 쓰면 대비가 1.6:1 이라 보이지
/// 않습니다. 그래서 낮에는 [StardustChip.day] — `stardustGlow` 면 + `ink900`
/// 글자, 밤에는 [StardustChip.night] — 투명 면 + `stardust` 글자(9.7:1)입니다.
///
/// 화면 전체가 차가운 파스텔인 이유가 이 칩 하나를 눈에 띄게 하기 위해서입니다.
/// **다른 곳에 노란색을 쓰지 마세요.** (`docs/DESIGN_SYSTEM.md` 3장)
class StardustChip extends StatelessWidget {
  const StardustChip.day({super.key, required this.count}) : _isNight = false;

  const StardustChip.night({super.key, required this.count}) : _isNight = true;

  final int count;
  final bool _isNight;

  @override
  Widget build(BuildContext context) {
    final Color foreground = _isNight ? AppColors.stardust : AppColors.ink900;
    return Semantics(
      // "✦ 7" 만으로는 무엇의 7 인지 알 수 없습니다.
      label: '${HomeStrings.stardust} $count개',
      excludeSemantics: true,
      // 테두리를 두르지 않습니다. 노란 선으로 가둔 알약은 스티커처럼
      // 보였습니다. 낮에는 옅은 금빛 면 + 아주 옅은 발광으로, 밤에는
      // 반투명한 금빛 면으로 "빛나는 것"처럼 둡니다.
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: _isNight
              ? AppColors.stardust.withValues(alpha: 0.16)
              : AppColors.stardustGlow,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: _isNight
              ? null
              : <BoxShadow>[
                  BoxShadow(
                    color: AppColors.stardust.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              AppIcons.stardust,
              size: AppSizes.iconCaption,
              color: _isNight ? AppColors.stardust : AppColors.stardustDeep,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$count',
              style: AppTypography.kidLabel.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
