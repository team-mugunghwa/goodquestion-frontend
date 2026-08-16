import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/kid_button.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/story_thumbnail.dart';

/// 홈 히어로 — 표지를 **카드 전폭 배경**으로 깔고 그 위에 글자를 얹는 카드.
///
/// 이어하기([ContinueCard]) · 오늘의 이야기([TodayStoryCard]) · 마지막 안전망
/// ([StartStoryCard]) 이 이 한 껍데기를 함께 씁니다. 세 상태의 문법이 같아야
/// 이어하던 이야기가 있든 없든 홈의 첫인상과 손이 가는 자리가 안 바뀝니다.
///
/// ## 높이는 글자가 정하고, 사진이 그 높이를 채웁니다
///
/// 사진에 높이를 맡기면(=비율을 고정하면) 태블릿 가로에서 이미지 한 장이
/// 첫 화면을 다 먹고, 반대로 글자 기둥 옆에 사진을 세우면 사진 오른쪽에 빈
/// 면이 남습니다. 그래서 이 카드는 **글자·버튼이 높이를 정하고 사진이 그
/// 높이를 채웁니다** — 구조적으로 빈 여백이 0 입니다.
///
/// ## 여기가 표지를 자르는 **유일한 자리**입니다
///
/// 앱의 원칙은 "표지는 자르지 않는다"이고, 목록·책장·상세는 전부 세로 2:3 을
/// 그대로 세웁니다. 히어로만 예외입니다. 이 자리는 가로로 긴 배너(태블릿
/// 1280 에서 약 7.7:1)라서 세로 2:3 그림을 넣을 방법이 없고, 표지를 세워
/// 봤더니 태블릿에서 화면이 비어 보였습니다.
///
/// **대가는 큽니다.** 태블릿 1280 에서 원본(1024×1536)의 세로 **약 9%**,
/// 1024 에서 약 11%, 폰에서 약 49% 만 남습니다. 이 예외를 없애는 방법은
/// 하나뿐입니다 — 이 비율로 그려진 가로 전용 그림(`story_<id>_wide.png`)을
/// 따로 뽑는 것. (`docs/COVER_ART_GUIDE.md` 7장)
class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({
    super.key,
    required this.metrics,
    required this.image,
    required this.storyTitle,
    required this.eyebrowIcon,
    required this.eyebrowLabel,
    required this.actionIcon,
    required this.actionLabel,
    required this.onTap,
    this.topicTag,
    this.detail,
  });

  /// 사진 위에 얹는 글자·아이콘의 색. 히어로 안에서는 전부 이 색입니다.
  static const Color onCover = AppColors.surface;

  /// 납작한 띠에서 표지의 **어느 높이를 남길지.**
  ///
  /// 표지 원본은 세로 2:3(1024×1536)이라, 가운데([Alignment.center])를 잡으면
  /// 인물의 허리만 남고 얼굴이 통째로 잘려 나갑니다. `-0.2` 는 원본 세로의
  /// 40% 지점을 띠의 중심으로 삼는다는 뜻이고, 가지고 있는 표지 일곱 장에서
  /// 인물의 눈~입이 이 근처에 옵니다. 표지가 늘어나면 이 값이 아니라
  /// **가로 전용 그림**으로 푸는 게 맞습니다.
  static const Alignment coverAlignment = Alignment(0, -0.2);

  // ── 스크림 ────────────────────────────────────────────────
  //
  // 흰 글자가 **가장 밝은 표지 위에서도** 읽혀야 합니다. 지금 가진 표지 중
  // 제일 밝은 `story_31.png`(토끼와 거북이)는 글자가 놓이는 왼쪽 영역의
  // 상위 2% 밝기가 상대휘도 0.91 로 사실상 흰색입니다. 그래서 계산은
  // **흰 표지**를 기준으로 합니다.
  //
  // 검은 스크림 알파 a 를 얹으면 sRGB 값이 (1-a) 배가 되고, 흰 글자와의
  // 명도비는 대략 이렇게 됩니다.
  //
  // | a | 흰 표지 위 명도비 |
  // |---|---|
  // | 0.50 | 4.0:1 |
  // | 0.60 | 5.7:1 |
  // | 0.65 | 7.0:1 |
  //
  // 목표는 **5.8~7:1** — WCAG AA(4.5:1)를 여유 있게 넘기되, 사진을 검은
  // 판때기로 만들지 않는 선입니다.

  /// 카드 전체에 한 겹. 아래로 갈수록 진해집니다 — 버튼과 진행 라벨이
  /// 아래쪽에 있어서 그렇습니다.
  static const double _scrimTop = 0.30;
  static const double _scrimBottom = 0.45;

  /// 가로에서 **글자가 놓이는 왼쪽에만** 한 겹 더.
  ///
  /// 세로 스크림만으로 5.8:1 을 맞추려면 카드 전체를 0.6 이상으로 덮어야
  /// 하는데, 그러면 오른쪽 사진까지 같이 죽습니다. 왼쪽만 겹쳐서 합성
  /// 0.61(위)~0.69(아래) = **6.1:1~8.3:1** 을 만들고, 오른쪽은 0.30~0.45
  /// 로 두어 사진이 살아 있게 합니다.
  static const double _scrimLeft = 0.44;

  /// 왼쪽 겹의 알파가 유지되는 구간. 여기까지가 글자 자리입니다.
  static const double _scrimLeftHold = 0.55;

  /// 폰은 글자가 카드 폭을 다 쓰므로 왼쪽 겹을 나눌 수 없습니다.
  /// 세로 한 겹을 진하게 깔아 6.2:1(위)~15.6:1(아래)로 맞춥니다.
  static const double _scrimCompactTop = 0.62;
  static const double _scrimCompactBottom = 0.86;

  final ScreenMetrics metrics;

  /// 표지 이미지. `null` 이면 [StoryThumbnail] 이 제목별 로컬 표지 →
  /// 주제별 코드 표지 순으로 대신 채웁니다.
  final String? image;

  final String storyTitle;

  /// 코드 표지의 색·모티프를 정합니다. 진행 중 세션에는 주제 정보가 없어
  /// `null` 이 들어오고, 그때는 브랜드 기본 표지가 뜹니다.
  final String? topicTag;

  /// 제목 위 한 줄. "지금 여기가 어디인지"를 알려 주는 표식입니다.
  final IconData eyebrowIcon;
  final String eyebrowLabel;

  /// 제목 아래 한 줄. 진행 점([ContinueCard]) 또는 시간·주제 한 줄
  /// ([TodayStoryCard]).
  ///
  /// 보여 줄 이야기가 없는 폴백([StartStoryCard])에서는 `null` 입니다 —
  /// 채울 게 없는데 줄을 만들면 그게 다시 빈 여백입니다.
  final Widget? detail;

  final IconData actionIcon;
  final String actionLabel;

  /// 카드 전체와 버튼이 **같은 곳**으로 갑니다 — 아이가 어디를 눌러도 됩니다.
  final VoidCallback onTap;

  /// 로딩 스켈레톤이 쓰는 예상 높이. 실제 카드와 **같은 식**이어야
  /// 로딩 → 성공에서 화면이 덜컹거리지 않습니다.
  ///
  /// 기기의 글자 확대 설정까지 반영하려고 [ScreenMetrics.lineHeight] 를 씁니다.
  static double estimateHeight(BuildContext context, ScreenMetrics metrics) {
    final double label = metrics.lineHeight(context, AppTypography.kidLabel);
    // 표식 줄은 아이콘(24)이 글자보다 큽니다.
    final double eyebrow = math.max(AppSizes.iconInline, label);
    final double title = metrics.lineHeight(context, AppTypography.kidTitle);
    // 아래 한 줄은 이어하기의 진행 점을 기준으로 잡습니다 — 히어로가 존재하는
    // 이유가 그 상태이고, 세 상태 중 가장 높습니다. 가로에서는 점과 라벨이
    // 한 줄에 서고, 폰에서는 점 줄 밑으로 라벨이 내려옵니다.
    final double meta = metrics.isWide
        ? math.max(AppSpacing.md, label)
        : AppSpacing.md + AppSpacing.sm + label;
    final double text = eyebrow + AppSpacing.sm + title + AppSpacing.sm + meta;
    final double body = metrics.isWide
        // 가로: 버튼이 글자 오른쪽에 눕습니다 — 큰 쪽이 높이를 정합니다.
        ? math.max(text, AppSizes.tapChildPrimary)
        // 폰: 글자 아래에 전폭 버튼이 한 줄 더 붙습니다.
        : text + AppSpacing.lg + AppSizes.tapChildPrimary;
    return body + AppSpacing.lg * 2;
  }

  @override
  Widget build(BuildContext context) {
    final Widget? detailLine = detail;
    final Widget textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Eyebrow(icon: eyebrowIcon, label: eyebrowLabel, metrics: metrics),
        const SizedBox(height: AppSpacing.sm),
        Text(
          storyTitle,
          // 제목이 두 줄로 늘어나면 카드가 그만큼 두꺼워지고, 사진이 남기는
          // 세로도 같이 늘어납니다. 한 줄로 못박아 카드 높이를 고정합니다.
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: metrics.text(AppTypography.kidTitle).copyWith(color: onCover),
        ),
        if (detailLine != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          detailLine,
        ],
      ],
    );

    final Widget action = KidPrimaryButton(
      icon: actionIcon,
      label: actionLabel,
      labelStyle: metrics.text(AppTypography.kidButton),
      // 폰에서는 카드 폭을 다 쓰는 한 개의 CTA 로 눕힙니다.
      expand: !metrics.isWide,
      onPressed: onTap,
    );

    final Widget body = metrics.isWide
        // 가로: 글자는 왼쪽에 쌓고 버튼은 오른쪽 끝에 세로 가운데로 눕힙니다.
        // 버튼을 글자 밑에 두면 카드가 두 배로 두꺼워지고, 그만큼 표지가
        // 더 많이 잘립니다.
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(child: textBlock),
              const SizedBox(width: AppSpacing.lg),
              action,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              textBlock,
              const SizedBox(height: AppSpacing.lg),
              action,
            ],
          );

    return PressScale(
      onTap: onTap,
      borderRadius: AppRadius.xl,
      semanticLabel: '$eyebrowLabel $storyTitle $actionLabel',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: <BoxShadow>[
            // 브랜드 파랑을 넓게 깐 앰비언트. 낮 배경에서 카드가 떠오른
            // 온도감을 냅니다. 히어로만 lift 를 겹쳐 한 겹 더 띄웁니다.
            BoxShadow(
              color: AppColors.brandBlue.withValues(alpha: 0.28),
              blurRadius: 48,
              offset: const Offset(0, 22),
            ),
            ...AppShadows.lift,
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          // 위치를 잡지 않은 자식(=글자 블록)이 Stack 의 크기를 정하고,
          // Positioned.fill 인 표지와 스크림이 그 크기를 따라옵니다.
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: StoryThumbnail(
                  image: image,
                  fallbackIcon: AppIcons.stories,
                  // 비율을 강제하지 않습니다 — 글자가 정한 높이를 채웁니다.
                  aspectRatio: null,
                  alignment: coverAlignment,
                  topicTag: topicTag,
                  title: storyTitle,
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.black.withValues(
                          alpha: metrics.isWide ? _scrimTop : _scrimCompactTop,
                        ),
                        Colors.black.withValues(
                          alpha: metrics.isWide
                              ? _scrimBottom
                              : _scrimCompactBottom,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (metrics.isWide)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: <Color>[
                          Colors.black.withValues(alpha: _scrimLeft),
                          Colors.black.withValues(alpha: _scrimLeft),
                          Colors.transparent,
                        ],
                        stops: const <double>[0, _scrimLeftHold, 1],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 제목 위의 한 줄 표식. 아이콘 + 한 마디.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow({
    required this.icon,
    required this.label,
    required this.metrics,
  });

  final IconData icon;
  final String label;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: AppSizes.iconInline, color: HomeHeroCard.onCover),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: metrics
                .text(AppTypography.kidLabel)
                .copyWith(color: HomeHeroCard.onCover),
          ),
        ),
      ],
    );
  }
}
