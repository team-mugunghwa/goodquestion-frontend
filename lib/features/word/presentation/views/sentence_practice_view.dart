import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_canvas.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/cosmic_backdrop.dart';
import '../../../../core/widgets/kid_button.dart';
import '../../../../core/widgets/kid_chips.dart';
import '../../../../core/widgets/kid_speech_bubble.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../../core/widgets/stardust_chip.dart';
import '../../../play/presentation/voice/mission_voice_recorder.dart';
import '../../domain/entities/saved_word.dart';
import '../../domain/entities/sentence_practice.dart';
import '../../domain/repositories/word_repository.dart';
import '../viewmodels/sentence_practice_view_model.dart';

/// 예문 따라 말하기 - 단어장에서 담은 단어의 예문을 소리 내어 따라 말하고
/// 별가루를 받는 화면.
///
/// ## 이 화면이 하는 한 가지 일
///
/// **문장 하나를 골라 따라 말하게 하기.** 세 단계가 한 화면에서 갈립니다.
///
/// | 단계 | 내용 |
/// |---|---|
/// | 1 | 예문 고르기 - 있는 종류만 카드로 |
/// | 2 | 말하기 - 큰 문장 + 마이크 |
/// | 3 | 결과 - 보상 / 격려 / 안내 |
class SentencePracticePage extends StatelessWidget {
  const SentencePracticePage({
    super.key,
    required this.wordId,
    this.initialWord,
  });

  final String wordId;

  /// 단어장 목록이 push 하면서 실어 보내는 단어. 딥링크로 들어오면 `null`
  /// 이고, 그때만 ViewModel 이 서버에서 다시 찾습니다.
  final SavedWord? initialWord;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SentencePracticeViewModel>(
      create: (_) => SentencePracticeViewModel(
        getIt<WordRepository>(),
        wordId: wordId,
        initialWord: initialWord,
      )..load(),
      child: const SentencePracticeView(),
    );
  }
}

/// ViewModel 이 이미 위에 있다고 가정하는 본체. (테스트에서 직접 씁니다)
class SentencePracticeView extends StatefulWidget {
  const SentencePracticeView({super.key, this.recorder});

  /// 테스트에서 가짜 녹음기를 끼워 넣는 자리입니다.
  final MissionVoiceRecorder? recorder;

  @override
  State<SentencePracticeView> createState() => _SentencePracticeViewState();
}

