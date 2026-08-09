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

/// 진행 중인 세션이 없을 때 섹션2 자리에 들어가는 카드.
///
/// 빈 상태를 "없음"으로 그리지 않습니다. 아이 화면의 빈 상태는 **캐릭터가
/// 말을 거는 형태**이고, 시선을 바로 아래 추천 섹션으로 넘겨야 합니다.
/// (`docs/DESIGN_SYSTEM.md` 10장)
///
/// 이어하기 카드보다 낮게 두는 것도 의도입니다 — 여기서 화면을 다 쓰면
/// 추천 카드가 접히는 곳 아래로 내려갑니다.
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.lift,
        ),
        child: Row(
          children: <Widget>[
            // 캐릭터 에셋이 나오면 이 이미지를 갈아 끼웁니다.
            Image.asset(
              AppAssets.logoMark,
              width: AppSizes.illustration,
              height: AppSizes.illustration,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
