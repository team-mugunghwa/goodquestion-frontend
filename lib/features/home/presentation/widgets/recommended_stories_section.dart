import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/story_card.dart';
import '../../domain/entities/recommended_story.dart';
import 'home_hero_card.dart';

/// 섹션3 — 추천 이야기. 고정 큐레이션 2~3개를 **세로 표지 카드**로 놓습니다.
///
/// 개인화 추천은 MVP 범위 밖입니다. 여기서 하는 일은 "다음에 뭐 할래?"에
/// 대한 **선택지를 세 개 이하로 줄여 주는 것** 하나뿐입니다.
///
/// ## 이야기 목록과 **같은 [StoryCard]** 입니다
///
/// 표지(세로 2:3) 위, 제목과 시간·주제 칩이 그 아래. 같은 이야기가 홈과
/// 목록에서 다른 물건처럼 보이면 안 됩니다. 다른 건 **크기뿐**입니다.
///
/// ## 왜 16:9·가로 배치를 버렸나
///
/// 한때 이 자리는 표지를 16:9(또는 가로 배치의 정사각)로 잘랐습니다. 표지
/// 원본은 전부 세로(1024×1536)라 16:9 는 세로 44%만 남깁니다 — 그림책 표지
/// 구도(인물 전신 + 여백)에서 44%만 남기면 표지가 아니라 장면 클로즈업이고,
/// 잘려 나가는 건 대개 인물의 얼굴입니다. **표지는 자르지 않습니다.**
/// (`docs/COVER_ART_GUIDE.md` 7장)
///
/// 가로 배치가 지키려던 것은 "표지 하나가 화면 절반을 먹지 않게"였습니다.
/// 그건 배치가 아니라 **크기**로 풉니다 — [coverWidthOf] 가 남는 세로에서
/// 카드 폭을 거꾸로 계산합니다. 폭을 못박으면 1280×800 에 맞춘 값이
/// 1024×768 에서 칩을 하단 내비 밑으로 밀어냅니다.
///
/// 이어하기가 없을 때는 1순위가 히어로([TodayStoryCard])로 올라가므로 여기
/// 목록에서는 빠집니다 — 같은 표지가 한 화면에 두 번 나오지 않게.
class RecommendedStoriesSection extends StatelessWidget {
  const RecommendedStoriesSection({
    super.key,
    required this.stories,
    required this.metrics,
    required this.onStoryTap,
    required this.onMoreTap,
    required this.coverWidth,
  });

  /// 태블릿에서 카드 폭의 범위.
  ///
  /// 아래쪽(200)은 **칩 두 개가 한 줄에 서는 최소 폭**입니다. 시간 칩(약 69) +
  /// 사이(8) + 네 글자 주제 칩(약 74) + 카드 안쪽 여백(32). 이보다 좁히면
  /// 주제 이름이 "옛이…" 로 잘립니다 — 정보량을 지키려고 이 카드를 쓰는
  /// 것이므로 폭을 줄여 칩을 죽이면 앞뒤가 안 맞습니다.
  ///
  /// 위쪽(240)은 홈에서 추천이 히어로보다 커 보이지 않는 한계입니다.
  static const double coverMinWide = 200;
  static const double coverMaxWide = 240;

  final List<RecommendedStory> stories;
  final ScreenMetrics metrics;
  final void Function(RecommendedStory story) onStoryTap;
  final VoidCallback onMoreTap;

  /// [coverWidthOf] 로 잰 표지 폭. 홈 본문이 세로 예산을 알고 있어서
  /// 여기서 직접 재지 않고 받습니다. (스켈레톤도 같은 값을 씁니다)
  final double coverWidth;

