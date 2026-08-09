import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/skeleton_box.dart';

/// 홈 본문(섹션2~4)의 골격.
///
/// 실제 콘텐츠와 **같은 순서·같은 여백**이어야 합니다. 모양이 다르면
/// 데이터가 도착할 때 화면이 덜컹거립니다.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key, required this.metrics});

  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        AppSpacing.lg,
        metrics.screenPadding,
        metrics.screenPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // 섹션2 — 이어하기 카드
          SkeletonBox(
            aspectRatio: metrics.isWide ? 21 / 9 : 4 / 5,
            borderRadius: AppRadius.xl,
          ),
          SizedBox(height: metrics.sectionGap),
          // 섹션3 — 추천
          const SkeletonBox(width: 220, height: AppSpacing.xl),
          const SizedBox(height: AppSpacing.lg),
          SkeletonCardList(
            count: metrics.isWide ? 3 : 2,
            columns: metrics.isWide ? 3 : 1,
            aspectRatio: metrics.isWide ? 3 / 4 : 16 / 6,
          ),
          SizedBox(height: metrics.sectionGap),
          // 섹션4 — 행성 위젯
          const SkeletonBox(
            height: AppSizes.tapChildPrimary + AppSpacing.xl,
            borderRadius: AppRadius.xl,
          ),
        ],
      ),
    );
  }
}
