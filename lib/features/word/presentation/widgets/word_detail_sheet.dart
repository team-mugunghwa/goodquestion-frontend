import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/kid_button.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/speaker_button.dart';
import '../../domain/entities/saved_word.dart';

/// 단어 상세 모달(모달 #2).
///
/// 목록에서 감춰 둔 것 — **쉬운 뜻 · 이야기 속 문장 · 음성 · 좋아요** —
/// 를 여기서 전부 보여 줍니다. 좋아요 토글은 이 모달의 책임이고,
/// 닫히면 목록 카드에 즉시 반영됩니다.
///
/// [onToggleLike] 는 바뀐 값을 화면 밖(ViewModel)에 알리고, 이 시트는
/// 넘겨받은 [word] 가 갱신되면 다시 그려집니다.
Future<void> showWordDetailSheet(
  BuildContext context, {
  required SavedWord word,
  required ScreenMetrics metrics,
  required Future<void> Function() onToggleLike,
  required SavedWord? Function() latest,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) => _WordDetailSheet(
      initial: word,
      metrics: metrics,
      onToggleLike: onToggleLike,
      latest: latest,
    ),
  );
}

class _WordDetailSheet extends StatefulWidget {
  const _WordDetailSheet({
    required this.initial,
    required this.metrics,
    required this.onToggleLike,
    required this.latest,
  });

  final SavedWord initial;
  final ScreenMetrics metrics;
  final Future<void> Function() onToggleLike;

  /// 토글 후 최신 단어를 다시 읽어 오는 함수. ViewModel 이 진실의 출처입니다.
  final SavedWord? Function() latest;

  @override
  State<_WordDetailSheet> createState() => _WordDetailSheetState();
}

class _WordDetailSheetState extends State<_WordDetailSheet> {
  late SavedWord _word = widget.initial;

  Future<void> _toggle() async {
    await widget.onToggleLike();
    if (!mounted) return;
    setState(() => _word = widget.latest() ?? _word);
  }

  @override
  Widget build(BuildContext context) {
    final ScreenMetrics metrics = widget.metrics;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          metrics.screenPadding,
          AppSpacing.md,
          metrics.screenPadding,
          AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // 표제어 + 좋아요 + 소리. 아이가 여기서 하는 첫 행동은 "듣기"입니다.
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _word.word,
                      style: metrics.text(AppTypography.kidHero),
                    ),
                  ),
                  _LikeButton(
                    liked: _word.liked,
                    size: AppSizes.tapChildPrimary,
                    onPressed: _toggle,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SpeakerButton(
                    audio: _word.audio,
                    speakText: _word.word,
                    semanticLabel: WordStrings.listenTo(_word.word),
                    size: AppSizes.tapChildPrimary,
                    filled: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // 뜻은 서버가 LLM 으로 만들어 주지만 없을 수 있습니다. 빈 칸을
              // 두면 제목만 남아 고장으로 보입니다.
              _Block(
                title: WordStrings.meaning,
                body: _word.hasMeaning
                    ? _word.meaning
                    : WordStrings.meaningMissing,
                metrics: metrics,
              ),
              const SizedBox(height: AppSpacing.lg),
              _Block(
                title: WordStrings.exampleInStory,
                body: _word.sentence,
                metrics: metrics,
              ),
              // 예문 3종(이야기/일상/심화) - 서버 V14 이전에 담긴 단어는
              // 일상/심화가 없어서 칸을 그리지 않습니다.
              if (_word.sentenceDaily?.isNotEmpty == true) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                _Block(
                  title: WordStrings.exampleInDaily,
                  body: _word.sentenceDaily!,
                  metrics: metrics,
                ),
              ],
              if (_word.sentenceAdvanced?.isNotEmpty == true) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                _Block(
                  title: WordStrings.exampleAdvanced,
                  body: _word.sentenceAdvanced!,
                  metrics: metrics,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              KidPrimaryButton(
                icon: AppIcons.close,
                label: WordStrings.close,
                labelStyle: metrics.text(AppTypography.kidButton),
                expand: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.title,
    required this.body,
    required this.metrics,
  });

  final String title;
  final String body;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: metrics
              .text(AppTypography.kidLabel)
              .copyWith(color: AppColors.ink500),
        ),
        const SizedBox(height: AppSpacing.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.bubbleMaxWidth),
          child: Text(body, style: metrics.text(AppTypography.kidBody)),
        ),
      ],
    );
  }
}

/// 좋아요 토글. 색만으로 구분하지 않습니다 — 아이콘의 **채움 여부**가
/// 함께 바뀝니다.
///
/// 라벨 없이 하트 아이콘 하나만 둡니다 — 소리듣기 버튼과 나란히 놓인
/// 아이콘 버튼 한 쌍으로 읽히도록, 크기([size])도 소리듣기와 맞춥니다.
class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.liked,
    required this.size,
    required this.onPressed,
  });

  final bool liked;
  final double size;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onPressed,
      borderRadius: AppRadius.pill,
      semanticLabel: WordStrings.like,
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: liked ? AppColors.brandBlueSurface : AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: liked ? AppColors.brandBlueDeep : AppColors.ink300,
          ),
        ),
        child: Icon(
          liked ? AppIcons.like : AppIcons.likeOff,
          size: AppSizes.iconChild,
          color: liked ? AppColors.brandBlueDeep : AppColors.ink500,
        ),
      ),
    );
  }
}
