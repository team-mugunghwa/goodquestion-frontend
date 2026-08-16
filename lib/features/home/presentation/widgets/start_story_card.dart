import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/screen_metrics.dart';
import 'home_hero_card.dart';

/// 진행 중인 세션도, 추천 큐레이션도 없을 때의 **마지막 안전망**.
///
/// 평소 빈 상태는 추천 1순위를 히어로에 앉힌 [TodayStoryCard] 가 맡습니다.
/// 여기까지 오는 건 큐레이션이 통째로 빈 기획 사고인데, 그때도 아이에게는
/// 나가는 문이 하나 보여야 합니다. (`docs/SCREEN_RECIPE.md` 2장)
///
/// 껍데기는 [HomeHeroCard] 로 다른 두 상태와 같습니다. 보여 줄 이야기가 없어서
/// 배경은 브랜드 코드 표지([StoryCover])로 채우고, 제목 아래 메타 줄은 아예
/// 두지 않습니다 — 채울 게 없는 줄을 만들면 그게 다시 빈 여백입니다.
/// 메타 줄이 없어서 이 카드만 다른 둘보다 한 줄 낮습니다(가로에서는 버튼
/// 높이 88 이 바닥이라 136).
class StartStoryCard extends StatelessWidget {
  const StartStoryCard({
    super.key,
    required this.metrics,
    required this.onStart,
  });

  final ScreenMetrics metrics;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return HomeHeroCard(
      metrics: metrics,
      // 표지도 제목 매칭도 없으니 코드 표지(브랜드 파스텔 + 말풍선)로 떨어집니다.
      image: null,
      storyTitle: HomeStrings.startTitle,
      eyebrowIcon: AppIcons.add,
      eyebrowLabel: HomeStrings.startBadge,
      actionIcon: AppIcons.stories,
      actionLabel: HomeStrings.startAction,
      onTap: onStart,
    );
  }
}
