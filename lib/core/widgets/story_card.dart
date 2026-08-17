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
    this.coverAspectRatio,
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

  /// 표지 비율을 강제로 정합니다. `null` 이면 배치에 맞는 기본값을 씁니다
  /// (가로=정사각 / 세로=16:9). 이야기 목록은 [StoryThumbnail.portrait] 를
  /// 넘겨 그림책 세로 표지로 씁니다. 홈 카드는 넘기지 않아 16:9 를 유지합니다.
  final double? coverAspectRatio;

  @override
  Widget build(BuildContext context) {
    final Widget thumbnail = StoryThumbnail(
      image: image,
      fallbackIcon: AppIcons.stories,
      // 표지 이미지가 없으면 주제별 코드 표지로 채웁니다.
      topicTag: topicLabel,
      title: title,
      // 가로 배치에서 16:9 를 쓰면 이미지가 납작해져서 제목 옆에 붙은
      // 장식처럼 보입니다. 정사각이 글자 블록 높이와 맞습니다.
      aspectRatio:
          coverAspectRatio ??
          (horizontal ? StoryThumbnail.square : StoryThumbnail.wide),
    );

    final Widget body = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 제목은 남는 높이 안에서 접힙니다. 셀 높이를 아무리 정확히
          // 계산해도 폰트·글자 확대 설정에 따라 몇 px 씩 어긋나는데,
          // Flexible 이면 그 몇 px 때문에 넘치는 대신 줄 수가 줄어듭니다.
          Flexible(
            child: Text(
              title,
              maxLines: titleMaxLines,
              overflow: TextOverflow.ellipsis,
              // 화면 제목 크기(kidTitle 32)를 카드 안에 그대로 쓰면 좁은 셀에서
              // 제목이 잘립니다. 카드 제목은 버튼 급(22) 굵은 글씨면 충분합니다.
              // kidButton 은 흰 글자라 카드에서는 잉크색으로 바꿉니다.
              style: metrics
                  .text(AppTypography.kidButton)
                  .copyWith(color: AppColors.ink900),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // 칩은 **한 줄**입니다. 줄바꿈을 허용하면 좁은 셀에서만 두 줄이
          // 되어 카드 높이가 제각각이 되고, 고정 높이 그리드에서는 넘칩니다.
          // 자리가 모자라면 칩 안의 라벨이 줄어듭니다.
          Row(
            children: <Widget>[
              Flexible(
                child: KidInfoChip(
                  icon: AppIcons.duration,
                  label: '$estimatedMinutes분',
                  metrics: metrics,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: KidInfoChip(label: topicLabel, metrics: metrics),
              ),
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
                  // 표지는 **비율로만** 높이가 정해집니다. 예전처럼 남는
                  // 높이를 먹게 두면 제목이 한 줄인 카드의 표지만 길어져서,
                  // 한 줄에 늘어놓은 카드들의 그림 높이가 제각각이 됩니다.
                  thumbnail,
                  // 대신 글자 블록이 남는 높이를 가져갑니다. 제목이 짧으면
                  // 아래가 비고, 길어도 셀 밖으로 넘치지 않습니다.
                  Flexible(child: body),
                ],
              ),
      ),
    );
  }
}
