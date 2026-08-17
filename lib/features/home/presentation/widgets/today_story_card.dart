import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../domain/entities/recommended_story.dart';
import 'home_hero_card.dart';

/// 진행 중인 세션이 없을 때 섹션2를 채우는 **오늘의 이야기**.
///
/// 빈 상태를 "없음"으로 그리지 않습니다. 예전 [StartStoryCard] 는 표지 자리에
/// 로고마크를 두고 "골라볼까?" 하며 목록으로 밀었는데, 그러면 히어로 · 추천
/// 카드 · 더 보기가 **전부 같은 곳**으로 가는 중복이 생기고 아이는 표지 자리에서
/// 아무 정보도 얻지 못합니다.
///
/// 그래서 추천 1순위 한 편을 히어로에 그대로 앉힙니다. 껍데기가
/// [HomeHeroCard] 로 이어하기와 같으므로, 이어하던 이야기가 있든 없든 홈의
/// 첫인상과 손이 가는 자리가 바뀌지 않습니다.
///
/// 누르면 **이야기 상세**로 갑니다 — 세션을 만드는 곳은 상세 화면 하나뿐이라
/// 홈이 직접 시작하지 않습니다. 버튼 문구도 그 도착지에 맞춰
/// [HomeStrings.todayAction] 입니다.
class TodayStoryCard extends StatelessWidget {
  const TodayStoryCard({
    super.key,
    required this.story,
    required this.metrics,
    required this.onTap,
  });

  final RecommendedStory story;
  final ScreenMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HomeHeroCard(
      metrics: metrics,
      image: story.image,
      storyTitle: story.title,
      topicTag: story.topicTag,
      eyebrowIcon: AppIcons.stardust,
      eyebrowLabel: HomeStrings.todayBadge,
      detail: _Meta(story: story, metrics: metrics),
      actionIcon: AppIcons.stories,
      actionLabel: HomeStrings.todayAction,
      onTap: onTap,
    );
  }
}

/// "🕐 20분 · 옛이야기" — 한 줄.
///
/// 이야기 목록의 카드는 같은 정보를 칩 두 개로 줍니다. 여기서는 안 씁니다 —
/// 히어로의 글자 면은 제목·진행·버튼으로 이미 세 덩이라, 칩까지 얹으면 눈이
/// 무엇부터 볼지 못 정합니다. 한 줄([HomeStrings.storyMeta])로 눕히고 앞에
/// 시계 글리프만 붙입니다.
///
/// 이 줄은 추천 책장에는 없습니다. 히어로는 아이가 지금 고를 한 편이라
/// "얼마나 걸리는지"가 결정에 쓰이지만, 책장은 표지로 훑는 자리입니다.
class _Meta extends StatelessWidget {
  const _Meta({required this.story, required this.metrics});

  final RecommendedStory story;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          AppIcons.duration,
          size: AppSizes.iconInline,
          color: AppColors.ink500,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            HomeStrings.storyMeta(story.estimatedMinutes, story.topicTag),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: metrics.text(AppTypography.kidLabel),
          ),
        ),
      ],
    );
  }
}
