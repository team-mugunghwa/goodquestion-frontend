import 'package:flutter/material.dart';

import '../constants/app_icons.dart';
import '../theme/app_colors.dart';
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
  });

  final String label;
  final ScreenMetrics metrics;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final IconData? glyph = icon;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
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
            Icon(glyph, size: AppSizes.iconInline, color: AppColors.ink700),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label, style: metrics.text(AppTypography.kidLabel)),
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
      padding: EdgeInsets.symmetric(horizontal: metrics.screenPadding),
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
          decoration: BoxDecoration(
            color: selected ? AppColors.brandBlueDeep : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.brandBlueDeep : AppColors.ink300,
            ),
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
