import 'package:flutter/material.dart';

import '../constants/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// 보호자 화면의 그룹 목록. 제목 + 흰 카드 안에 행들.
///
/// 마이페이지의 메뉴와 설정의 항목이 **같은 모양**이어야 합니다. 화면마다
/// 다르게 그리면 같은 앱의 설정처럼 안 보입니다.
class GuardianSection extends StatelessWidget {
  const GuardianSection({super.key, required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (title != null) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              0,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Text(
              title!,
              style: text.titleMedium?.copyWith(color: AppColors.ink500),
            ),
          ),
        ],
        // 얇은 테두리 대신 옅은 그림자. 캔버스와 같은 명도의 선은 화면을
        // 칸막이처럼 보이게 합니다.
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0) const Divider(height: 1, indent: AppSpacing.md),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 그룹 안의 한 행. 누르면 어딘가로 갑니다.
class GuardianTile extends StatelessWidget {
  const GuardianTile({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.trailingText,
    this.showBadge = false,
    this.showChevron = true,
    this.enabled = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  /// 오른쪽 회색 글자. 계정 표시값처럼 값을 보여 줄 때.
  final String? trailingText;

  /// 새 것이 있다는 빨간 점. **보호자 화면에서만** 빨강을 씁니다.
  final bool showBadge;

  final bool showChevron;

  /// 비활성. 아이 프로필이 없을 때의 리포트 메뉴가 그렇습니다.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color foreground = enabled ? AppColors.ink900 : AppColors.ink300;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Semantics(
        button: enabled && onTap != null,
        enabled: enabled,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.tapGuardian),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: AppSizes.iconGuardian, color: foreground),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Text(
                  label,
                  style: text.bodyLarge?.copyWith(color: foreground),
                ),
              ),
              if (showBadge) ...<Widget>[
                const _NewDot(),
                const SizedBox(width: AppSpacing.sm),
              ],
              if (trailingText != null) ...<Widget>[
                Text(trailingText!, style: text.bodySmall),
                const SizedBox(width: AppSpacing.sm),
              ],
              if (showChevron && onTap != null)
                Icon(
                  AppIcons.chevronRight,
                  size: AppSizes.iconGuardian,
                  color: enabled ? AppColors.ink500 : AppColors.ink300,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 켜고 끄는 행. 알림 설정처럼 즉시 반영되는 것.
class GuardianSwitchTile extends StatelessWidget {
  const GuardianSwitchTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
  });

  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: AppSizes.tapGuardian),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(label, style: text.bodyLarge),
                if (description != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(description!, style: text.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// "새 것이 있다"는 빨간 점.
///
/// ⚠️ 빨강은 **보호자 화면 전용**입니다. 아이 화면에 이걸 쓰지 마세요.
/// (`docs/DESIGN_SYSTEM.md` 3장)
class _NewDot extends StatelessWidget {
  const _NewDot();

  @override
  Widget build(BuildContext context) => Container(
    width: AppSpacing.sm,
    height: AppSpacing.sm,
    decoration: const BoxDecoration(
      color: AppColors.danger,
      shape: BoxShape.circle,
    ),
  );
}
