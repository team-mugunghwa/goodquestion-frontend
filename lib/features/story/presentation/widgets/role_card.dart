import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../domain/entities/story_detail.dart';

/// 섹션5 — 내 역할 카드. **이 화면에서 가장 중요한 정보입니다.**
///
/// 별도 카드로 승격한 이유: 아이가 아무 정보 없이 장면에 던져지면 "무슨
/// 역할로 무엇을 말해야 하는지" 모른 채 위축됩니다. 도입문 아래 한 문단으로
/// 묻어 두면 아무도 안 읽습니다. 완주율에 직결되는 정보라 카드로 뺐습니다.
class RoleCard extends StatelessWidget {
  const RoleCard({super.key, required this.role, required this.metrics});

  final StoryRole role;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        // 흰 카드가 아니라 파스텔 면입니다. 주변 섹션과 달라 보여야
        // 아이 눈이 여기 한 번 멈춥니다.
        color: AppColors.brandBlueSurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // 역할 캐릭터 에셋이 나오면 이 이미지를 갈아 끼웁니다.
          Image.asset(
            role.characterImage ?? AppAssets.logoMark,
            width: AppSizes.illustration,
            height: AppSizes.illustration,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stack) =>
                    Image.asset(
                      AppAssets.logoMark,
                      width: AppSizes.illustration,
                      height: AppSizes.illustration,
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  StoryDetailStrings.roleTitle(role.name),
                  style: metrics.text(AppTypography.kidTitle),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  role.description,
                  style: metrics.text(AppTypography.kidBody),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