class _SentencePracticeViewState extends State<SentencePracticeView> {
  late final MissionVoiceRecorder _recorder;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _recorder = widget.recorder ?? DeviceMissionVoiceRecorder();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  Future<void> _toggleMic() async {
    final SentencePracticeViewModel vm = context
        .read<SentencePracticeViewModel>();
    switch (vm.voiceStage) {
      case PracticeVoiceStage.transcribing:
      case PracticeVoiceStage.submitting:
        return;
      case PracticeVoiceStage.recording:
        await _stopAndSubmit(vm);
        return;
      case PracticeVoiceStage.ready:
        break;
    }
    try {
      final bool allowed = await _recorder.start();
      if (!mounted) return;
      if (!allowed) {
        vm.micDenied();
        return;
      }
      vm.beginRecording();
      setState(() => _recordingSeconds = 0);
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || vm.voiceStage != PracticeVoiceStage.recording) return;
        setState(() => _recordingSeconds++);
        // 업로드 한도(10MB, 웹 48kHz 기준 109초) 전에 끊는다. -> mission_overlay
        if (_recordingSeconds >= maxRecordingSeconds) {
          unawaited(_stopAndSubmit(vm));
        }
      });
    } on Object {
      if (mounted) vm.micFailed();
    }
  }

  Future<void> _stopAndSubmit(SentencePracticeViewModel vm) async {
    _recordingTimer?.cancel();
    Uint8List? audio;
    try {
      audio = await _recorder.stop();
    } on Object {
      audio = null;
    }
    if (!mounted) return;
    await vm.submitRecording(audio);
  }

  void _onBack(SentencePracticeViewModel vm) {
    if (vm.state.isSuccess && vm.step != PracticeStep.pick) {
      // 녹음 중이면 버리고 나갑니다. 뒤로 가려는 아이를 붙잡지 않습니다.
      if (vm.voiceStage == PracticeVoiceStage.recording) {
        _recordingTimer?.cancel();
        unawaited(_recorder.cancel());
      }
      vm.backToPick();
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final SentencePracticeViewModel vm = context
        .watch<SentencePracticeViewModel>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppCanvas.day(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 단어장에서 이어져 들어오는 화면 — 배경도 같은 세계관을 잇습니다.
            const CosmicBackdrop(seed: 11, planetCenterX: 0.5),
            SafeArea(child: _layout(context, vm)),
          ],
        ),
      ),
    );
  }

  Widget _layout(BuildContext context, SentencePracticeViewModel vm) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ScreenMetrics metrics = ScreenMetrics.of(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Header(vm: vm, metrics: metrics, onBack: () => _onBack(vm)),
            Expanded(
              child: AnimatedSwitcher(
                duration: respect(context, AppDurations.normal),
                switchInCurve: AppCurves.standard,
                switchOutCurve: AppCurves.exit,
                layoutBuilder: (Widget? current, List<Widget> previous) =>
                    Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previous,
                        if (current != null) current,
                      ],
                    ),
                child: _body(context, vm, metrics),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    SentencePracticeViewModel vm,
    ScreenMetrics metrics,
  ) {
    if (vm.state.isError) {
      return AppKidErrorView(
        key: const ValueKey<String>('practice-error'),
        messageStyle: metrics.text(AppTypography.kidBody),
        onRetry: vm.load,
      );
    }
    if (!vm.state.isSuccess) {
      return _Skeleton(
        key: const ValueKey<String>('practice-skeleton'),
        metrics: metrics,
      );
    }
    switch (vm.step) {
      case PracticeStep.pick:
        if (vm.sentences.isEmpty) {
          // 딥링크로 예문 없는 단어에 들어온 경우. 단어장이 나가는 문입니다.
          return AppKidEmptyView(
            key: const ValueKey<String>('practice-no-sentence'),
            message: SentencePracticeStrings.noSentence,
            actionIcon: AppIcons.words,
            actionLabel: SentencePracticeStrings.backToWords,
            messageStyle: metrics.text(AppTypography.kidBody),
            onAction: () => context.pop(),
          );
        }
        return _PickStage(
          key: const ValueKey<String>('practice-pick'),
          vm: vm,
          metrics: metrics,
        );
      case PracticeStep.speak:
        return _SpeakStage(
          key: const ValueKey<String>('practice-speak'),
          vm: vm,
          metrics: metrics,
          recordingSeconds: _recordingSeconds,
          onMic: _toggleMic,
        );
      case PracticeStep.result:
        return _ResultStage(
          key: const ValueKey<String>('practice-result'),
          vm: vm,
          metrics: metrics,
        );
    }
  }
}

/// 예문 종류의 한글 라벨.
String _typeLabel(SentenceType type) => switch (type) {
  SentenceType.story => SentencePracticeStrings.typeStory,
  SentenceType.daily => SentencePracticeStrings.typeDaily,
  SentenceType.advanced => SentencePracticeStrings.typeAdvanced,
};

/// 상단 - 뒤로가기 + 화면 제목.
class _Header extends StatelessWidget {
  const _Header({
    required this.vm,
    required this.metrics,
    required this.onBack,
  });

  final SentencePracticeViewModel vm;
  final ScreenMetrics metrics;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        AppSpacing.md,
        metrics.screenPadding,
        AppSpacing.lg,
      ),
      child: Row(
        children: <Widget>[
          KidBackButton(
            onPressed: onBack,
            labelStyle: metrics.text(AppTypography.kidLabel),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              vm.word?.word ?? SentencePracticeStrings.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: metrics.text(AppTypography.kidTitle),
            ),
          ),
        ],
      ),
    );
  }
}

