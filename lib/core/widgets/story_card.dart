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

/// 이야기 카드. 홈의 추천, 이야기 목록의 그리드가 **같은 카드**를 씁니다.
///
/// 카드에 정보를 더 얹고 싶어지는 유혹을 여기서 막습니다. 노출은
/// **대표 이미지 → 제목 → 시간·주제 배지 2개**까지입니다. 난이도·요약·역할은
/// 이야기 상세의 몫입니다. (PRD F-03)
///
/// 이미지가 카드 면적을 지배해야 합니다 — 아이는 제목이 아니라 그림을 보고
/// 고릅니다.
class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.title,
    required this.image,
    required this.estimatedMinutes,
    required this.topicLabel,
    required this.metrics,
    required this.onTap,
    this.horizontal = false,
    this.titleMaxLines = 2,
  });

  final String title;
  final String? image;
  final int estimatedMinutes;
  final String topicLabel;
  final ScreenMetrics metrics;
  final VoidCallback onTap;

  /// 폰에서 쓰는 가로 배치(썸네일 왼쪽 · 글자 오른쪽).
  final bool horizontal;

  final int titleMaxLines;

  @override
  Widget build(BuildContext context) {
    final Widget thumbnail = StoryThumbnail(
      image: image,
      fallbackIcon: AppIcons.stories,
      // 표지 이미지가 없으면 주제별 코드 표지로 채웁니다.
      topicTag: topicLabel,
      // 가로 배치에서 16:9 를 쓰면 이미지가 납작해져서 제목 옆에 붙은
      // 장식처럼 보입니다. 정사각이 글자 블록 높이와 맞습니다.
      aspectRatio: horizontal ? StoryThumbnail.square : StoryThumbnail.wide,
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
        child: horizontal
            ? Row(
                children: <Widget>[
                  Expanded(flex: 4, child: thumbnail),
                  Expanded(flex: 6, child: body),
                ],
              )
            : Column(
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
