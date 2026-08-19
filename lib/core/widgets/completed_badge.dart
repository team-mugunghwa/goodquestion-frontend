import 'package:flutter/material.dart';

import '../constants/app_icons.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'screen_metrics.dart';

/// "다 들었어" — 완주한 이야기의 표지 위에 얹는 뱃지.
///
/// 이야기 목록 카드와 이야기 상세가 **같은 뱃지**를 씁니다. 목록에서 본
/// 표식이 상세에서 다른 모양이면 같은 사실로 안 읽힙니다.
///
/// ## 왜 칩이 아니라 표지 위인가
///
/// 완주 여부는 메타 정보(시간·난이도·주제)와 성격이 다릅니다. 저 셋은
/// **고를 때 보는 정보**라 칩 줄에 모여 있어야 하고, 이건 **아이가 한 일**
/// 이라 그림 위에 도장처럼 찍혀야 합니다. 칩 줄에 넣으면 네 번째 회색
/// 조각이 되어 아무도 안 봅니다.
///
/// 글자를 빼고 아이콘만 두지 않습니다 — 체크 하나는 "선택됨"으로도 읽힙니다.
class CompletedBadge extends StatelessWidget {
  const CompletedBadge({
    super.key,
    required this.metrics,
    this.compact = false,
  });

  final ScreenMetrics metrics;

  /// 목록 카드처럼 좁은 자리. 글자와 아이콘을 한 단계 줄입니다.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final TextStyle label = metrics.text(
      compact ? AppTypography.kidCaption : AppTypography.kidLabel,
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        // 완료의 색(`AppColors.success` = brandGreenDeep). 표지 그림 위에
        // 얹히므로 반투명을 쓰지 않습니다 — 그림이 밝으면 글자가 사라집니다.
        color: AppColors.success,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
        boxShadow: AppShadows.soft,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm : AppSpacing.md,
          vertical: compact ? AppSpacing.xs : AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              AppIcons.done,
              size: compact ? AppSizes.iconCaption : AppSizes.iconInline,
              color: AppColors.surface,
            ),
            SizedBox(width: compact ? AppSpacing.xs : AppSpacing.sm),
            Text(
              StoryDetailStrings.completedBadge,
              style: label.copyWith(color: AppColors.surface),
            ),
          ],
        ),
      ),
    );
  }
}
