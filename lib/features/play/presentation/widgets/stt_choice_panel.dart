import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../data/stt_choice_catalog.dart';

/// 목소리를 세 번 이어서 못 알아들었을 때 내려오는 "골라 말하기" 판.
///
/// 이 판이 떠도 **마이크는 그대로 남습니다**(대화 화면 아래쪽 아이 말풍선).
/// 고르기로 내려온 것이지 마이크가 막힌 게 아니라서, 아이가 다시 말하고
/// 싶어 하면 그쪽이 우선입니다.
///
/// 면·모서리는 대화 화면이 쓰는 크림/골드 말풍선을 그대로 따라갑니다 -
/// 장면 이미지 위에 얹히는 화면이라 밝은 배경용 토큰 색(`AppColors`)을
/// 그대로 쓰면 배경에 묻힙니다. 크기는 토큰(`AppSizes`·`AppSpacing`)을 씁니다.
///
/// `core/widgets/speaker_button.dart` 를 쓰지 않은 이유: 그 버튼은 아직 진짜
/// 오디오가 아니라 정해진 시간만큼 재생 중 상태를 흉내 내고, 색도 흰 배경
/// 기준입니다. 여기서는 화면이 들고 있는 재생기가 실제로 mp3 를 틀고, 어느
/// 카드가 나오는 중인지는 [playingCardId] 로 위에서 내려받습니다.
class SttChoicePanel extends StatelessWidget {
  const SttChoicePanel({
    required this.characterName,
    required this.introText,
    required this.cards,
    required this.onChoose,
    required this.onListen,
    this.playingCardId,
    this.submitting = false,
    this.compact = false,
    super.key,
  });

  final String characterName;

  /// 캐릭터가 선택지를 내리며 건넨 말. 소리를 못 듣는 환경에서도 같은 말이
  /// 보여야 해서 자막으로 같이 답니다.
  final String introText;

  /// 보여줄 문장 카드. **비어 있으면 이 판을 띄우지 않습니다**(호출부 책임).
  final List<SttChoiceSentence> cards;

  final ValueChanged<SttChoiceSentence> onChoose;
  final ValueChanged<SttChoiceSentence> onListen;

  /// 지금 스피커로 들려주고 있는 카드. 소리가 작거나 꺼져 있어도 무엇이
  /// 재생 중인지 눈으로 보여야 합니다.
  final String? playingCardId;

  /// 고른 문장을 보내는 중. 연타로 두 번 보내지 않도록 카드를 잠급니다.
  final bool submitting;

  final bool compact;

