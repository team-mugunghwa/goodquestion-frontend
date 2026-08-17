import 'package:flutter/material.dart';

import '../constants/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'press_scale.dart';
import 'screen_metrics.dart';
import 'story_thumbnail.dart';

/// 정보를 보여 주기만 하는 칩. 예상 시간, 주제 태그, 난이도.
///
/// **누를 수 없습니다.** 누르는 칩은 [KidFilterChips] 를 쓰세요 — 아이가
/// 눌러 봤는데 아무 일도 안 일어나는 게 가장 나쁩니다.
///
/// 파스텔은 면으로만 쓰고 글자는 잉크색입니다. (`docs/DESIGN_SYSTEM.md` 3장)
class KidInfoChip extends StatelessWidget {
  const KidInfoChip({
    super.key,
    required this.label,
    required this.metrics,
    this.icon,
    this.compact = false,
  });

  final String label;
  final ScreenMetrics metrics;
  final IconData? icon;

  /// 카드 안처럼 자리가 좁을 때. 글자(15)와 아이콘(18)을 한 단계 줄입니다.
  /// 읽는 정보라 작아도 되고, 그래야 아이콘을 달고도 이름이 안 잘립니다.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final IconData? glyph = icon;
    return Container(
      // 좌우 여백이 md(16)면 좁은 카드 안에서 아이콘·글자를 밀어내 넘칩니다.
      // 정보 칩은 읽는 것이지 누르는 것이 아니라 여백이 작아도 됩니다.
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.brandBlueSurface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (glyph != null) ...<Widget>[
            Icon(
              glyph,
              size: compact ? AppSizes.iconCaption : AppSizes.iconInline,
              color: AppColors.ink700,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          // 좁은 카드 안에서도 칩이 넘치지 않게 라벨을 줄입니다.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: metrics.text(
                compact ? AppTypography.kidCaption : AppTypography.kidLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 필터 칩 하나가 보여 줄 내용.
///
/// [icon] 과 [image] 중 하나만 주세요. 이야기별 필터처럼 **그림이 곧 라벨**인
/// 자리에는 [image] 를, 주제처럼 그림이 없는 자리에는 [icon] 을 씁니다.
@immutable
class KidFilterChipData {
  const KidFilterChipData({
    required this.id,
    required this.label,
    this.icon,
    this.image,
  });

  final String id;
  final String label;
  final IconData? icon;
  final String? image;
}

/// 가로 스크롤 필터 칩 바. **단일 선택**입니다.
///
/// 다중 선택을 넣지 마세요 — 저학년에게 "두 개를 동시에 골랐다"는 상태는
/// 인지 부담이고, 해제하는 법을 몰라 갇힙니다.
///
/// 선택된 칩은 색만으로 구분하지 않습니다. 진한 면 + 흰 글자로 **명도 자체가
/// 뒤집혀서**, 색을 구분하기 어려운 아이도 어느 게 켜졌는지 압니다.
class KidFilterChips extends StatelessWidget {
  const KidFilterChips({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
    required this.metrics,
  });

  final List<KidFilterChipData> items;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // 세로 여백은 그림자가 잘리지 않게 하는 최소한입니다.
      padding: EdgeInsets.symmetric(
        horizontal: metrics.screenPadding,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            _Chip(
              data: items[i],
              selected: items[i].id == selectedId,
              metrics: metrics,
              onTap: () => onSelected(items[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.data,
    required this.selected,
    required this.metrics,
    required this.onTap,
  });

  final KidFilterChipData data;
  final bool selected;
  final ScreenMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected ? AppColors.surface : AppColors.ink700;
    final String? image = data.image;
    final IconData? icon = data.icon;

    return Semantics(
      selected: selected,
      child: PressScale(
        onTap: onTap,
        borderRadius: AppRadius.pill,
        semanticLabel: data.label,
        child: Container(
          // 칩도 아이가 누르는 것이라 64 를 지킵니다.
          height: AppSizes.tapChildSecondary,
          padding: EdgeInsets.symmetric(
            horizontal: image == null ? AppSpacing.lg : AppSpacing.sm,
          ),
          // 테두리 대신 옅은 그림자로 띄웁니다. 1px 테두리 알약은 화면을
          // 선으로 채워 답답해 보입니다.
          decoration: BoxDecoration(
            color: selected ? AppColors.brandBlueDeep : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (image != null) ...<Widget>[
                ClipOval(
                  child: SizedBox.square(
                    dimension: AppSizes.tapChildSecondary - AppSpacing.md,
                    child: StoryThumbnail(
                      image: image,
                      fallbackIcon: AppIcons.stories,
                      aspectRatio: StoryThumbnail.square,
                      iconSize: AppSizes.iconInline,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ] else if (icon != null) ...<Widget>[
                Icon(icon, size: AppSizes.iconInline, color: foreground),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: metrics
                    .text(AppTypography.kidLabel)
                    .copyWith(color: foreground),
              ),
              if (image != null) const SizedBox(width: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
