import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../../core/widgets/stardust_chip.dart';
import '../../domain/entities/child_profile.dart';

/// 섹션1 — 상단 바. 왼쪽에 지금 이야기하는 아이, 오른쪽에 별가루 잔액.
///
/// 데이터가 오기 전에도 **자리를 먼저 그립니다.** 상단 바가 나중에 나타나면
/// 아이가 이미 손을 뻗은 자리에 다른 게 들어옵니다.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.metrics,
    required this.onProfileTap,
    this.child,
    this.stardustBalance,
    this.isLoading = false,
  });

  final ScreenMetrics metrics;

  /// 아이 프로필 전환 모달(모달 6)을 엽니다.
  final VoidCallback onProfileTap;

  /// 아직 아이 프로필이 없으면 `null`.
  final ChildProfile? child;

  /// 로딩 중이거나 불러오지 못했으면 `null`.
  final int? stardustBalance;

  /// 스켈레톤을 보여 줄지. **로딩 중일 때만** `true` 입니다.
  ///
  /// 에러 상태에서도 계속 두면 상단 바가 영원히 깜빡입니다 — 아이 눈에는
  /// "아직 오는 중"으로 보여서 본문의 "다시 불러오기" 버튼을 안 누릅니다.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final int? balance = stardustBalance;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        AppSpacing.sm,
        metrics.screenPadding,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Flexible(
            child: _ProfileArea(
              metrics: metrics,
              child: child,
              isLoading: isLoading,
              onTap: onProfileTap,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (isLoading)
            const SkeletonBox(
              width: AppSizes.tapChildPrimary,
              height: AppSizes.tapGuardian,
            )
          // 잔액을 모르는 채 0 을 보여 주면 아이가 별가루를 잃었다고 읽습니다.
          else if (balance != null)
            StardustChip.day(count: balance),
        ],
      ),
    );
  }
}

class _ProfileArea extends StatelessWidget {
  const _ProfileArea({
    required this.metrics,
    required this.child,
    required this.isLoading,
    required this.onTap,
  });

  final ScreenMetrics metrics;
  final ChildProfile? child;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ChildProfile? profile = child;
    return PressScale(
      onTap: onTap,
      borderRadius: AppRadius.pill,
      semanticLabel: profile == null
          ? HomeStrings.profileSemantics
          : '${profile.name} · ${HomeStrings.profileSemantics}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Avatar(profile: profile, isLoading: isLoading),
            const SizedBox(width: AppSpacing.sm),
            if (isLoading)
              const SkeletonBox(width: AppSizes.mic, height: AppSpacing.lg)
            // 아이 프로필이 없으면 이름 자리를 비워 둡니다. 여기서 "이름을
            // 만들어"라고 부르면, 정작 불러오기에 실패한 경우에도 그렇게 보입니다.
            else if (profile != null)
              Flexible(
                child: Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: metrics.text(AppTypography.kidLabel),
                ),
              ),
            const SizedBox(width: AppSpacing.sm),
            // 아이콘 하나로 "바꾸기"를 알릴 수는 없지만, 이름이 곧 라벨입니다.
            const Icon(
              AppIcons.switchChild,
              size: AppSizes.iconInline,
              color: AppColors.ink500,
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, required this.isLoading});

  final ChildProfile? profile;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SkeletonBox(
        width: AppSizes.tapChildSecondary,
        height: AppSizes.tapChildSecondary,
      );
    }

    final String? avatar = profile?.avatar;
    final String name = profile?.name ?? '';
    // 흰 링 + 부드러운 그림자로 또렷해진 배경에서 아바타를 분리합니다.
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        boxShadow: AppShadows.soft,
      ),
      child: ClipOval(
        child: SizedBox.square(
          dimension: AppSizes.tapChildSecondary,
          child: avatar == null
              ? _AvatarFallback(name: name)
              : Image.asset(
                  avatar,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder:
                      (BuildContext context, Object error, StackTrace? _) =>
                          _AvatarFallback(name: name),
                ),
        ),
      ),
    );
  }
}

/// 아바타를 아직 고르지 않았을 때. 이름 첫 글자를 파스텔 면 위에 둡니다.
class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final String initial = name.isEmpty ? '' : name.substring(0, 1);
    return ColoredBox(
      color: AppColors.brandMint,
      child: Center(
        child: initial.isEmpty
            ? const Icon(
                AppIcons.childProfile,
                size: AppSizes.iconInline,
                color: AppColors.ink900,
              )
            : Text(initial, style: AppTypography.kidLabel),
      ),
    );
  }
}