  /// 위아래로 쌓았을 때 카드 한 장이 필요로 하는 최소 높이.
  /// (글 한 줄 + 듣기 버튼 [AppSizes.tapChildSecondary] + 안팎 여백)
  static const double _minStackedCardHeight = 150;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF3),
        borderRadius: BorderRadius.circular(
          compact ? AppRadius.lg : AppRadius.xl,
        ),
        border: Border.all(color: const Color(0xFFFFD66B), width: 3),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x55081729),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                AppIcons.characterSpeaking,
                color: Color(0xFF4EA883),
                size: 25,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$characterName의 말',
                style: const TextStyle(
                  color: Color(0xFF496179),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            label: introText,
            child: Text(
              introText,
              style: TextStyle(
                color: const Color(0xFF172A3E),
                fontSize: compact ? 21 : 26,
                height: 1.35,
                fontWeight: FontWeight.w900,
                letterSpacing: -.5,
              ),
            ),
          ),
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // **세 장이 한눈에 다 보여야 합니다.** 굴려야 보이는 카드는
                // 아이에게 없는 카드나 마찬가지입니다. 그래서 가로로 나누는
                // 것을 먼저 보고, 폭이 정말 좁을 때만 위아래로 쌓습니다.
                final double perCard = constraints.maxWidth / cards.length;
                final double stackNeeds =
                    cards.length * _minStackedCardHeight +
                    (cards.length - 1) * AppSpacing.md;
                final bool fitsStacked = constraints.maxHeight >= stackNeeds;
                final bool stacked =
                    perCard < 170 || (compact && fitsStacked && perCard < 260);
                if (!stacked) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (int index = 0; index < cards.length; index++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: index == 0 ? 0 : AppSpacing.md,
                            ),
                            child: _buildCard(cards[index], index),
                          ),
                        ),
                    ],
                  );
                }
                if (fitsStacked) {
                  return Column(
                    children: <Widget>[
                      for (int index = 0; index < cards.length; index++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: index == 0 ? 0 : AppSpacing.md,
                            ),
                            child: _buildCard(
                              cards[index],
                              index,
                              stacked: true,
                            ),
                          ),
                        ),
                    ],
                  );
                }
                // 세로로도 자리가 모자란 아주 작은 화면. 이때만 굴립니다.
                // 카드 높이를 화면의 절반보다 조금 작게 잡아 **다음 카드가
                // 반쯤 보이게** 합니다 - 굴려야 나오는 카드는 아이에게 없는
                // 카드라, 더 있다는 신호가 화면에 남아 있어야 합니다.
                final double peekHeight =
                    ((constraints.maxHeight - AppSpacing.md * 2) / 2.5).clamp(
                      110,
                      _minStackedCardHeight,
                    );
                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: cards.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (BuildContext context, int index) => SizedBox(
                    height: peekHeight,
                    child: _buildCard(cards[index], index, stacked: true),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    SttChoiceSentence sentence,
    int index, {
    bool stacked = false,
  }) {
    return _ChoiceCard(
      sentence: sentence,
      order: index + 1,
      playing: playingCardId == sentence.id,
      locked: submitting,
      stacked: stacked,
      compact: compact,
      onChoose: () => onChoose(sentence),
      onListen: () => onListen(sentence),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.sentence,
    required this.order,
    required this.playing,
    required this.locked,
    required this.stacked,
    required this.compact,
    required this.onChoose,
    required this.onListen,
  });

  final SttChoiceSentence sentence;
  final int order;
  final bool playing;
  final bool locked;
  final bool stacked;
  final bool compact;
  final VoidCallback onChoose;
  final VoidCallback onListen;

  /// 길면 한 단계씩 줄입니다. 자르지 않습니다 - 반만 읽고 고르면 아이는
  /// 자기가 무슨 말을 했는지 모릅니다. 그래도 넘치면 카드 안에서 굴립니다.
  double get _fontSize {
    final int length = sentence.text.characters.length;
    if (compact) return length > 34 ? 19 : 21;
    if (stacked) return length > 34 ? 21 : 23;
    return length > 34 ? 20 : 23;
  }

  @override
  Widget build(BuildContext context) {
    return PressScale(
      borderRadius: AppRadius.lg,
      onTap: locked ? null : onChoose,
      semanticLabel: '$order번째 문장, 이 말 하기. ${sentence.text}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints(minHeight: stacked ? 110 : 168),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: playing ? const Color(0xFFEFF9F4) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: playing ? const Color(0xFF4EA883) : const Color(0xFFCADFEC),
            width: playing ? 3 : 2,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x22102B48),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: stacked ? _buildStacked() : _buildColumn(),
      ),
    );
  }

  /// 가로로 나눠 놓았을 때(태블릿 가로). 문장이 위, 버튼이 아래입니다.
  Widget _buildColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(child: _sentenceText()),
        const SizedBox(height: AppSpacing.md),
        // 카드가 좁아지면 두 줄로 접힙니다. 한 줄에 밀어 넣으면 듣기 버튼이
        // 최소 터치 크기(64) 밑으로 눌립니다.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            _ListenButton(playing: playing, onTap: locked ? null : onListen),
            // 카드를 누르면 이 말을 한다는 것을 글로도 알려 줍니다 - 저학년은
            // "카드를 누르면 골라진다"는 관습을 아직 모릅니다.
            const _ChooseHint(),
          ],
        ),
      ],
    );
  }

  /// 위아래로 쌓았을 때(세로 화면). 문장 옆에 듣기 버튼을 두어 카드 한 장의
  /// 높이를 낮춥니다 - 그래야 세 장이 한 화면에 들어옵니다.
  Widget _buildStacked() {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(child: _sentenceText()),
              const SizedBox(height: AppSpacing.sm),
              const _ChooseHint(),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        _ListenButton(playing: playing, onTap: locked ? null : onListen),
      ],
    );
  }

  /// 자르지 않습니다 - 넘치면 카드 안에서 굴립니다.
  Widget _sentenceText() {
    return SingleChildScrollView(
      child: Text(
        sentence.text,
        style: TextStyle(
          color: const Color(0xFF172A3E),
          fontSize: _fontSize,
          height: 1.35,
          fontWeight: FontWeight.w900,
          letterSpacing: -.4,
        ),
      ),
    );
  }
}

/// 카드 문장을 소리로 들려주는 버튼. 초1~3 은 읽기가 느려서, 소리가 없으면
/// 고르기가 또 하나의 시험이 됩니다.
class _ListenButton extends StatelessWidget {
  const _ListenButton({required this.playing, required this.onTap});

  final bool playing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: playing ? '듣는 중' : '들어 보기',
      child: PressScale(
        borderRadius: AppRadius.pill,
        onTap: onTap,
        semanticLabel: playing ? '문장 듣는 중' : '문장 들어 보기',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: AppSizes.tapChildSecondary,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: playing ? const Color(0xFF4EA883) : const Color(0xFFE4F3EC),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                playing ? AppIcons.speaking : AppIcons.soundOn,
                size: 28,
                color: playing ? Colors.white : const Color(0xFF1D6E56),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '듣기',
                style: TextStyle(
                  color: playing ? Colors.white : const Color(0xFF1D6E56),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChooseHint extends StatelessWidget {
  const _ChooseHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1CC),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(AppIcons.check, size: 22, color: Color(0xFF8A5A16)),
          SizedBox(width: AppSpacing.xs),
          Text(
            '이 말 하기',
            style: TextStyle(
              color: Color(0xFF8A5A16),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
