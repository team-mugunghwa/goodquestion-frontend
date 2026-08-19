import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/kid_button.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../domain/entities/saved_word.dart';

/// 단어 지우기 전에 한 번 묻는 시트. [word_detail_sheet.dart] 와 같은
/// 바텀시트 형태로 통일합니다 - 이 화면의 모달은 전부 이 모양입니다.
///
/// 되돌릴 수 없는 동작이라 **안전한 선택(다시 보기)을 주 버튼으로**
/// 둡니다 - 위험한 동작을 크고 진한 버튼으로 강조하면 급하게 누르는
/// 아이한테 오히려 사고를 부릅니다. (`docs/DESIGN_SYSTEM.md` 3장 - 아이
/// 화면에는 경고색도 안 씁니다)
///
/// `true` 를 반환하면 지우기로 결정한 것입니다.
Future<bool> showDeleteWordSheet(
  BuildContext context, {
  required SavedWord word,
  required ScreenMetrics metrics,
}) async {
  final bool? confirmed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) =>
        _DeleteWordSheet(word: word, metrics: metrics),
  );
  return confirmed ?? false;
}

class _DeleteWordSheet extends StatelessWidget {
  const _DeleteWordSheet({required this.word, required this.metrics});

  final SavedWord word;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          metrics.screenPadding,
          AppSpacing.md,
          metrics.screenPadding,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              WordStrings.deleteTitle(word.word),
              textAlign: TextAlign.center,
              style: metrics.text(AppTypography.kidTitle),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              WordStrings.deleteMessage,
              textAlign: TextAlign.center,
              style: metrics
                  .text(AppTypography.kidBody)
                  .copyWith(color: AppColors.ink500),
            ),
            const SizedBox(height: AppSpacing.xl),
            KidPrimaryButton(
              icon: AppIcons.back,
              label: WordStrings.deleteKeep,
              labelStyle: metrics.text(AppTypography.kidButton),
              expand: true,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: AppSpacing.md),
            KidSecondaryButton(
              icon: AppIcons.delete,
              label: WordStrings.deleteConfirm,
              labelStyle: metrics.text(AppTypography.kidButton),
              expand: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}
