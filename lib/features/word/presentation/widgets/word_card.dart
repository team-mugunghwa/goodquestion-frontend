import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../domain/entities/saved_word.dart';

/// 단어 카드 한 장. 왼쪽에 표제어, 오른쪽에 뜻 한 줄, 끝에 좋아요 토글.
///
/// 소리 듣기는 상세 모달의 몫입니다 — 목록의 스피커는 오터치만 만들고
/// 아이의 시선을 글자에서 빼앗았습니다. 뜻은 한 줄로 잘라 보여 주고,
/// 전체 뜻과 예문은 카드를 눌러 상세에서 봅니다.
///
/// 하트는 **표시가 아니라 토글**입니다. 목록에서 바로 좋아요를 켜고 끕니다.
class WordCard extends StatelessWidget {
  const WordCard({
    super.key,
    required this.word,
    required this.metrics,
    required this.onTap,
    required this.onToggleLike,
  });

  final SavedWord word;
  final ScreenMetrics metrics;
  final VoidCallback onTap;
  final VoidCallback onToggleLike;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: <Widget>[
          // 카드 몸통만 모달을 엽니다. 하트는 이 영역 밖입니다.
          Expanded(
            child: PressScale(
              onTap: onTap,
              borderRadius: AppRadius.xl,
              semanticLabel: '${word.word} · ${word.meaning}',
              child: Container(
                height: AppSizes.tapChildPrimary,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    // 첫 글자 배지 — 글자만 나열된 목록에 시선이 앉을 자리를
                    // 만듭니다. 파스텔 면 + 잉크 글자 규칙 그대로입니다.
                    Container(
                      width: AppSizes.tapChildSecondary - AppSpacing.md,
                      height: AppSizes.tapChildSecondary - AppSpacing.md,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.brandBlueSurface,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        word.word.isEmpty ? '' : word.word.substring(0, 1),
                        style: metrics
                            .text(AppTypography.kidLabel)
                            .copyWith(color: AppColors.brandBlueDeep),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      word.word,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // kidButton 은 파란 버튼 위 흰 글자용이라 색을 잉크로.
                      style: metrics
                          .text(AppTypography.kidButton)
                          .copyWith(color: AppColors.ink900),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // 뜻은 오른쪽 정렬 한 줄. 길면 잘리고, 전체는 상세에서.
                    Expanded(
                      child: Text(
                        word.meaning,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: metrics
                            .text(AppTypography.kidLabel)
                            .copyWith(color: AppColors.ink500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 좋아요 토글. 몸통과 분리된 64 타겟 — 오터치가 곧 좌절입니다.
          Semantics(
            button: true,
            child: PressScale(
              onTap: onToggleLike,
              borderRadius: AppRadius.pill,
              semanticLabel: word.liked ? WordStrings.unlike : WordStrings.like,
              child: SizedBox.square(
                dimension: AppSizes.tapChildSecondary,
                child: Icon(
                  word.liked ? AppIcons.like : AppIcons.likeOff,
                  size: AppSizes.iconChild,
                  color: word.liked
                      ? AppColors.brandBlueDeep
                      : AppColors.ink300,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}