/// 1단계 - 있는 예문만 카드로 보여 주고 하나를 고르게 합니다.
class _PickStage extends StatelessWidget {
  const _PickStage({super.key, required this.vm, required this.metrics});

  final SentencePracticeViewModel vm;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        0,
        metrics.screenPadding,
        metrics.screenPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            SentencePracticeStrings.pickGuide,
            style: metrics.text(AppTypography.kidBody),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final PracticeSentence sentence in vm.sentences) ...<Widget>[
            _SentenceCard(
              sentence: sentence,
              metrics: metrics,
              onTap: () => vm.selectSentence(sentence.type),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _SentenceCard extends StatelessWidget {
  const _SentenceCard({
    required this.sentence,
    required this.metrics,
    required this.onTap,
  });

  final PracticeSentence sentence;
  final ScreenMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String label = _typeLabel(sentence.type);
    return PressScale(
      onTap: onTap,
      borderRadius: AppRadius.xl,
      semanticLabel: '$label, ${sentence.text}',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            KidInfoChip(label: label, icon: AppIcons.speak, metrics: metrics),
            const SizedBox(height: AppSpacing.md),
            Text(sentence.text, style: metrics.text(AppTypography.kidBody)),
          ],
        ),
      ),
    );
  }
}

/// 2단계 - 큰 문장 + 마이크. 탭해서 시작하고 다시 탭해서 끝냅니다.
class _SpeakStage extends StatelessWidget {
  const _SpeakStage({
    super.key,
    required this.vm,
    required this.metrics,
    required this.recordingSeconds,
    required this.onMic,
  });

  final SentencePracticeViewModel vm;
  final ScreenMetrics metrics;
  final int recordingSeconds;
  final VoidCallback onMic;

  String get _statusText => switch (vm.voiceStage) {
    PracticeVoiceStage.ready => SentencePracticeStrings.micReady,
    PracticeVoiceStage.recording => SentencePracticeStrings.micRecording(
      recordingSeconds,
    ),
    PracticeVoiceStage.transcribing => SentencePracticeStrings.micTranscribing,
    PracticeVoiceStage.submitting => SentencePracticeStrings.micSubmitting,
  };

  String? get _hintText => switch (vm.micHint) {
    null => null,
    PracticeMicHint.notHeard => SentencePracticeStrings.hintNotHeard,
    PracticeMicHint.tooLong => SentencePracticeStrings.hintTooLong,
    PracticeMicHint.waitAndRetry => SentencePracticeStrings.hintWait,
    PracticeMicHint.permission => SentencePracticeStrings.hintMicPermission,
    PracticeMicHint.micFailed => SentencePracticeStrings.hintMicFailed,
  };

