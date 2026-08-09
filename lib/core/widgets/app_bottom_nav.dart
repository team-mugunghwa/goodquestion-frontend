import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_icons.dart';
import '../constants/app_strings.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'press_scale.dart';

/// 하단 내비게이션의 네 자리. 순서를 바꾸지 마세요.
///
/// 아이는 위치로 기억합니다. 화면마다 순서가 다르면 "아까 여기 있었는데"가
/// 통하지 않습니다. (PRD F-02)
enum AppNavTab {
  home(AppRoutes.home, AppIcons.home, NavStrings.home),
  stories(AppRoutes.stories, AppIcons.stories, NavStrings.stories),
  words(AppRoutes.words, AppIcons.words, NavStrings.words),
  myPage(AppRoutes.myPage, AppIcons.myPage, NavStrings.myPage);

  const AppNavTab(this.route, this.icon, this.label);

  final String route;
  final IconData icon;
  final String label;
}

/// 홈 · 이야기 · 단어장 · 마이페이지를 오가는 고정 내비게이션.
///
/// Material 의 `NavigationBar` 를 쓰지 않는 이유는 두 가지입니다.
/// 라벨·아이콘 크기가 보호자 기준(24/12sp)이라 아이에게 작고, 선택 표시가
/// 테마상 `stardustGlow`(노랑)인데 **노란색은 별가루에만** 써야 합니다.
///
/// 선택된 탭은 색만으로 구분하지 않습니다 — `brandBlueSurface` 알약 면이
/// 함께 붙습니다. (`docs/DESIGN_SYSTEM.md` 12장)
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.current});

  final AppNavTab current;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.soft,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          // 글자 크기 설정을 키운 기기에서 넘치지 않도록 "최소" 높이입니다.
          constraints: const BoxConstraints(minHeight: AppSizes.bottomNav),
          child: Row(
            children: <Widget>[
              for (final AppNavTab tab in AppNavTab.values)
                Expanded(
                  child: _NavItem(
                    tab: tab,
                    selected: tab == current,
                    // 같은 탭을 다시 눌러도 히스토리를 쌓지 않습니다.
                    onTap: tab == current ? null : () => context.go(tab.route),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppNavTab tab;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? AppColors.brandBlueDeep : AppColors.ink500;
    return Semantics(
      selected: selected,
      child: PressScale(
        onTap: onTap,
        borderRadius: AppRadius.pill,
        semanticLabel: tab.label,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.brandBlueSurface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Icon(tab.icon, size: AppSizes.iconChild, color: color),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.kidLabel.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
