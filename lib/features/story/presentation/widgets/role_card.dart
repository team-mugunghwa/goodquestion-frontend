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
///
/// ## 서버가 주는 건 이름 하나뿐입니다
///
/// `StoryDetailResponse.childRole` 이 전부이고, 역할 설명문은 기획에도 API
/// 에도 없습니다. 그래서 **이름 자체가 카드의 무게를 지도록** 그립니다 —
/// 작은 눈길잡이 한 줄 위에 크고 진한 이름 한 줄. 설명 두 줄이 채우던
/// 면적을 글자를 늘려서가 아니라 **위계와 색으로** 대신합니다.
///
/// 이름이 비어 있으면(시드 미완) 이 카드를 아예 그리지 않습니다. 빈 파스텔
/// 상자는 "고장 난 화면"으로 보입니다. → `story_detail_view.dart`
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
      child: MergeSemantics(
        // 좁으면 카드를 줄이는 게 아니라 **레이아웃을 바꿉니다.** 폰에서
        // 160 짜리 그림 옆에 남는 폭은 120 남짓이고, 거기서 역할 이름이
        // 세 줄로 쪼개지면 이 카드가 가진 유일한 정보가 읽히지 않습니다.
        child: metrics.isWide
            ? Row(
                // 그림과 이름을 **한 덩어리로 가운데**에 둡니다. 이름 한 줄만
                // 남아서, 왼쪽에 붙이면 태블릿 폭(1200+)에서 오른쪽 절반이
                // "빠진 자리"처럼 보입니다. 가운데 배지처럼 놓으면 짧은 것이
                // 모자란 게 아니라 의도한 것으로 읽힙니다.
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _Avatar(
                    image: role.characterImage,
                    size: AppSizes.illustration,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Flexible(
                    child: _RoleLabel(
                      role: role,
                      metrics: metrics,
                      centered: false,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _Avatar(image: role.characterImage, size: AppSizes.mic),
                  const SizedBox(height: AppSpacing.md),
                  _RoleLabel(role: role, metrics: metrics, centered: true),
                ],
              ),
      ),
    );
  }
}

/// 역할 캐릭터. 파스텔 면 위에 **흰 원반**으로 얹습니다.
///
/// 그림만 덩그러니 두면 배경이 옅어서 카드에 얹힌 게 아니라 얼룩처럼
/// 보입니다. 원반 + `soft` 그림자면 메달처럼 읽혀서, 에셋이 아직 로고
/// 마크인 지금도 "자리를 비워 둔 것"이 아니라 "그렇게 생긴 것"이 됩니다.
class _Avatar extends StatelessWidget {
  const _Avatar({this.image, required this.size});

  /// 역할 캐릭터 에셋이 나오면 여기로 들어옵니다. 서버 필드가 아닙니다.
  final String? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: AppShadows.soft,
      ),
      child: Image.asset(
        image ?? AppAssets.logoMark,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            Image.asset(
              AppAssets.logoMark,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
      ),
    );
  }
}

class _RoleLabel extends StatelessWidget {
  const _RoleLabel({
    required this.role,
    required this.metrics,
    required this.centered,
  });

  final StoryRole role;
  final ScreenMetrics metrics;

  /// 폰(세로 배치)에서는 가운데, 태블릿(가로 배치)에서는 왼쪽 정렬.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          StoryDetailStrings.roleIntro,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: metrics.text(AppTypography.kidLabel),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          StoryDetailStrings.roleName(role.name),
          textAlign: centered ? TextAlign.center : TextAlign.start,
          // 이 화면에서 가장 진한 글자입니다. 파스텔은 면으로만 쓰고 글자에는
          // `Deep` 을 쓰라는 규칙 그대로. (`docs/DESIGN_SYSTEM.md` 3장)
          style: metrics
              .text(AppTypography.kidTitle)
              .copyWith(color: AppColors.brandBlueDeep),
        ),
      ],
    );
  }
}
