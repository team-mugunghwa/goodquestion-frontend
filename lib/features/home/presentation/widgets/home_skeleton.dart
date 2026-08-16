import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/skeleton_box.dart';
import 'home_hero_card.dart';
import 'recommended_stories_section.dart';

/// 홈 본문(섹션2~3)의 골격.
///
/// 실제 콘텐츠와 **같은 순서·같은 여백**이어야 합니다. 모양이 다르면
/// 데이터가 도착할 때 화면이 덜컹거립니다. 그래서 히어로 높이는 눈대중이
/// 아니라 [HomeHeroCard.estimateHeight] 로 실제 카드와 같은 식을 씁니다.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key, required this.metrics});

  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => _body(
        context,
        RecommendedStoriesSection.coverWidthOf(
          context,
          metrics,
          constraints.maxWidth - metrics.screenPadding * 2,
          constraints.maxHeight,
        ),
      ),
    );
  }

  Widget _body(BuildContext context, double coverWidth) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        AppSpacing.md,
        metrics.screenPadding,
        metrics.screenPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 섹션2 — 히어로 (표지 전폭 배경 + 글자 오버레이)
          SkeletonBox(
            height: HomeHeroCard.estimateHeight(context, metrics),
            borderRadius: AppRadius.xl,
          ),
          const SizedBox(height: AppSpacing.lg),
          // 섹션3 — 추천. 제목 줄의 높이는 실제로 "더 보기" 버튼(64)이 정합니다.
          const SizedBox(
            height: AppSizes.tapChildSecondary,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SkeletonBox(width: 220, height: AppSpacing.xl),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // 추천 줄과 같은 폭·같은 배치. 그리드로 폭을 나누면 실제 책과
          // 어긋나서 데이터가 올 때 화면이 덜컹거립니다.
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: <Widget>[
              // 큐레이션은 2~3개입니다. 스켈레톤이 더 길면 데이터가 온
              // 순간 남는 자리가 사라지면서 화면이 위로 튑니다.
              for (int i = 0; i < 3; i++)
                SkeletonBox(
                  width: coverWidth,
                  height: RecommendedStoriesSection.heightOf(
                    context,
                    metrics,
                    coverWidth,
                  ),
                  borderRadius: AppRadius.lg,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