  @override
  Widget build(BuildContext context) {
    final SentenceType? type = vm.selectedType;
    final String? hint = _hintText;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: metrics.screenPadding),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (type != null)
                      KidInfoChip(
                        label: _typeLabel(type),
                        icon: AppIcons.speak,
                        metrics: metrics,
                      ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      SentencePracticeStrings.speakGuide,
                      style: metrics
                          .text(AppTypography.kidLabel)
                          .copyWith(color: AppColors.ink500),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    KidSpeechBubble(
                      child: Text(
                        vm.targetSentence ?? '',
                        style: metrics.text(AppTypography.kidTitle),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hint != null) ...<Widget>[
            Text(
              hint,
              textAlign: TextAlign.center,
              style: metrics
                  .text(AppTypography.kidLabel)
                  .copyWith(color: AppColors.caution),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _MicButton(stage: vm.voiceStage, onTap: onMic),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _statusText,
            textAlign: TextAlign.center,
            style: metrics
                .text(AppTypography.kidLabel)
                .copyWith(color: AppColors.ink500),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// 마이크. 화면에서 가장 큰 조작 요소이고 늘 같은 자리에 있습니다.
class _MicButton extends StatelessWidget {
  const _MicButton({required this.stage, required this.onTap});

  final PracticeVoiceStage stage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool recording = stage == PracticeVoiceStage.recording;
    final bool busy =
        stage == PracticeVoiceStage.transcribing ||
        stage == PracticeVoiceStage.submitting;
    return PressScale(
      onTap: busy ? null : onTap,
      borderRadius: AppRadius.pill,
      semanticLabel: recording
          ? SentencePracticeStrings.micStop
          : SentencePracticeStrings.micStart,
      child: Container(
        height: AppSizes.mic,
        width: AppSizes.mic,
        decoration: BoxDecoration(
          color: recording
              ? AppColors.brandGreenDeep
              : busy
              ? AppColors.ink300
              : AppColors.brandBlueDeep,
          shape: BoxShape.circle,
          boxShadow: AppShadows.lift,
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(
                  color: AppColors.surface,
                  strokeWidth: 4,
                ),
              )
            : Icon(
                recording ? AppIcons.stop : AppIcons.speak,
                size: AppSizes.iconChild,
                color: AppColors.surface,
              ),
      ),
    );
  }
}

/// 3단계 - 결과. 다섯 갈래 전부 여기서 그립니다.
class _ResultStage extends StatelessWidget {
  const _ResultStage({super.key, required this.vm, required this.metrics});

  final SentencePracticeViewModel vm;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    switch (vm.resultKind) {
      case PracticeResultKind.rewarded:
        return _RewardedResult(vm: vm, metrics: metrics);
      case PracticeResultKind.alreadyRewarded:
        return _PraiseResult(
          title: SentencePracticeStrings.alreadyRewardedTitle,
          body: SentencePracticeStrings.alreadyRewardedBody,
          vm: vm,
          metrics: metrics,
          showAnotherSentence: true,
        );
      case PracticeResultKind.dailyLimit:
        return _PraiseResult(
          title: SentencePracticeStrings.dailyLimitTitle,
          body: SentencePracticeStrings.dailyLimitBody,
          vm: vm,
          metrics: metrics,
          showAnotherSentence: false,
        );
      case PracticeResultKind.notMatched:
        return _NotMatchedResult(vm: vm, metrics: metrics);
      case PracticeResultKind.sentenceMissing:
        return AppKidMessageView(
          message: SentencePracticeStrings.sentenceMissing,
          actionIcon: AppIcons.words,
          actionLabel: SentencePracticeStrings.pickAgain,
          messageStyle: metrics.text(AppTypography.kidBody),
          onAction: vm.backToPick,
        );
      case PracticeResultKind.failed:
      case null:
        return AppKidErrorView(
          messageStyle: metrics.text(AppTypography.kidBody),
          onRetry: vm.resubmit,
        );
    }
  }
}

/// 별가루를 받은 결과. 이 화면에서 유일하게 노랑이 나오는 자리입니다.
class _RewardedResult extends StatelessWidget {
  const _RewardedResult({required this.vm, required this.metrics});

  final SentencePracticeViewModel vm;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final int amount = vm.result?.stardustAmount ?? 0;
    final int balance = vm.result?.stardustBalance ?? 0;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(metrics.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              SentencePracticeStrings.rewardedTitle,
              textAlign: TextAlign.center,
              style: metrics.text(AppTypography.kidTitle),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              SentencePracticeStrings.stardustGain(amount),
              style: metrics
                  .text(AppTypography.kidHero)
                  .copyWith(color: AppColors.stardustDeep),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  SentencePracticeStrings.stardustBalanceLabel,
                  style: metrics
                      .text(AppTypography.kidLabel)
                      .copyWith(color: AppColors.ink500),
                ),
                const SizedBox(width: AppSpacing.sm),
                StardustChip.day(count: balance),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            _ResultActions(vm: vm, metrics: metrics, showAnotherSentence: true),
          ],
        ),
      ),
    );
  }
}