  /// 카드 한 장의 폭.
  ///
  /// 세로 표지는 폭이 곧 높이(×1.5)라, **폭을 어디서 가져오느냐가 곧 세로
  /// 예산**입니다. 그래서 모자란 쪽 기준이 화면마다 다릅니다.
  ///
  /// - 폰: 세로는 스크롤로 벌 수 있고 폭이 모자랍니다. 이야기 목록과 같은
  ///   2열로 나눠 갖습니다. 여기서 폭을 고정하면 화면 오른쪽 절반이 빕니다.
  /// - 태블릿: 폭은 남고 **세로가 모자랍니다.** 그래서 본문에 실제로 주어진
  ///   높이([bodyHeight])에서 히어로·섹션 제목·여백·글자 블록을 뺀 나머지를
  ///   표지가 씁니다. 상수로 못박으면 1280×800 에 맞춘 값이 1024×768 에서
  ///   칩을 하단 내비 밑으로 밀어냅니다 — 기기마다 남는 세로가 다릅니다.
  static double coverWidthOf(
    BuildContext context,
    ScreenMetrics metrics,
    double maxWidth,
    double bodyHeight,
  ) {
    if (!metrics.isWide) return (maxWidth - AppSpacing.lg) / 2;
    // 책장 위에 이미 놓인 것들 — 본문 위 여백, 히어로, 히어로~섹션 사이,
    // 섹션 제목 줄("더 보기" 버튼이 높이를 정합니다), 제목~책 사이.
    final double above =
        AppSpacing.md +
        HomeHeroCard.estimateHeight(context, metrics, maxWidth) +
        AppSpacing.lg +
        AppSizes.tapChildSecondary +
        AppSpacing.md;
    // 카드 안에서 표지가 아닌 부분 — 제목 두 줄과 칩 한 줄, 안쪽 여백.
    // 이야기 목록 그리드와 **같은 식**을 씁니다.
    final double body = StoryCard.bodyHeightOf(context, metrics);
    // 2:3 이라 남은 세로를 1.5로 나누면 폭입니다.
    //
    // 낮고 넓은 창(1280×800)에서는 이 값이 최솟값에 걸립니다 — 산수로 안
    // 되는 자리라 카드는 최소 폭으로 서고 아래가 접힙니다. 폭을 더 줄여
    // 첫 화면에 밀어 넣는 대신 칩을 지키는 쪽을 골랐습니다.
    return ((bodyHeight - above - body) / 1.5).clamp(
      coverMinWide,
      coverMaxWide,
    );
  }

  /// 카드 한 장이 차지하는 세로 = 표지 + 글자 블록.
  /// 로딩 스켈레톤이 같은 자리를 잡는 데 씁니다.
  static double heightOf(
    BuildContext context,
    ScreenMetrics metrics,
    double coverWidth,
  ) => StoryCard.heightOf(context, metrics, coverWidth);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _SectionHeading(
                text: HomeStrings.recommendedTitle,
                metrics: metrics,
              ),
            ),
            _MoreButton(metrics: metrics, onTap: onMoreTap),
          ],
        ),
        // 제목과 카드 사이는 md 입니다. 세로 표지는 폭의 1.5배라 여기서 lg 로
        // 벌리면 표지 밑 제목이 첫 화면 밖으로 밀립니다.
        const SizedBox(height: AppSpacing.md),
        if (stories.isEmpty)
          // 큐레이션이 비는 건 기획 사고지만, 그래도 화면이 무너지면 안 됩니다.
          Text(
            HomeStrings.recommendedEmpty,
            style: metrics.text(AppTypography.kidBody),
          )
        else
          // 가로 스크롤을 쓰지 않습니다 — 아이는 오른쪽에 더 있다는 걸
          // 모르면 아예 못 봅니다. 큐레이션이 늘면 아래로 접힙니다.
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: <Widget>[
              for (final RecommendedStory story in stories)
                SizedBox(
                  width: coverWidth,
                  // 높이를 못박습니다. 안 그러면 제목이 두 줄인 카드만
                  // 아래로 튀어나와 한 줄에 늘어놓은 카드의 밑선이 어긋납니다.
                  height: heightOf(context, metrics, coverWidth),
                  child: _card(story),
                ),
            ],
          ),
      ],
    );
  }

  Widget _card(RecommendedStory story) => StoryCard(
    title: story.title,
    image: story.image,
    estimatedMinutes: story.estimatedMinutes,
    topicLabel: story.topicTag,
    metrics: metrics,
    onTap: () => onStoryTap(story),
  );
}

/// 섹션 제목.
///
/// 예전에는 마지막 단어만 브랜드 색으로 강조했는데, 한 제목 안에서 글자
/// 색이 갈리면 두 문장처럼 읽히고 다른 화면 제목과도 어긋납니다.
/// 제목은 어디서나 한 가지 잉크색입니다. (`docs/DESIGN_SYSTEM.md` 3장)
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.text, required this.metrics});

  final String text;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: metrics.text(AppTypography.kidTitle));
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.metrics, required this.onTap});

  final ScreenMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      borderRadius: AppRadius.pill,
      semanticLabel: '${HomeStrings.recommendedTitle} ${HomeStrings.more}',
      child: Container(
        height: AppSizes.tapChildSecondary,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              HomeStrings.more,
              style: metrics
                  .text(AppTypography.kidLabel)
                  .copyWith(color: AppColors.brandBlueDeep),
            ),
            const Icon(
              AppIcons.chevronRight,
              size: AppSizes.iconInline,
              color: AppColors.brandBlueDeep,
            ),
          ],
        ),
      ),
    );
  }
}
