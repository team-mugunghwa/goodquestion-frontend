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

/// 홈 히어로 — **표지 패널 + 흰 글자 면**으로 나뉜 카드.
///
/// 이어하기([ContinueCard]) · 오늘의 이야기([TodayStoryCard]) · 마지막 안전망
/// ([StartStoryCard]) 이 이 한 껍데기를 함께 씁니다. 세 상태의 문법이 같아야
/// 이어하던 이야기가 있든 없든 홈의 첫인상과 손이 가는 자리가 안 바뀝니다.
///
/// ## 자르지 않습니다
///
/// 예전 이 카드는 세로 2:3 표지를 카드 전폭 배경으로 깔고 검은 스크림 위에 흰
/// 글자를 얹었습니다. 태블릿에서 원본 세로의 9% 만 남는 자리였고, 앱의 원칙
/// ("표지는 자르지 않는다")의 유일한 예외였습니다.
///
/// 지금은 **가로 전용 표지(2.5:1)** 가 들어와서 그 예외가 사라지는 중입니다.
/// 이미지 패널은 항상 그림 원본과 같은 비율이라 [BoxFit.cover] 가 잘라낼 게
/// 없고, 글자는 옆(또는 아래)의 **흰 면**으로 나와서 스크림도 필요 없습니다.
/// (`docs/COVER_ART_GUIDE.md` 7장)
///
/// ## 네 가지 모양
///
/// | 조건 | 모양 | 패널 |
/// |---|---|---|
/// | 가로(≥600) · 가로 표지 있음 · 글자 칸 [_textMinWidth] 확보 | 패널 왼쪽 + 글자 오른쪽 | **2.5:1** |
/// | 가로(≥600) · 그 밖 | 패널 왼쪽 + 글자 오른쪽 | 세로 **2:3** |
/// | 폰 · 가로 표지 있음 | 띠 위 + 글자 아래 | **2.5:1** 전폭 |
/// | 폰 · 가로 표지 없음 | 표지 왼쪽 + 글자 오른쪽, CTA 는 아래 전폭 | 세로 **2:3** |
///
/// 폰에서 2.5:1 패널을 글자 옆에 세울 수는 없습니다 — 카드 높이 250 이면 폭이
/// 625dp 라 폰 화면보다 넓습니다. 반대로 세로 2:3 을 폰 전폭에 띠로 얹으면
/// 380×570 이 되어 히어로 하나가 첫 화면을 다 먹습니다. **기하학이 강제하는
/// 분기**라서 폰만 두 모양입니다.
///
/// ## 표식이 놓이는 자리도 패널이 정합니다
///
/// 가로 패널(2.5:1) 위에는 **흰 알약**([_HeroBadge])을 얹습니다. 세로 2:3
/// 패널은 폭이 177dp 남짓이라 알약이 이미지 밖으로 삐져나가므로, 그때는
/// 표식을 글자 기둥 안 제목 위 한 줄([_Eyebrow])로 들입니다.
/// 카드 높이는 **둘 중 높은 쪽(=한 줄이 들어가는 세로 폴백)** 으로 맞춰서,
/// 같은 자리의 카드가 이야기마다 들쭉날쭉하지 않게 합니다.
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

  /// 이미지 패널이 카드 폭에서 노리는 몫.
  ///
  /// 패널 높이 = 폭 ÷ 2.5 이므로 **이 값이 곧 카드 높이**입니다. 0.5 는
  /// 1280 화면에서 608×243 — 목업과 같은 균형입니다. 글자가 그보다 더 높이를
  /// 요구하면 글자가 이깁니다([_bodyHeight]).
  static const double _panelFraction = 0.5;

  /// 카드 높이 상한. 큰 화면에서 폭의 20% 를 그대로 따라가면 히어로 하나가
  /// 첫 화면을 다 먹습니다.
  static const double _maxHeight = 280;

  /// 가로 표지 패널을 세우기 위해 **글자 칸에 남아야 하는 최소 폭.**
  ///
  /// 여기가 좁아지면 제목이 잘리는 게 아니라 진행 점 줄이 두 줄로 접히면서
  /// 카드 높이가 어긋납니다. 계산 근거는 이어하기의 가장 긴 줄입니다 —
  /// 점 10개(10×16 + 9×8 = 232) + [AppSpacing.md] + "10번째 장면까지 했어요"
  /// (18sp 로 약 216) + 좌우 여백 48 = 512.
  ///
  /// 이 폭이 안 나오면 **글자를 줄이지 않고 세로 2:3 패널로 바꿉니다.**
  /// 1280·1194(iPad 11") 는 가로 패널, 1024·840 은 세로 패널입니다.
  static const double _textMinWidth = 512;

  /// 진행 점 하나의 지름. [ContinueCard] 와 높이 계산이 함께 씁니다.
  static const double dotSize = AppSpacing.md;

  /// 진행 점 사이. 폰의 좁은 글자 칸(약 206dp)에서도 점 열 개가 **한 줄에**
  /// 서야 해서 좁힙니다. 10×16 + 9×4 = 196.
  static double dotSpacing(ScreenMetrics metrics) =>
      metrics.isWide ? AppSpacing.sm : AppSpacing.xs;

  /// 글자 높이 계산에 얹는 반올림 여유.
  ///
  /// [ScreenMetrics.lineHeight] 는 `fontSize × height` 로 **이상적인** 한 줄
  /// 높이를 냅니다. 실제로 그려진 줄 상자는 폰트의 ascent/descent 를 올림해서
  /// 0.1~1dp 쯤 더 커질 수 있고, 카드가 딱 맞게 계산돼 있으면 그 0.2dp 가
  /// `RenderFlex overflowed by 0.200 pixels` 로 터집니다. 글자 세 줄이니
  /// 4dp 면 충분하고, 눈에는 안 보입니다.
  static const double _textRounding = AppSpacing.xs;

  final ScreenMetrics metrics;

  /// 세로 표지. `null` 이면 [StoryThumbnail] 이 제목별 로컬 표지 →
  /// 주제별 코드 표지 순으로 대신 채웁니다.
  ///
  /// 가로 표지는 여기로 안 들어옵니다 — 제목으로
  /// [StoryThumbnail.localWideCoverAssetFor] 에서 찾습니다.
  final String? image;

  final String storyTitle;

  /// 코드 표지의 색·모티프를 정합니다. 진행 중 세션에는 주제 정보가 없어
  /// `null` 이 들어오고, 그때는 브랜드 기본 표지가 뜹니다.
  final String? topicTag;

  /// 이미지 위에 얹히는 흰 알약의 내용. "지금 여기가 어디인지"를 알려 줍니다.
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

  /// 글자 기둥이 요구하는 높이(위아래 여백 포함).
  ///
  /// [metaWraps] 는 진행 점 줄이 두 줄로 접히는지 — 점과 라벨이 한 줄에 못 설
  /// 만큼 글자 칸이 좁으면 그만큼 카드가 두꺼워집니다.
  ///
  /// [eyebrow] 는 표식이 **글자 기둥 안**에 한 줄로 들어가는지. 세로 2:3
  /// 폴백에서만 그렇습니다 — 폭 177dp 짜리 세로 표지 위에는 흰 알약이 안
  /// 들어갑니다. 가로 패널은 알약을 이미지 위에 얹으므로 이 줄이 없습니다.
  static double _bodyHeight(
    BuildContext context,
    ScreenMetrics metrics, {
    required bool metaWraps,
    bool eyebrow = false,
  }) {
    final double label = metrics.lineHeight(context, AppTypography.kidLabel);
    final double title = metrics.lineHeight(context, AppTypography.kidTitle);
    final double meta = metaWraps
        ? dotSize + AppSpacing.sm + label
        : math.max(dotSize, label);
    final double top = eyebrow
        ? math.max(AppSizes.iconInline, label) + AppSpacing.sm
        : 0;
    return top +
        title +
        AppSpacing.sm +
        meta +
        AppSpacing.lg +
        AppSizes.tapChildPrimary +
        AppSpacing.lg * 2 +
        _textRounding;
  }

  /// 가로 화면의 카드 높이. 글자가 요구하는 높이와 패널 몫 중 큰 쪽입니다.
  ///
  /// 두 모양(가로 패널 · 세로 폴백)이 **같은 높이**를 씁니다. 이야기마다
  /// 히어로가 들쭉날쭉하면 아래 책장이 같이 움직이고, 로딩 스켈레톤도 어느
  /// 쪽에 맞춰야 할지 정할 수 없습니다. 그래서 표식 한 줄이 들어가는 쪽
  /// (세로 폴백)을 기준으로 잡고, 가로 패널은 그만큼 숨 쉴 틈으로 씁니다.
  static double _wideHeight(
    BuildContext context,
    ScreenMetrics metrics,
    double cardWidth, {
    required bool metaWraps,
  }) => math.max(
    _bodyHeight(context, metrics, metaWraps: metaWraps, eyebrow: true),
    math.min(cardWidth * _panelFraction / StoryThumbnail.wideCover, _maxHeight),
  );

  /// 가로 화면의 카드 높이와 "진행 점 줄이 접히는가".
  ///
  /// 접힘 여부는 글자 칸 폭에 달렸고 글자 칸 폭은 다시 카드 높이에 달려
  /// 있어서 두 번 계산합니다. 기준은 **세로 2:3 패널**입니다 — 가로 패널을
  /// 세우는 폭이면 글자 칸이 [_textMinWidth] 이상이라 어차피 안 접힙니다.
  static ({double height, bool metaWraps}) _wideLayout(
    BuildContext context,
    ScreenMetrics metrics,
    double cardWidth,
  ) {
    final double first = _wideHeight(
      context,
      metrics,
      cardWidth,
      metaWraps: false,
    );
    final bool wraps =
        cardWidth - first * StoryThumbnail.portrait < _textMinWidth;
    if (!wraps) return (height: first, metaWraps: false);
    return (
      height: _wideHeight(context, metrics, cardWidth, metaWraps: true),
      metaWraps: true,
    );
  }

  /// 폰에서 세로 표지를 옆에 세울 때의 **위쪽 줄** 높이.
  /// 표지 폭이 여기서 나옵니다(÷1.5). CTA 는 이 줄 아래에 전폭으로 붙습니다.
  static double _compactRowHeight(BuildContext context, ScreenMetrics metrics) {
    final double label = metrics.lineHeight(context, AppTypography.kidLabel);
    final double title = metrics.lineHeight(context, AppTypography.kidTitle);
    return AppSpacing.lg +
        math.max(AppSizes.iconInline, label) +
        AppSpacing.sm +
        // 폰의 좁은 글자 칸에서는 제목이 두 줄까지 갑니다. 줄이지 않고
        // 자리를 내주는 게 이 저장소의 규약입니다.
        title * 2 +
        AppSpacing.sm +
        (dotSize + AppSpacing.sm + label) +
        AppSpacing.lg +
        _textRounding;
  }

  /// 로딩 스켈레톤과 아래 책장이 쓰는 카드 높이.
  ///
  /// 실제 카드와 **같은 식**이어야 로딩 → 성공에서 화면이 덜컹거리지 않습니다.
  /// 기기의 글자 확대 설정까지 반영하려고 [ScreenMetrics.lineHeight] 를 씁니다.
  ///
  /// 폰에서는 **가로 표지가 있는 모양**(띠 + 글자)을 기준으로 잽니다. 가로
  /// 표지가 없는 편은 이보다 낮지만(약 60dp), 스켈레톤은 어떤 이야기가 올지
  /// 모르고 가로 표지는 계속 늘어납니다.
  static double estimateHeight(
    BuildContext context,
    ScreenMetrics metrics,
    double cardWidth,
  ) {
    if (!metrics.isWide) {
      return cardWidth / StoryThumbnail.wideCover +
          _bodyHeight(context, metrics, metaWraps: true);
    }
    return _wideLayout(context, metrics, cardWidth).height;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          _card(context, constraints.maxWidth),
    );
  }

  Widget _card(BuildContext context, double cardWidth) {
    // 이 제목으로 그려 둔 가로 전용 표지가 있는지. 없으면 `null` 이고,
    // 그때는 세로 2:3 표지를 세웁니다. (지금 7편 중 2편)
    final String? wideCover = StoryThumbnail.localWideCoverAssetFor(storyTitle);

    return PressScale(
      onTap: onTap,
      borderRadius: AppRadius.xl,
      semanticLabel: '$eyebrowLabel $storyTitle $actionLabel',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
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
          child: metrics.isWide
              ? _sideBySide(context, cardWidth, wideCover)
              : wideCover == null
              ? _compactStanding(context)
              : _compactBanner(context, cardWidth, wideCover),
        ),
      ),
    );
  }

  /// 가로 화면 — 패널 왼쪽, 글자 오른쪽. 목업의 모양입니다.
  Widget _sideBySide(
    BuildContext context,
    double cardWidth,
    String? wideCover,
  ) {
    final ({double height, bool metaWraps}) layout = _wideLayout(
      context,
      metrics,
      cardWidth,
    );
    final double height = layout.height;
    // 가로 표지는 글자 칸이 충분히 남을 때만. 안 되면 세로 표지를 세웁니다 —
    // 어느 쪽이든 패널 비율 = 그림 비율이라 잘리는 데가 없습니다.
    final bool useWide =
        wideCover != null &&
        cardWidth - height * StoryThumbnail.wideCover >= _textMinWidth;
    final double panelWidth = useWide
        ? height * StoryThumbnail.wideCover
        : height * StoryThumbnail.portrait;

    return SizedBox(
      height: height,
      child: Row(
        children: <Widget>[
          _panel(
            width: panelWidth,
            height: height,
            asset: useWide ? wideCover : image,
            // 세로 표지 폭은 177dp 남짓이라 흰 알약이 이미지 밖으로 삐져
            // 나갑니다. 그때는 표식을 글자 기둥 안으로 들입니다.
            badge: useWide,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _textColumn(expand: false, eyebrow: !useWide),
            ),
          ),
        ],
      ),
    );
  }

  /// 폰 · 가로 표지 있음 — 띠를 카드 위에 전폭으로 얹고 글자를 아래에 쌓습니다.
  ///
  /// 글자가 카드 폭을 다 쓰기 때문에 제목·진행 점·CTA 가 전부 한 줄씩 제자리에
  /// 섭니다. 표지를 옆에 세우면 글자 칸이 216dp 로 줄어 CTA 라벨부터 깨집니다.
  Widget _compactBanner(
    BuildContext context,
    double cardWidth,
    String wideCover,
  ) {
    final double bandHeight = cardWidth / StoryThumbnail.wideCover;
    return SizedBox(
      height: bandHeight + _bodyHeight(context, metrics, metaWraps: true),
      child: Column(
        children: <Widget>[
          _panel(width: cardWidth, height: bandHeight, asset: wideCover),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _textColumn(expand: true),
            ),
          ),
        ],
      ),
    );
  }

  /// 폰 · 가로 표지 없음 — 세로 2:3 표지를 왼쪽에 세우고, CTA 만 아래 전폭으로.
  ///
  /// CTA 를 글자 옆에 두면 216dp 안에 "이어서 말하기"가 안 들어가서 라벨이
  /// 잘립니다. 그래서 이 모양만 표식(알약 대신 한 줄)과 CTA 자리가 다릅니다 —
  /// 표지 폭이 134dp 라 흰 알약을 얹을 자리가 없습니다.
  Widget _compactStanding(BuildContext context) {
    final double rowHeight = _compactRowHeight(context, metrics);
    return SizedBox(
      height: rowHeight + AppSizes.tapChildPrimary + AppSpacing.lg,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: rowHeight,
            child: Row(
              children: <Widget>[
                _panel(
                  width: rowHeight * StoryThumbnail.portrait,
                  height: rowHeight,
                  asset: image,
                  badge: false,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _Eyebrow(
                          icon: eyebrowIcon,
                          label: eyebrowLabel,
                          metrics: metrics,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          storyTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: metrics.text(AppTypography.kidTitle),
                        ),
                        if (detail != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          detail!,
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: _action(expand: true),
          ),
        ],
      ),
    );
  }

  /// 표지 패널. **비율을 이미 맞춰서 주므로** [StoryThumbnail] 은 부모 크기를
  /// 그대로 채우기만 합니다 — 잘려 나가는 부분이 없습니다.
  Widget _panel({
    required double width,
    required double height,
    required String? asset,
    bool badge = true,
  }) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: StoryThumbnail(
              image: asset,
              fallbackIcon: AppIcons.stories,
              aspectRatio: null,
              topicTag: topicTag,
              title: storyTitle,
            ),
          ),
          if (badge)
            Positioned(
              left: AppSpacing.md,
              top: AppSpacing.md,
              child: _HeroBadge(
                icon: eyebrowIcon,
                label: eyebrowLabel,
                metrics: metrics,
              ),
            ),
        ],
      ),
    );
  }

  /// 흰 면 위의 글자 기둥. 세로 가운데 정렬입니다(목업).
  Widget _textColumn({required bool expand, bool eyebrow = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: expand
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: <Widget>[
        if (eyebrow) ...<Widget>[
          _Eyebrow(icon: eyebrowIcon, label: eyebrowLabel, metrics: metrics),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          storyTitle,
          // 한 줄로 못박아 카드 높이를 고정합니다. 가로에서는 글자 칸이
          // 최소 512dp 라 가장 긴 제목도 한 줄에 섭니다.
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: metrics.text(AppTypography.kidTitle),
        ),
        if (detail != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          detail!,
        ],
        const SizedBox(height: AppSpacing.lg),
        // 폰은 카드 폭을 다 쓰는 한 개의 CTA, 가로는 글자 왼쪽 끝에 맞춘
        // 알약입니다. 가로에서 전폭으로 늘리면 버튼이 카드의 절반이 됩니다.
        expand
            ? _action(expand: true)
            : Align(
                alignment: Alignment.centerLeft,
                child: _action(expand: false),
              ),
      ],
    );
  }

  Widget _action({required bool expand}) => KidPrimaryButton(
    icon: actionIcon,
    label: actionLabel,
    labelStyle: metrics.text(AppTypography.kidButton),
    expand: expand,
    onPressed: onTap,
  );
}

