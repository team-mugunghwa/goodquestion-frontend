import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/story_thumbnail.dart';
import '../../domain/entities/recommended_story.dart';
import 'home_hero_card.dart';

/// 섹션3 — 추천 이야기. 고정 큐레이션 2~3개를 **책장에 꽂듯 세워** 놓습니다.
///
/// 개인화 추천은 MVP 범위 밖입니다. 여기서 하는 일은 "다음에 뭐 할래?"에
/// 대한 **선택지를 세 개 이하로 줄여 주는 것** 하나뿐입니다.
///
/// ## 왜 16:9 크롭을 버렸나
///
/// 전에는 카드가 폭을 나눠 갖고 표지를 16:9 로 잘랐습니다. 표지 원본은 전부
/// 세로(1024×1536)라 그러면 세로 44%만 남습니다 — 그림책 표지 구도(인물 전신 +
/// 여백)에서 44%만 남기면 표지가 아니라 장면 클로즈업이 됩니다.
/// **표지는 자르지 않습니다.** (`docs/COVER_ART_GUIDE.md`)
///
/// ## 왜 [StoryCard] 를 쓰지 않나
///
/// 이야기 목록(`/stories`)과 같은 카드를 쓰려고 먼저 재 봤습니다. 그 카드는
/// 32sp 제목 한 줄 + 칩 두 개라 폭이 **210dp 는 돼야** 제목이 안 잘립니다.
/// 그런데 표지를 자르지 않으면 카드 높이가 폭의 1.5배 + 글자 블록이라,
/// 210dp 카드는 373dp 높이입니다 — 태블릿 가로 본문 610dp 에서 히어로(272) ·
/// 섹션 제목 줄(64) · 여백(56)을 빼면 218dp 밖에 안 남습니다.
///
/// 그래서 홈에서는 **카드가 아니라 책**을 놓습니다. 흰 면·그림자·칩을 걷어내면
/// 남는 세로를 전부 표지가 쓰고, 제목은 책등 라벨처럼 표지 밑에 작게 붙습니다
/// ([_ShelfBook]). 아이는 어차피 제목이 아니라 그림으로 고릅니다 —
/// 시간·주제는 이야기 목록과 상세가 다시 보여 줍니다.
///
/// 표지 자체는 목록·상세와 **같은 세로 2:3, 같은 [StoryThumbnail]** 이라
/// 화면을 옮겨도 같은 그림이 같은 모양으로 보입니다.
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

  /// 태블릿에서 세우는 표지의 폭 범위.
  ///
  /// 아래쪽(96)은 18sp 라벨이 다섯 글자("의좋은 형제")를 담는 최소 폭이고,
  /// 위쪽(168)은 "책장에 꽂힌 책"으로 읽히는 한계입니다 — 더 키우면 책이
  /// 아니라 카드가 되고, 그러면 제목·칩이 없는 게 어색해집니다.
  static const double coverMinWide = 96;
  static const double coverMaxWide = 168;

  final List<RecommendedStory> stories;
  final ScreenMetrics metrics;
  final void Function(RecommendedStory story) onStoryTap;
  final VoidCallback onMoreTap;

  /// [coverWidthOf] 로 잰 표지 폭. 홈 본문이 세로 예산을 알고 있어서
  /// 여기서 직접 재지 않고 받습니다. (스켈레톤도 같은 값을 씁니다)
  final double coverWidth;

  /// 책 한 권의 폭.
  ///
  /// 세로 표지는 폭이 곧 높이(×1.5)라, **폭을 어디서 가져오느냐가 곧 세로
  /// 예산**입니다. 그래서 모자란 쪽 기준이 화면마다 다릅니다.
  ///
  /// - 폰: 세로는 스크롤로 벌 수 있고 폭이 모자랍니다. 이야기 목록과 같은
  ///   2열로 나눠 갖습니다. 여기서 폭을 고정하면 화면 오른쪽 절반이 빕니다.
  /// - 태블릿: 폭은 남고 **세로가 모자랍니다.** 그래서 본문에 실제로 주어진
  ///   높이([bodyHeight])에서 히어로·섹션 제목·여백·라벨을 뺀 나머지를 표지가
  ///   씁니다. 상수로 못박으면 1280×800 에 맞춘 값이 1024×768 에서 라벨을
  ///   하단 내비 밑으로 밀어냅니다 — 기기마다 남는 세로가 다릅니다.
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
        HomeHeroCard.estimateHeight(context, metrics) +
        AppSpacing.lg +
        AppSizes.tapChildSecondary +
        AppSpacing.md;
    // 책 한 권 안에서 표지가 아닌 부분 — 표지~라벨 사이와 라벨 한 줄.
    // 끝에 sm 을 한 번 더 빼는 건 숨 쉴 틈입니다. 딱 맞게 계산하면 라벨 밑선이
    // 하단 내비에 붙어서, 잘리지 않았는데도 잘린 것처럼 보입니다.
    final double label =
        AppSpacing.sm +
        metrics.lineHeight(context, AppTypography.kidLabel) +
        AppSpacing.sm;
    // 2:3 이라 남은 세로를 1.5로 나누면 폭입니다.
    return ((bodyHeight - above - label) / 1.5).clamp(
      coverMinWide,
      coverMaxWide,
    );
  }

  /// 책 한 권이 차지하는 세로 = 표지 + 라벨.
  /// 로딩 스켈레톤이 같은 자리를 잡는 데 씁니다.
  static double heightOf(
    BuildContext context,
    ScreenMetrics metrics,
    double coverWidth,
  ) =>
      coverWidth * 3 / 2 +
      AppSpacing.sm +
      metrics.lineHeight(context, AppTypography.kidLabel);

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
                _ShelfBook(
                  story: story,
                  metrics: metrics,
                  coverWidth: coverWidth,
                  onTap: () => onStoryTap(story),
                ),
            ],
          ),
      ],
    );
  }
}

