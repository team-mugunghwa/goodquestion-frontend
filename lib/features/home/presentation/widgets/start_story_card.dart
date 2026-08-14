import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/kid_button.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/story_cover.dart';

/// 진행 중인 세션이 없을 때 섹션2 자리에 들어가는 카드.
///
/// 빈 상태를 "없음"으로 그리지 않습니다. 이어하기 카드와 **같은 온도감**(코드
/// 표지 + 입체 그림자)을 써서, 진행 중인 이야기가 있든 없든 홈의 첫인상이
/// 흔들리지 않게 합니다. 표지 위에는 마스코트 자리(지금은 로고마크)를 둡니다.
/// (`docs/DESIGN_SYSTEM.md` 10장)
class StartStoryCard extends StatelessWidget {
  const StartStoryCard({
    super.key,
    required this.metrics,
    required this.onStart,
  });

  final ScreenMetrics metrics;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onStart,
      borderRadius: AppRadius.xl,
      semanticLabel: '${HomeStrings.startTitle} ${HomeStrings.startAction}',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppColors.surface,
              Color.alphaBlend(AppColors.brandBlueSurface, AppColors.surface),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.brandBlue.withValues(alpha: 0.28),
              blurRadius: 48,
              offset: const Offset(0, 22),
            ),
            ...AppShadows.lift,
          ],
        ),
        child: metrics.isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const Expanded(flex: 5, child: _CoverPanel()),
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: _Body(metrics: metrics, onStart: onStart),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _CoverPanel(),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: _Body(metrics: metrics, onStart: onStart),
                  ),
                ],
              ),
      ),
    );
  }
}

/// 코드 표지 + 마스코트 자리 + "새 이야기" 표식.
class _CoverPanel extends StatelessWidget {
  const _CoverPanel();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          StoryCover(
            palette: StoryCoverPalette.forTopic(null),
            motifIcon: AppIcons.stories,
          ),
          // 마스코트 자리 — 캐릭터 에셋이 나오면 이 로고마크를 갈아 끼웁니다.
          Center(
            child: Image.asset(
              AppAssets.logoMark,
              width: AppSizes.illustration * 0.72,
              height: AppSizes.illustration * 0.72,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
          const Positioned(
            top: AppSpacing.md,
            left: AppSpacing.md,
            child: _StartBadge(),
          ),
        ],
      ),
    );
  }
}

class _StartBadge extends StatelessWidget {
  const _StartBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            AppIcons.add,
            size: AppSizes.iconInline,
            color: AppColors.brandBlueDeep,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            HomeStrings.startBadge,
            style: AppTypography.kidLabel.copyWith(
              color: AppColors.brandBlueDeep,
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.metrics, required this.onStart});

  final ScreenMetrics metrics;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          HomeStrings.startTitle,
          style: metrics.text(AppTypography.kidTitle),
        ),
        const SizedBox(height: AppSpacing.lg),
        KidPrimaryButton(
          icon: AppIcons.stories,
          label: HomeStrings.startAction,
          labelStyle: metrics.text(AppTypography.kidButton),
          onPressed: onStart,
        ),
      ],
    );
  }
}
