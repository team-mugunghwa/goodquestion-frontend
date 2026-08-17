import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/child_avatar.dart';
import '../../../../core/widgets/kid_button.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../mypage/domain/entities/my_page_summary.dart';
import '../../domain/entities/child_profile.dart';

/// 아이 프로필 전환 시트. 이 계정의 아이들을 늘어놓고 하나를 고릅니다.
///
/// 고른 아이의 `childId` 를 돌려줍니다. 그냥 닫으면 `null` 입니다 —
/// 호출한 쪽은 값이 있을 때만 홈을 다시 받습니다.
Future<String?> showChildSwitchSheet(
  BuildContext context, {
  required ScreenMetrics metrics,
  required List<MyPageChild> children,
  ChildProfile? current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    // 기본 시트는 폭 640 에서 잘려 아이 카드가 한 줄에 두 명도 안 들어갑니다.
    constraints: const BoxConstraints(maxWidth: AppSizes.sheetMaxWidth),
    builder: (BuildContext sheetContext) => _KidSheet(
      title: HomeStrings.switchChildTitle,
      metrics: metrics,
      children: <Widget>[
        if (children.isEmpty)
          Text(current?.name ?? '', style: metrics.text(AppTypography.kidBody))
        else
          // 아이가 몇 명이든 한 줄에 늘어놓고, 넘치면 다음 줄로 접습니다.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: <Widget>[
              for (final MyPageChild child in children)
                _ChildOption(
                  child: child,
                  // 홈 응답에는 아이 id 가 없어 이름으로 맞춥니다.
                  selected: child.name == current?.name,
                  metrics: metrics,
                  onTap: () => Navigator.of(sheetContext).pop(child.childId),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.lg),
        KidSecondaryButton(
          icon: AppIcons.close,
          label: HomeStrings.close,
          labelStyle: metrics.text(AppTypography.kidButton),
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
      ],
    ),
  );
}

/// 시트 안의 아이 하나. 얼굴(아바타) + 이름 + 나이.
///
/// 고른 아이는 색만이 아니라 **테두리와 체크**로도 구분합니다 —
/// 색을 구분하기 어려운 아이도 누가 선택됐는지 알아야 합니다.
class _ChildOption extends StatelessWidget {
  const _ChildOption({
    required this.child,
    required this.selected,
    required this.metrics,
    required this.onTap,
  });

  final MyPageChild child;
  final bool selected;
  final ScreenMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: PressScale(
        onTap: onTap,
        borderRadius: AppRadius.xl,
        semanticLabel: child.name,
        child: Container(
          width: AppSizes.mic + AppSpacing.xl,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandBlueSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: selected ? AppColors.brandBlueDeep : AppColors.ink100,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ChildAvatar(
                name: child.name,
                image: child.avatar,
                diameter: AppSizes.tapChildSecondary,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                child.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: metrics
                    .text(AppTypography.kidLabel)
                    .copyWith(color: AppColors.ink900),
              ),
              const SizedBox(height: AppSpacing.xs),
              Icon(
                selected ? AppIcons.checked : AppIcons.unchecked,
                size: AppSizes.iconInline,
                color: selected ? AppColors.brandBlueDeep : AppColors.ink300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 아이 프로필이 없는 계정이 이야기에 들어가려 할 때. (PRD F-01 게이트)
///
/// 홈에 들어오는 것 자체를 막지 않습니다 — 무엇을 하는 앱인지 보여 준 다음,
/// **행동하려는 순간에만** 프로필 생성으로 보냅니다. 처음부터 막으면 아이는
/// 이 앱이 뭔지도 모른 채 로그인 화면만 봅니다.
Future<void> showProfileNeededSheet(
  BuildContext context, {
  required ScreenMetrics metrics,
  required VoidCallback onCreate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) => _KidSheet(
      title: HomeStrings.profileNeededTitle,
      metrics: metrics,
      children: <Widget>[
        KidPrimaryButton(
          icon: AppIcons.childProfile,
          label: HomeStrings.profileNeededAction,
          labelStyle: metrics.text(AppTypography.kidButton),
          onPressed: () {
            Navigator.of(context).pop();
            onCreate();
          },
        ),
      ],
    ),
  );
}

/// 아이용 시트의 공통 뼈대. 캐릭터가 말을 걸고, 선택지는 하나뿐입니다.
class _KidSheet extends StatelessWidget {
  const _KidSheet({
    required this.title,
    required this.metrics,
    required this.children,
  });

  final String title;
  final ScreenMetrics metrics;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // 태블릿 가로에서는 화면 높이가 낮아 시트가 세로로 넘칩니다.
    // 스크롤을 허용하고, 일러스트도 남는 높이에 맞춰 줄입니다.
    final double illustration = metrics.isWide
        ? AppSizes.mic
        : AppSizes.illustration;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          metrics.screenPadding,
          AppSpacing.md,
          metrics.screenPadding,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.asset(
              AppAssets.logoMark,
              width: illustration,
              height: illustration,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.bubbleMaxWidth,
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: metrics.text(AppTypography.kidTitle),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ...children,
          ],
        ),
      ),
    );
  }
}