/// 책장에 꽂힌 책 한 권 — 세로 2:3 표지 + 그 밑의 라벨.
///
/// 흰 카드 면을 두르지 않습니다. 표지 자체가 이미 사각형이라 카드에 넣으면
/// **테두리가 두 겹**이 되고, 그 여백만큼 표지가 작아집니다. 낮 배경 위에
/// 표지를 바로 세우고 [AppShadows.soft] 로 띄우면 "책장에 꽂힌 책"이 됩니다.
///
/// 라벨은 32sp 제목이 아니라 18sp([AppTypography.kidLabel])입니다. 120dp 폭에
/// 32sp 를 넣으면 세 글자 만에 잘려서 "의좋"이 되는데, 그건 제목이 아니라
/// 잡음입니다. 아이 화면에서 글자는 보조이고 본체는 그림입니다
/// (`docs/DESIGN_SYSTEM.md` 2장) — 여기서는 표지가 제목의 일을 합니다.
class _ShelfBook extends StatelessWidget {
  const _ShelfBook({
    required this.story,
    required this.metrics,
    required this.coverWidth,
    required this.onTap,
  });

  final RecommendedStory story;
  final ScreenMetrics metrics;
  final double coverWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      borderRadius: AppRadius.lg,
      // 화면에 안 보이는 시간·주제도 여기서는 읽어 줍니다.
      semanticLabel:
          '${story.title} · ${AppStrings.minutes(story.estimatedMinutes)} · '
          '${story.topicTag}',
      child: SizedBox(
        width: coverWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.soft,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: StoryThumbnail(
                  image: story.image,
                  fallbackIcon: AppIcons.stories,
                  aspectRatio: StoryThumbnail.portrait,
                  topicTag: story.topicTag,
                  title: story.title,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              story.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: metrics.text(AppTypography.kidLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// 섹션 제목. 레퍼런스처럼 **마지막 단어(키워드)만 브랜드 색**으로 강조합니다.
///
/// 파스텔은 글자로 못 쓰므로 강조는 대비가 나오는 `brandBlueDeep` 로.
/// (노랑은 별가루 전용이라 강조에 쓰지 않습니다 — `docs/DESIGN_SYSTEM.md` 3장)
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.text, required this.metrics});

  final String text;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = metrics.text(AppTypography.kidTitle);
    final int split = text.lastIndexOf(' ');
    final String lead = split < 0 ? '' : text.substring(0, split + 1);
    final String keyword = split < 0 ? text : text.substring(split + 1);
    return RichText(
      text: TextSpan(
        style: base,
        children: <TextSpan>[
          if (lead.isNotEmpty) TextSpan(text: lead),
          TextSpan(
            text: keyword,
            style: base.copyWith(color: AppColors.brandBlueDeep),
          ),
        ],
      ),
    );
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
