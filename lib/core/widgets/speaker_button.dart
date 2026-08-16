import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/speech_service.dart';
import '../constants/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'press_scale.dart';

/// 소리로 들려주는 버튼. "들려줘"(이야기 상세)와 단어 카드의 스피커가 같은 것을 씁니다.
///
/// ## 소리가 나는 길은 둘입니다
///
/// | 무엇 | 언제 | 상태 |
/// |---|---|---|
/// | [speakText] | 기기 내장 목소리로 읽어 줌 | ✅ 실제로 납니다 |
/// | [audio] | 준비된 음성 파일 재생 | 🚧 아직 [mockDuration] 시뮬레이션 |
///
/// [speakText] 가 먼저입니다. 음성 파일이 아직 하나도 없어서, 지금 실제로
/// 소리를 내는 건 이쪽뿐입니다. → `docs/DECISIONS.md` 016 · 019
///
/// **긴 글을 [speakText] 로 넘기지 마세요.** 기기 기본 목소리는 캐릭터 목소리가
/// 아니라, 이야기 낭독에 쓰면 톤이 깨집니다. 단어처럼 짧은 것만 읽히세요.
///
/// 이 앱은 "말"이 주제라 소리가 본체입니다. 글을 못 읽는 아이가 **버튼 하나로
/// 내용을 들을 수 있어야** 화면이 성립합니다.
class SpeakerButton extends StatefulWidget {
  const SpeakerButton({
    super.key,
    required this.audio,
    required this.semanticLabel,
    this.speakText,
    this.label,
    this.labelStyle,
    this.size = AppSizes.tapChildSecondary,
    this.filled = false,
  });

  /// 재생할 음성 파일 경로. `null` 이면 [speakText] 로 넘어갑니다.
  final String? audio;

  /// 기기 내장 목소리로 읽어 줄 글자. 한국어 목소리가 없는 기기에서는
  /// 이 값이 있어도 버튼이 비활성됩니다.
  final String? speakText;

  /// 스크린리더가 읽을 이름. ("들려줘", "며느리 발음 듣기")
  final String semanticLabel;

  /// 옆에 붙는 한 단어. 아이가 누르는 큰 버튼이면 **반드시 주세요** —
  /// 아이콘 단독 버튼은 저학년이 못 알아봅니다. (`docs/DESIGN_SYSTEM.md` 7장)
  final String? label;

  final TextStyle? labelStyle;

  /// 지름(라벨이 없을 때) 또는 높이(라벨이 있을 때).
  final double size;

  /// 진한 면 + 흰 아이콘으로 그릴지. 목록 안의 보조 버튼은 `false`.
  final bool filled;

  /// 진짜 오디오가 들어오기 전까지의 가짜 재생 길이.
  static const Duration mockDuration = Duration(milliseconds: 1800);

  @override
  State<SpeakerButton> createState() => _SpeakerButtonState();
}

class _SpeakerButtonState extends State<SpeakerButton> {
  bool _playing = false;
  Timer? _timer;

  /// 늦게 끝난 이전 재생이 새 재생의 상태를 지우지 못하게 하는 표입니다.
  int _turn = 0;

  /// 읽어 줄 글자가 있고, 기기가 읽어 줄 수 있는가.
  String? get _speakable {
    final String? text = widget.speakText;
    if (text == null || text.trim().isEmpty) return null;
    return SpeechService.instance.available ? text : null;
  }

  @override
  void dispose() {
    // 화면을 나가면 재생도 끝납니다. 타이머를 안 끄면 사라진 위젯에
    // setState 를 걸게 됩니다.
    _timer?.cancel();
    // 모달을 닫았는데 목소리만 계속 남는 걸 막습니다.
    if (_playing) unawaited(SpeechService.instance.stop());
    super.dispose();
  }

  // 재생 중에 다시 누르면 처음부터 다시 — 멈춤이 아니라 되감기입니다.
  // 아이가 원하는 건 "한 번 더 들려줘"이지 "정지"가 아닙니다.
  void _toggle() {
    final String? text = _speakable;
    if (text != null) {
      unawaited(_speak(text));
      return;
    }
    _timer?.cancel();
    final int turn = ++_turn;
    setState(() => _playing = true);
    _timer = Timer(SpeakerButton.mockDuration, () {
      if (!mounted || turn != _turn) return;
      setState(() => _playing = false);
    });
  }

  Future<void> _speak(String text) async {
    _timer?.cancel();
    final int turn = ++_turn;
    setState(() => _playing = true);
    await SpeechService.instance.speak(text);
    // 그사이 다시 눌렸으면 그쪽이 상태의 주인입니다.
    if (!mounted || turn != _turn) return;
    setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.audio != null || _speakable != null;
    final Color foreground = widget.filled
        ? AppColors.surface
        : AppColors.brandBlueDeep;
    final String? label = widget.label;

    return PressScale(
      onTap: enabled ? _toggle : null,
      borderRadius: AppRadius.pill,
      semanticLabel: widget.semanticLabel,
      child: Container(
        height: widget.size,
        width: label == null ? widget.size : null,
        padding: label == null
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: widget.filled
              ? AppColors.brandBlueDeep
              : AppColors.brandBlueSurface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 재생 중에는 아이콘이 파형으로 바뀝니다. 소리가 안 나는 환경
            // (무음 모드)에서도 눌린 게 보여야 합니다.
            AnimatedSwitcher(
              duration: respect(context, AppDurations.quick),
              child: Icon(
                _playing ? AppIcons.speaking : AppIcons.soundOn,
                key: ValueKey<bool>(_playing),
                size: AppSizes.iconChild,
                color: enabled ? foreground : AppColors.ink300,
              ),
            ),
            if (label != null) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: (widget.labelStyle ?? AppTypography.kidButton).copyWith(
                  color: enabled ? foreground : AppColors.ink300,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
