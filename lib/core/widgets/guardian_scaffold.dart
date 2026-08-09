import 'package:flutter/material.dart';

import '../constants/app_icons.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_canvas.dart';
import 'responsive_layout.dart';

/// 보호자 화면의 뼈대. 마이페이지 · 리포트 · 설정이 같은 것을 씁니다.
///
/// ## 아이 화면과 다르게 생겨야 합니다
///
/// 아이는 못 읽고, 보호자는 **읽으러 옵니다.** 그래서 여기는 큰 그림·큰 글씨가
/// 아니라 성인용 정보 밀도입니다 — 터치 타겟 48, 본문 16sp, 모서리 16,
/// 흰 카드 + 얇은 테두리. (`docs/DESIGN_SYSTEM.md` 2장)
///
/// 본문은 [ContentContainer] 로 720dp 에서 잘립니다. 태블릿에서 글을 화면
/// 끝까지 늘리면 한 줄이 너무 길어져 읽기 어렵습니다.
class GuardianScaffold extends StatelessWidget {
  const GuardianScaffold({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.trailing,
    this.bottomNav,
    this.subtitle,
  });

  final String title;

  /// 제목 아래 한 줄. 리포트 상세의 "지우 · 방귀 뀌는 며느리 · 8/7" 처럼
  /// **무엇에 대한 화면인지** 식별해야 할 때만 씁니다.
  final String? subtitle;

  /// `null` 이면 뒤로가기를 그리지 않습니다. 탭 루트 화면(마이페이지)이 그렇습니다.
  final VoidCallback? onBack;

  /// 헤더 오른쪽. 리포트 목록의 "아이: 지우" 같은 읽기 전용 라벨.
  final Widget? trailing;

  /// 하단 내비. 탭 루트 화면만 가집니다.
  final Widget? bottomNav;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppCanvas.guardian(
        child: SafeArea(
          bottom: bottomNav == null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: ContentContainer(
                  child: Row(
                    children: <Widget>[
                      if (onBack != null) ...<Widget>[
                        IconButton(
                          onPressed: onBack,
                          icon: const Icon(AppIcons.back),
                          iconSize: AppSizes.iconGuardian,
                          tooltip: AppStrings.back,
                          color: AppColors.ink900,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(title, style: text.headlineLarge),
                            if (subtitle != null) ...<Widget>[
                              const SizedBox(height: AppSpacing.xs),
                              Text(subtitle!, style: text.bodySmall),
                            ],
                          ],
                        ),
                      ),
                      if (trailing != null) ...<Widget>[
                        const SizedBox(width: AppSpacing.md),
                        trailing!,
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(child: ContentContainer(child: child)),
              if (bottomNav != null) bottomNav!,
            ],
          ),
        ),
      ),
    );
  }
}
