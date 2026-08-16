import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/speaker_button.dart';
import '../../domain/entities/saved_word.dart';

/// 단어 카드 한 장. 표제어 + 스피커 + 좋아요 상태.
///
/// **뜻과 예문을 여기 넣지 마세요.** 목록은 밀도가 낮아야 하고, 뜻은 상세
/// 모달의 몫입니다. (PRD F-10)
///
/// 카드 탭과 스피커 탭은 **다른 일**을 합니다. 그래서 스피커를 카드 안의
/// 독립된 터치 영역으로 두고, 둘 사이에 간격을 줍니다 — 오터치가 곧 좌절입니다.
class WordCard extends StatelessWidget {
  const WordCard({
    super.key,
    required this.word,
    required this.metrics,
    required this.onTap,
  });

  final SavedWord word;
  final ScreenMetrics metrics;
  final VoidCallback onTap;

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
          // 카드 몸통만 모달을 엽니다. 스피커는 이 영역 밖입니다.
          Expanded(
            child: PressScale(
              onTap: onTap,
              borderRadius: AppRadius.xl,
              semanticLabel: word.word,
              child: Container(
                height: AppSizes.tapChildPrimary,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  word.word,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: metrics.text(AppTypography.kidTitle),
                ),
              ),
            ),
          ),
          SpeakerButton(
            audio: word.audio,
            speakText: word.word,
            semanticLabel: WordStrings.listenTo(word.word),
          ),
          const SizedBox(width: AppSpacing.md),
          // 좋아요는 **표시만** 합니다. 토글은 상세 모달의 책임입니다.
          Icon(
            word.liked ? AppIcons.like : AppIcons.likeOff,
            size: AppSizes.iconChild,
            color: word.liked ? AppColors.brandBlueDeep : AppColors.ink300,
            semanticLabel: word.liked ? WordStrings.like : null,
          ),
          const SizedBox(width: AppSpacing.lg),
        ],
      ),
    );
  }
}
