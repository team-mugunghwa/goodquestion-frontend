import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/stardust_chip.dart';
import '../../../../core/widgets/story_thumbnail.dart';
import '../../domain/entities/planet_summary.dart';

/// 섹션4 — 내 행성 미니 뷰.
///
/// **이어하기·추천보다 작아야 합니다.** 행성은 "다음 회차에 돌아올 이유"를
/// 상기시키는 장치이지 놀이 진입 유도가 아닙니다. 여기가 커지면 아이는
/// 말하기 대신 꾸미기를 하러 옵니다. (PRD F-08)
///
/// 그래서 이 카드만 한 줄이고, 썸네일은 원형 64 입니다.
class PlanetWidget extends StatelessWidget {
  const PlanetWidget({
    super.key,
    required this.planet,
    required this.metrics,
    required this.onTap,
  });

  final PlanetSummary planet;
  final ScreenMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      borderRadius: AppRadius.xl,
      semanticLabel:
          '${HomeStrings.planetTitle} · '
          '${HomeStrings.stardust} ${planet.stardustBalance}개',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: <Widget>[
            ClipOval(
              child: SizedBox.square(
                dimension: AppSizes.tapChildSecondary,
                child: StoryThumbnail(
                  image: planet.thumbnailImage,
                  fallbackIcon: AppIcons.planet,
                  aspectRatio: StoryThumbnail.square,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                HomeStrings.planetTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: metrics.text(AppTypography.kidLabel),
              ),
            ),
            StardustChip.day(count: planet.stardustBalance),
            const SizedBox(width: AppSpacing.sm),
            Text(
              HomeStrings.planetAction,
              style: metrics
                  .text(AppTypography.kidLabel)
                  .copyWith(color: AppColors.brandBlueDeep),
            ),
            const Icon(
              AppIcons.chevronRight,
              size: AppSizes.iconInline,
              color: AppColors.brandBlueDeep,
            ),
          ],
        ),
      ),
    );
  }
}
