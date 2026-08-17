import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/child_avatar.dart';
import '../../domain/entities/my_page_summary.dart';

/// 섹션2 — 현재 아이 프로필 카드.
///
/// 이 화면의 첫 질문은 **"지금 누구의 계정으로 보고 있는가"** 입니다.
/// 그래서 최상단이고, 활동 요약은 숫자 둘까지만 붙습니다.
class ChildProfileCard extends StatelessWidget {
  const ChildProfileCard({
    super.key,
    required this.summary,
    required this.onSwitch,
    required this.onEdit,
    required this.onCreate,
  });

  final MyPageSummary summary;
  final VoidCallback onSwitch;
  final VoidCallback onEdit;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final MyPageChild? child = summary.child;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.soft,
      ),
      child: child == null
          ? _NoChild(onCreate: onCreate)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _Avatar(child: child),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        '${child.name} · ${MyPageStrings.childAge(child.age)}',
                        style: text.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(AppIcons.edit),
                      iconSize: AppSizes.iconGuardian,
                      tooltip: MyPageStrings.editChild,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    _Stat(
                      icon: AppIcons.stories,
                      label: MyPageStrings.completedStories(
                        summary.completedStories,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    _Stat(
                      icon: AppIcons.stardust,
                      label: MyPageStrings.stardust(summary.stardust),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // 아이가 한 명뿐이면 전환할 곳이 없습니다. 버튼은 두되
                // 강조하지 않습니다 — 없애면 두 번째 아이를 등록한 보호자가
                // 전환 방법을 못 찾습니다.
                if (summary.canSwitchChild)
                  FilledButton.icon(
                    onPressed: onSwitch,
                    icon: const Icon(AppIcons.switchChild),
                    label: const Text(MyPageStrings.switchChild),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: onSwitch,
                    icon: const Icon(AppIcons.switchChild),
                    label: const Text(MyPageStrings.switchChild),
                  ),
              ],
            ),
    );
  }
}

class _NoChild extends StatelessWidget {
  const _NoChild({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(MyPageStrings.noChild, style: text.bodyLarge),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(AppIcons.add),
          label: const Text(MyPageStrings.createChild),
        ),
      ],
    );
  }
}

/// 아이 얼굴. 홈·단어장과 **같은 공용 위젯**을 씁니다 — 화면마다 다른
/// 이니셜 원과 아이콘 원이 섞이면 같은 앱으로 안 보입니다.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.child});

  final MyPageChild child;

  @override
  Widget build(BuildContext context) => ChildAvatar(
    name: child.name,
    image: child.avatar,
    diameter: AppSizes.tapGuardian,
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: AppSizes.iconGuardian, color: AppColors.ink500),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
