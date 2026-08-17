import 'dart:math' as math;

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

/// 이야기 카드. 이야기 목록(`/stories`)의 그리드와 홈의 추천 줄이 **같은
/// 카드**를 씁니다.
///
/// 두 자리의 차이는 **크기뿐**입니다. 홈은 히어로 아래 남는 세로에서 카드
/// 폭을 거꾸로 계산해 더 작게 놓습니다 (`RecommendedStoriesSection`).
/// 모양까지 다르면 같은 이야기가 화면마다 다른 물건으로 보입니다.
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

  /// 표지 아래 글자 블록(제목 + 칩 + 안쪽 여백)의 높이.
  ///
  /// 글자 높이는 **재서** 씁니다. `fontSize * height` 로 어림하면 폰트의 실제
  /// 상·하단 여백만큼 몇 px 모자라, 제목이 두 줄인 카드에서만 넘칩니다.
  ///
  /// 이야기 목록은 그리드 셀 높이를, 홈 추천은 남는 세로에서 표지 폭을
  /// 역산할 때 씁니다 — **두 화면이 같은 식을 써야** 같은 카드가 같은 높이로
  /// 섭니다.
  static double bodyHeightOf(
    BuildContext context,
    ScreenMetrics metrics, {
    int titleMaxLines = 2,
  }) {
    final double title = measuredTextHeight(
      context,
      metrics.text(AppTypography.kidButton),
      lines: titleMaxLines,
    );
    // 칩 높이는 글자만이 아니라 **아이콘까지** 봐야 합니다. 카드는 작은
    // 칩(compact)을 쓰므로 kidCaption 글자와 iconCaption 중 큰 쪽입니다.
    final double chip =
        AppSpacing.xs * 2 +
        math.max(
          measuredTextHeight(context, metrics.text(AppTypography.kidCaption)),
          AppSizes.iconCaption,
        );
    return AppSpacing.md * 2 + title + AppSpacing.sm + chip;
  }

  /// 폭이 [width] 일 때 카드 한 장의 높이. 표지(2:3) + 글자 블록입니다.
  static double heightOf(
    BuildContext context,
    ScreenMetrics metrics,
    double width, {
    int titleMaxLines = 2,
  }) =>
      width * 3 / 2 +
      bodyHeightOf(context, metrics, titleMaxLines: titleMaxLines);

  /// 이 스타일로 [lines] 줄을 그렸을 때의 실제 높이.
  static double measuredTextHeight(
    BuildContext context,
    TextStyle style, {
    int lines = 1,
  }) {
    final TextPainter painter = TextPainter(
      // 한글 한 글자를 줄 수만큼. 어떤 글자든 줄 높이는 같습니다.
      text: TextSpan(
        text: List<String>.filled(lines, '가').join('\n'),
        style: style,
      ),
      maxLines: lines,
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final double height = painter.height;
    painter.dispose();
    return height;
  }

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
          //
          // 카드 폭이 200 대라 기본 칩(글자 18 · 아이콘 24)으로는 둘이
          // 한 줄에 안 들어갑니다. compact 로 한 단계 줄이면 시계 아이콘을
          // 달고도 주제 이름이 잘리지 않습니다.
          Row(
            children: <Widget>[
              // 시간은 짧고 길이가 뻔해서 줄이지 않습니다. 자리가 모자라면
              // 주제 이름만 줄어듭니다.
              KidInfoChip(
                icon: AppIcons.duration,
                label: '$estimatedMinutes분',
                metrics: metrics,
                compact: true,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: KidInfoChip(
                  label: topicLabel,
                  metrics: metrics,
                  compact: true,
                ),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 표지는 **비율로만** 높이가 정해집니다. 예전처럼 남는 높이를
            // 먹게 두면 제목이 한 줄인 카드의 표지만 길어져서, 한 줄에
            // 늘어놓은 카드들의 그림 높이가 제각각이 됩니다.
            thumbnail,
            // 대신 글자 블록이 남는 높이를 가져갑니다. 제목이 짧으면 아래가
            // 비고, 길어도 셀 밖으로 넘치지 않습니다.
            Flexible(child: body),
          ],
        ),
      ),
    );
  }
}
