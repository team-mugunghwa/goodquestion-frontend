import 'package:flutter/material.dart';

import '../constants/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'kid_chips.dart';
import 'press_scale.dart';
import 'screen_metrics.dart';
import 'story_thumbnail.dart';

/// 이야기 카드. 이야기 목록(`/stories`)의 그리드가 씁니다.
///
/// 홈의 추천 줄은 이 카드가 아니라 **표지만 세운 책장**입니다 — 32sp 제목과
/// 칩 두 개를 담으려면 카드 폭이 210dp 는 돼야 하는데, 홈은 히어로 아래에
/// 그만한 세로가 없습니다. (`RecommendedStoriesSection` 참고)
///
/// 카드에 정보를 더 얹고 싶어지는 유혹을 여기서 막습니다. 노출은
/// **대표 이미지 → 제목 → 시간·주제 배지 2개**까지입니다. 난이도·요약·역할은
/// 이야기 상세의 몫입니다. (PRD F-03)
///
/// 이미지가 카드 면적을 지배해야 합니다 — 아이는 제목이 아니라 그림을 보고
/// 고릅니다.
///
/// ## 표지는 **세로 2:3 한 가지**입니다
///
/// 예전에는 배치에 따라 16:9(홈)·정사각(폰 가로 배치)으로도 담았습니다.
/// 그런데 표지 원본은 전부 세로(1024×1536)라, 16:9 는 세로 44%·정사각은 67%만
/// 남기고 나머지를 잘라냅니다 — 그림책 표지에서 잘려 나가는 건 대개 인물의
/// 얼굴입니다. 그래서 비율 선택지를 없애고 **원본 비율 그대로 세웁니다.**
/// (`docs/COVER_ART_GUIDE.md`)
class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.title,
    required this.image,
    required this.estimatedMinutes,
    required this.topicLabel,
    required this.metrics,
    required this.onTap,
    this.titleMaxLines = 2,
  });

  final String title;
  final String? image;
  final int estimatedMinutes;
  final String topicLabel;
  final ScreenMetrics metrics;
  final VoidCallback onTap;

  final int titleMaxLines;

  @override
  Widget build(BuildContext context) {
    final Widget thumbnail = StoryThumbnail(
      image: image,
      fallbackIcon: AppIcons.stories,
      // 표지 이미지가 없으면 주제별 코드 표지로 채웁니다. 코드 표지도 같은
      // 2:3 이라 표지가 있는 카드와 높이가 어긋나지 않습니다.
      topicTag: topicLabel,
      title: title,
      aspectRatio: StoryThumbnail.portrait,
    );

    final Widget body = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            title,
            maxLines: titleMaxLines,
            overflow: TextOverflow.ellipsis,
            style: metrics.text(AppTypography.kidTitle),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              KidInfoChip(
                icon: AppIcons.duration,
                label: '$estimatedMinutes분',
                metrics: metrics,
              ),
              KidInfoChip(label: topicLabel, metrics: metrics),
            ],
          ),
        ],
      ),
    );

    return PressScale(
      onTap: onTap,
      borderRadius: AppRadius.xl,
      semanticLabel: '$title · $estimatedMinutes분 · $topicLabel',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 그리드 안에서는 카드 높이가 셀에 맞춰 고정되므로, 이미지가
            // 남는 높이를 먹고 글자 블록이 잘리지 않게 합니다.
            Flexible(child: thumbnail),
            body,
          ],
        ),
      ),
    );
  }
}