/// 이미지 왼쪽 위에 얹히는 흰 알약. "이어보던 이야기" · "오늘은 이거 어때?"
///
/// 글자 면이 아니라 **이미지 위**에 있습니다. 제목 위 한 줄로 두면 흰 면의
/// 글자가 세 덩이(표식·제목·진행)로 늘어나 무엇이 제목인지 흐려집니다.
/// 표지 밝기가 제각각이라 알약은 흰 면 + 그림자로 자기 대비를 스스로 만듭니다.
class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.icon,
    required this.label,
    required this.metrics,
  });

  final IconData icon;
  final String label;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: AppSizes.iconInline, color: AppColors.brandBlueDeep),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: metrics
                .text(AppTypography.kidLabel)
                .copyWith(color: AppColors.ink900),
          ),
        ],
      ),
    );
  }
}

/// 제목 위의 한 줄 표식. **폰에서 세로 표지를 세울 때만** 씁니다 —
/// 그때는 표지 폭이 134dp 라 흰 알약([_HeroBadge])을 얹을 자리가 없습니다.
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
        Icon(icon, size: AppSizes.iconInline, color: AppColors.brandBlueDeep),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: metrics
                .text(AppTypography.kidLabel)
                .copyWith(color: AppColors.brandBlueDeep),
          ),
        ),
      ],
    );
  }
}