/// 맞았지만 별가루는 없는 결과. (이미 받음 / 오늘 한도)
class _PraiseResult extends StatelessWidget {
  const _PraiseResult({
    required this.title,
    required this.body,
    required this.vm,
    required this.metrics,
    required this.showAnotherSentence,
  });

  final String title;
  final String body;
  final SentencePracticeViewModel vm;
  final ScreenMetrics metrics;
  final bool showAnotherSentence;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(metrics.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              textAlign: TextAlign.center,
              style: metrics.text(AppTypography.kidTitle),
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.bubbleMaxWidth,
              ),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: metrics.text(AppTypography.kidBody),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _ResultActions(
              vm: vm,
              metrics: metrics,
              showAnotherSentence: showAnotherSentence,
            ),
          ],
        ),
      ),
    );
  }
}

/// 90% 미만 - 실패라고 부르지 않고 얼마나 가까웠는지 보여 줍니다.
class _NotMatchedResult extends StatelessWidget {
  const _NotMatchedResult({required this.vm, required this.metrics});

  final SentencePracticeViewModel vm;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final SentencePracticeResult? result = vm.result;
    return SingleChildScrollView(
      padding: EdgeInsets.all(metrics.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            SentencePracticeStrings.notMatchedTitle,
            style: metrics.text(AppTypography.kidTitle),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            SentencePracticeStrings.similarity(result?.similarityPercent ?? 0),
            style: metrics.text(AppTypography.kidBody),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            SentencePracticeStrings.targetLabel,
            style: metrics
                .text(AppTypography.kidLabel)
                .copyWith(color: AppColors.ink500),
          ),
          const SizedBox(height: AppSpacing.xs),
          KidSpeechBubble(
            child: Text(
              result?.targetSentence ?? vm.targetSentence ?? '',
              style: metrics.text(AppTypography.kidBody),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            SentencePracticeStrings.spokenLabel,
            style: metrics
                .text(AppTypography.kidLabel)
                .copyWith(color: AppColors.ink500),
          ),
          const SizedBox(height: AppSpacing.xs),
          KidSpeechBubble(
            speaker: KidSpeaker.child,
            child: Text(
              vm.spokenText ?? '',
              style: metrics.text(AppTypography.kidBody),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: KidPrimaryButton(
              icon: AppIcons.speak,
              label: SentencePracticeStrings.retry,
              labelStyle: metrics.text(AppTypography.kidButton),
              onPressed: vm.speakAgain,
            ),
          ),
        ],
      ),
    );
  }
}

/// 결과 화면 하단 버튼 묶음. "다른 예문 해보기"와 "단어장으로".
class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.vm,
    required this.metrics,
    required this.showAnotherSentence,
  });

  final SentencePracticeViewModel vm;
  final ScreenMetrics metrics;
  final bool showAnotherSentence;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showAnotherSentence && vm.sentences.length > 1) ...<Widget>[
          KidPrimaryButton(
            icon: AppIcons.speak,
            label: SentencePracticeStrings.anotherSentence,
            labelStyle: metrics.text(AppTypography.kidButton),
            expand: true,
            onPressed: vm.backToPick,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        // 단어장으로 돌아가기는 보조 행동 — 주 버튼(다른 예문)과 얼굴을
        // 다르게 해 다음 행동이 한눈에 정해지게 합니다.
        KidSecondaryButton(
          icon: AppIcons.words,
          label: SentencePracticeStrings.backToWords,
          labelStyle: metrics.text(AppTypography.kidButton),
          expand: true,
          onPressed: () => context.pop(),
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({super.key, required this.metrics});

  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: metrics.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SkeletonBox(width: 240, height: AppSpacing.xl),
          const SizedBox(height: AppSpacing.lg),
          for (int i = 0; i < 3; i++) ...<Widget>[
            const SkeletonBox(height: 120, borderRadius: AppRadius.xl),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}
