/// 캐릭터 무대 · 말풍선 · 마이크를 한 화면에 놓는 대화 판.
///
/// 학습 대화(`play_view.dart`)와 후속 자유 대화(`free_talk_view.dart`)가
/// **같은 판을 씁니다.** 아이 눈에는 같은 친구와 같은 자리에서 말하는
/// 일이라, 화면이 갈리면 두 가지 규칙을 새로 배워야 합니다.
///
/// 자유 대화는 학습이 아니므로 진행바·장면 표시·요소 표시를 쓰지 않습니다.
/// 그 셋은 이 판이 아니라 **부르는 화면**이 그립니다 — 그래서 여기를 그대로
/// 재사용해도 학습용 표시가 따라오지 않습니다.
///
/// 원래 `play_view.dart` 안의 private 위젯이었습니다. 옮기면서 이름만
/// 공개형으로 바꿨고 **레이아웃·색·간격은 한 줄도 손대지 않았습니다**
/// (골든 테스트 `play_dialogue_template.png` 가 그것을 지킵니다).
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../domain/entities/play_session.dart';
import '../character/dialogue_character_stage.dart';
import '../character/dialogue_character_state_machine.dart';

enum DialoguePhase { characterSpeaking, listening, paused }

class DialogueCanvas extends StatelessWidget {
  const DialogueCanvas({
    super.key,
    required this.character,
    required this.activity,
    required this.characterAsset,
    required this.characterName,
    required this.question,
    required this.phase,
    required this.listeningSeconds,
    required this.recording,
    required this.transcribing,
    required this.compact,
    required this.onMicTap,
    required this.submitting,
    required this.lastChildText,
    required this.lastSttLowConfidence,
    this.guideSpeaking = false,
    this.micNeedsTap = false,
    this.sttHint,
    this.choicePanel,
    this.pendingTranscription,
    this.onConfirmTranscription,
    this.onRetryTranscription,
    this.onWordTap,
    this.pendingWord,
    this.savingWord = false,
    this.wordNotice,
    this.onConfirmWord,
    this.onCancelWord,
  });

  /// 제작한 표정 에셋이 있는 장면에서만 값이 있다. null이면 [characterAsset] 한 장으로 그린다.
  final DialogueCharacterStateMachine? character;
  final DialogueActivity activity;
  final String? characterAsset;
  final String characterName;
  final String question;
  final DialoguePhase phase;
  final int listeningSeconds;
  final bool recording;
  final bool transcribing;
  final bool compact;
  final VoidCallback? onMicTap;

  /// 캐릭터가 다시 물어보는 안내 음성이 나오는 중. 이때 마이크는 "준비됨"이
  /// 아니라 "듣는 중" 모양이어야 한다 - 눌러도 안 되는 버튼이 켜져 보이면
  /// 아이는 고장 났다고 여긴다.
  final bool guideSpeaking;

  /// 마이크가 저절로 켜지지 않고 아이가 눌러 줘야 하는 상태(못 알아들어서 다시
  /// 말해야 할 때·선택지가 떠 있을 때). 턴을 새로 시작할 때는 화면이 알아서
  /// 녹음을 켜지만, 다시 말하는 자리에서는 안내 음성 꼬리가 녹음되지 않도록
  /// 아이가 직접 누르게 두기 때문이다.
  final bool micNeedsTap;

  /// 아이의 확인을 기다리는 변환 결과. 값이 있으면 말풍선이 확인 화면으로 바뀐다.
  final PlayTranscription? pendingTranscription;
  final VoidCallback? onConfirmTranscription;
  final VoidCallback? onRetryTranscription;

  final bool submitting;
  final String? lastChildText;
  final bool lastSttLowConfidence;

  /// 무음/인식 실패로 다시 말해야 할 때만 값이 있다. [lastSttLowConfidence]
  /// 와 달리 화면을 안 바꾸고 마이크 옆에만 짧게 띄운다.
  final String? sttHint;

  /// 세 번 이어서 못 알아들었을 때만 값이 있다. 캐릭터 말풍선 자리를 대신
  /// 쓰고, 아이 말풍선(마이크)은 제자리에 그대로 둔다.
  final Widget? choicePanel;

  /// 고정 대사일 때만 값이 있다. null 이면 말풍선은 지금처럼 통짜 글로
  /// 그려지고 단어를 누를 수 없다(동적 대사).
  final void Function(String token)? onWordTap;
  final String? pendingWord;
  final bool savingWord;
  final String? wordNotice;
  final VoidCallback? onConfirmWord;
  final VoidCallback? onCancelWord;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // 제작 캐릭터는 정면 전신이고 표정이 전부다. 말풍선이 얼굴을 가리면 이 화면의 의미가
        // 없어지므로 인물은 왼쪽에 세우고 말풍선은 오른쪽으로 몰아 둔다.
        final bool hasStage = character != null;
        final double stageWidth = constraints.maxWidth * (compact ? .56 : .40);

        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            if (hasStage)
              Positioned(
                left: compact ? -constraints.maxWidth * .06 : 8,
                width: stageWidth,
                top: compact ? 120 : 4,
                bottom: 0,
                child: DialogueCharacterStage(
                  scene: character!.scene,
                  state: character!.current,
                  activity: activity,
                ),
              )
            else if (characterAsset != null && !compact)
              Positioned(
                left: 18,
                top: 30,
                bottom: 0,
                width: constraints.maxWidth * .29,
                child: Semantics(
                  image: true,
                  label: '$characterName 캐릭터',
                  child: Image.asset(
                    characterAsset!,
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomLeft,
                  ),
                ),
              ),
            Positioned(
              left: compact
                  ? 10
                  : (hasStage ? stageWidth + 24 : constraints.maxWidth * .23),
              right: compact ? 10 : 20,
              top: compact ? 18 : 44,
              // 선택지 판은 아이 말풍선 바로 위까지 내려와 카드 3장을 크게
              // 폅니다. 말풍선은 내용만큼만 차지하므로 bottom 을 주지 않습니다.
              bottom: choicePanel == null ? null : (compact ? 154.0 : 190.0),
              child:
                  choicePanel ??
                  _QuestionBubble(
                    characterName: characterName,
                    question: question,
                    compact: compact,
                    onWordTap: onWordTap,
                    pendingWord: pendingWord,
                    savingWord: savingWord,
                    wordNotice: wordNotice,
                    onConfirmWord: onConfirmWord,
                    onCancelWord: onCancelWord,
                    // 아이 말풍선(아래)과 서로 밀어내지 않도록 위아래로 나눠
                    // 씁니다. 좁은 폭에서 대사가 길어져도 잘리는 대신 이 안에서
                    // 굴러갑니다.
                    maxHeight:
                        constraints.maxHeight -
                        (compact ? 18 : 44) -
                        (compact ? 160 : 190),
                  ),
            ),
            // 이름 배지는 인물 발밑에 겹치고, 말풍선이 이미 "○○의 질문"으로 화자를 밝힌다.
            if (!compact && !hasStage)
              Positioned(
                left: 20,
                bottom: 22,
                child: _CharacterNameBadge(name: characterName),
              ),
            Positioned(
              right: compact ? 10 : 0,
              bottom: compact ? 10 : 20,
              width: compact
                  ? constraints.maxWidth - 20
                  : constraints.maxWidth * .52,
              child: _ChildVoiceBubble(
                phase: phase,
                seconds: listeningSeconds,
                recording: recording,
                transcribing: transcribing,
                submitting: submitting,
                guideSpeaking: guideSpeaking,
                micNeedsTap: micNeedsTap,
                onMicTap: onMicTap,
                lastChildText: lastChildText,
                lowConfidence: lastSttLowConfidence,
                sttHint: sttHint,
                compact: compact,
                pending: pendingTranscription,
                onConfirm: onConfirmTranscription,
                onRetry: onRetryTranscription,
                maxHeight: constraints.maxHeight * (compact ? .42 : .5),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CharacterNameBadge extends StatelessWidget {
  const _CharacterNameBadge({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xDD173A5D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white70),
      ),
      child: Text(
        name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// 캐릭터 대사 말풍선.
///
/// **대사는 어떤 폭에서도 잘리지 않습니다.** 아이가 글을 다 못 읽는 채로
/// 대답해야 하는 상황을 만들면 이 화면이 성립하지 않습니다. 그래서 문장이
/// 길면 (1) 글자를 한 단계씩 줄이고, (2) 그래도 넘치면 말풍선 안에서
/// 스크롤합니다 - 말줄임표로 끊지 않습니다.
class _QuestionBubble extends StatelessWidget {
  const _QuestionBubble({
    required this.characterName,
    required this.question,
    required this.compact,
    required this.maxHeight,
    this.onWordTap,
    this.pendingWord,
    this.savingWord = false,
    this.wordNotice,
    this.onConfirmWord,
    this.onCancelWord,
  });

  /// 말풍선이 차지해도 되는 최대 높이. 아이 말풍선을 밀어내지 않도록
  /// [DialogueCanvas] 가 화면 높이에서 계산해 넘깁니다.
  final double maxHeight;

  TextStyle get _questionStyle => TextStyle(
    color: const Color(0xFF172A3E),
    fontSize: _fontSize,
    height: 1.35,
    fontWeight: FontWeight.w900,
    letterSpacing: -.5,
  );

  /// 길이에 따라 한 단계씩 줄어드는 글자 크기. 자르는 대신 줄입니다.
  double get _fontSize {
    final int length = question.characters.length;
    if (compact) return length > 90 ? 21 : (length > 55 ? 24 : 27);
    return length > 90 ? 27 : (length > 55 ? 30 : 34);
  }

  final String characterName;
  final String question;
  final bool compact;

  /// 값이 있으면 대사가 단어 단위로 눌리는 고정 대사다. → [_TappableDialogue]
  final void Function(String token)? onWordTap;
  final String? pendingWord;
  final bool savingWord;
  final String? wordNotice;
  final VoidCallback? onConfirmWord;
  final VoidCallback? onCancelWord;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: -17,
          top: 62,
          child: Transform.rotate(
            angle: .78,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF3),
                border: Border.all(color: const Color(0xFFFFD66B), width: 2),
              ),
            ),
          ),
        ),
        Container(
          constraints: BoxConstraints(
            minHeight: compact ? 138 : 176,
            maxHeight: max(maxHeight, compact ? 138.0 : 176.0),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 22 : 34,
            vertical: compact ? 19 : 25,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF3),
            borderRadius: BorderRadius.circular(compact ? 24 : 32),
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
            mainAxisAlignment: MainAxisAlignment.center,
            // 최대 높이가 생겼으니 min 이어야 합니다 - 기본값(max)이면 대사가
            // 짧아도 말풍선이 허용 높이까지 늘어납니다.
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF4EA883),
                    size: 25,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    '$characterName의 질문',
                    style: const TextStyle(
                      color: Color(0xFF496179),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 자르지 않습니다 - 줄이고, 그래도 넘치면 말풍선 안에서 굴립니다.
              Flexible(
                child: SingleChildScrollView(
                  child: Semantics(
                    liveRegion: true,
                    label: question,
                    child: onWordTap == null
                        ? Text(question, style: _questionStyle)
                        : _TappableDialogue(
                            text: question,
                            style: _questionStyle,
                            selectedWord: pendingWord,
                            onWordTap: onWordTap!,
                          ),
                  ),
                ),
              ),
              if (pendingWord != null) ...<Widget>[
                const SizedBox(height: 12),
                _WordSaveBar(
                  word: pendingWord!,
                  saving: savingWord,
                  compact: compact,
                  onSave: onConfirmWord,
                  onCancel: onCancelWord,
                ),
              ] else if (wordNotice != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  wordNotice!,
                  style: const TextStyle(
                    color: Color(0xFF4EA883),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 고정 대사를 단어 단위로 눌리게 그린다.
///
/// RichText + TapGestureRecognizer 대신 Wrap을 쓴다 - recognizer는 dispose
/// 관리가 필요해 StatefulWidget이 되고, Wrap이면 토큰마다 위젯이라 테스트에서
/// find.text('단어')로 바로 잡힌다. 줄바꿈은 어차피 공백 단위라 결과가 같다.
class _TappableDialogue extends StatelessWidget {
  const _TappableDialogue({
    required this.text,
    required this.style,
    required this.onWordTap,
    this.selectedWord,
  });

  final String text;
  final TextStyle style;
  final void Function(String token) onWordTap;
  final String? selectedWord;

  @override
  Widget build(BuildContext context) {
    final List<String> tokens = text
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty)
        .toList(growable: false);
    return Wrap(
      spacing: (style.fontSize ?? 27) * .26,
      runSpacing: 6,
      children: <Widget>[
        for (final String token in tokens)
          GestureDetector(
            onTap: () => onWordTap(token),
            behavior: HitTestBehavior.opaque,
            child: Text(
              token,
              style: _isSelected(token)
                  ? style.copyWith(
                      color: const Color(0xFF1C6BC8),
                      decoration: TextDecoration.underline,
                      decorationColor: const Color(0xFF1C6BC8),
                      decorationThickness: 2.5,
                    )
                  : style,
            ),
          ),
      ],
    );
  }

  /// 구두점을 걷어낸 뒤 비교한다 - "기왓장이" 토큰을 눌러 "기왓장이"가
  /// 선택돼도, 토큰 끝 물음표 등으로 어긋나지 않게.
  bool _isSelected(String token) {
    final String? selected = selectedWord;
    if (selected == null) return false;
    return token == selected || token.startsWith(selected);
  }
}

/// "이 단어를 담을까요?" 확인 줄. 시험이 아니라 담기이므로 버튼은 둘뿐이고
/// 어느 쪽을 골라도 이야기는 그대로 이어진다.
class _WordSaveBar extends StatelessWidget {
  const _WordSaveBar({
    required this.word,
    required this.saving,
    required this.compact,
    required this.onSave,
    required this.onCancel,
  });

  final String word;
  final bool saving;
  final bool compact;
  final VoidCallback? onSave;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF9CC4EE), width: 2),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              "'$word' 단어장에 담을까요?",
              style: const TextStyle(
                color: Color(0xFF1C4F86),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _WordSaveButton(
            label: saving ? '담는 중...' : '담기',
            emphasized: true,
            onTap: saving ? null : onSave,
          ),
          const SizedBox(width: 8),
          _WordSaveButton(
            label: '그냥 둘게요',
            emphasized: false,
            onTap: saving ? null : onCancel,
          ),
        ],
      ),
    );
  }
}

class _WordSaveButton extends StatelessWidget {
  const _WordSaveButton({
    required this.label,
    required this.emphasized,
    required this.onTap,
  });

  final String label;
  final bool emphasized;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // 초등 저학년 손가락 기준 최소 44 - 텍스트가 작아도 판은 크게.
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: emphasized ? const Color(0xFF2E7CD6) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: emphasized
              ? null
              : Border.all(color: const Color(0xFF9CC4EE), width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: emphasized ? Colors.white : const Color(0xFF1C4F86),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ChildVoiceBubble extends StatelessWidget {
  const _ChildVoiceBubble({
    required this.phase,
    required this.seconds,
    required this.recording,
    required this.transcribing,
    required this.submitting,
    required this.onMicTap,
    required this.lastChildText,
    required this.lowConfidence,
    required this.compact,
    required this.maxHeight,
    this.guideSpeaking = false,
    this.micNeedsTap = false,
    this.sttHint,
    this.pending,
    this.onConfirm,
    this.onRetry,
  });

  /// 말풍선이 차지해도 되는 최대 높이. 아이가 길게 말했어도 잘라내지 않고
  /// 이 안에서 굴립니다. → [_QuestionBubble]
  final double maxHeight;

  final DialoguePhase phase;
  final int seconds;
  final bool recording;
  final bool transcribing;
  final bool submitting;
  final VoidCallback? onMicTap;
  final String? lastChildText;
  final bool lowConfidence;
  final bool compact;

  /// 캐릭터가 다시 물어보는 중. 마이크는 잠겨 있다. → [DialogueCanvas]
  final bool guideSpeaking;

  /// 마이크를 아이가 눌러 줘야 하는 자리. → [DialogueCanvas.micNeedsTap]
  final bool micNeedsTap;

  final String? sttHint;

  /// 아이의 확인을 기다리는 변환 결과. 값이 있으면 확인 화면을 그린다.
  final PlayTranscription? pending;
  final VoidCallback? onConfirm;
  final VoidCallback? onRetry;

  bool get listening => phase == DialoguePhase.listening;

  /// 안내 음성이 나오는 동안에는 "말할 차례"가 아니다. 마이크를 켜진 모양으로
  /// 두면 눌렀다가 아무 일도 안 일어난다.
  bool get micReady => listening && !guideSpeaking;

  @override
  Widget build(BuildContext context) {
    if (pending != null) return _buildConfirmView();
    final String status = transcribing
        ? '목소리를 글로 바꾸고 있어요'
        : submitting
        ? '이야기 친구가 답을 준비하고 있어요'
        : recording
        ? '잘 듣고 있어요 · $seconds초'
        : guideSpeaking
        ? '이야기 친구가 다시 물어보고 있어요'
        : listening
        // 다시 말하는 자리에서는 마이크가 저절로 켜지지 않는다. "이제 말할
        // 차례예요"라고 두면 아이가 누르지 않고 기다린다.
        ? (micNeedsTap ? '다시 말할 수 있어요' : '이제 말할 차례예요')
        : '질문을 듣고 있어요';
    final String body = lastChildText?.trim().isNotEmpty == true
        ? lastChildText!.trim()
        : recording
        ? '나는 이렇게 생각해요…'
        : transcribing
        ? '말한 내용을 잠깐 확인하고 있어요.'
        : guideSpeaking
        ? '친구 말이 끝나면 말할 수 있어요.'
        : listening
        ? (micNeedsTap ? '마이크를 누르고 말해 주세요.' : '마이크가 자동으로 켜졌어요.')
        : '질문이 끝나면 마이크가 켜져요.';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      constraints: BoxConstraints(
        minHeight: compact ? 128 : 154,
        maxHeight: max(maxHeight, compact ? 128.0 : 154.0),
      ),
      padding: EdgeInsets.all(compact ? 15 : 20),
      decoration: BoxDecoration(
        color: const Color(0xF2123252),
        borderRadius: BorderRadius.circular(compact ? 22 : 28),
        border: Border.all(
          color: listening ? const Color(0xFF77E0C4) : Colors.white38,
          width: listening ? 3 : 1.5,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          DialogueMicButton(
            ready: micReady,
            recording: recording,
            busy: transcribing || submitting,
            onTap: onMicTap,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: lastChildText == null ? status : '내가 한 말: $lastChildText',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    status,
                    style: const TextStyle(
                      color: Color(0xFF8DE7CF),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 9),
                  // 아이가 한 말도 자르지 않습니다 - 자기가 한 말이 반쯤
                  // 잘려 보이면 다시 말해야 하는지 알 수 없습니다.
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(
                        body,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 20 : 23,
                          height: 1.35,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  if (sttHint != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      sttHint!,
                      style: const TextStyle(
                        color: Color(0xFFFFD56A),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ] else if (lowConfidence &&
                      lastChildText != null) ...<Widget>[
                    const SizedBox(height: 6),
                    const Text(
                      '잘 들었는지 한 번 더 확인해 주세요.',
                      style: TextStyle(
                        color: Color(0xFFFFD56A),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 변환 결과 확인 화면. "맞아요"를 눌러야 턴이 제출된다.
  ///
  /// 글을 못 읽는 아이도 있으므로 문구에만 기대지 않는다 - 버튼을 크게 두 개만
  /// 두고 색과 아이콘(체크/새로고침)으로 "보내기"와 "다시 말하기"를 구분한다.
  /// 저신뢰면 테두리와 제목을 노란색 계열로 바꿔 "확실하지 않다"는 신호를 준다.
  ///
  /// 아이가 한 말은 자르지 않는다. 길게 말했으면 [maxHeight] 안에서 굴리고,
  /// 버튼 두 개는 어떤 경우에도 화면에 남는다 - 잘린 말과 사라진 버튼은
  /// 아이에게 "여기서 뭘 해야 하는지"를 통째로 숨긴다.
  Widget _buildConfirmView() {
    final PlayTranscription result = pending!;
    final Color accent = result.lowConfidence
        ? const Color(0xFFFFD56A)
        : const Color(0xFF77E0C4);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      constraints: BoxConstraints(
        minHeight: compact ? 128 : 154,
        maxHeight: maxHeight,
      ),
      padding: EdgeInsets.all(compact ? 15 : 20),
      decoration: BoxDecoration(
        color: const Color(0xF2123252),
        borderRadius: BorderRadius.circular(compact ? 22 : 28),
        border: Border.all(color: accent, width: 3),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Semantics(
        liveRegion: true,
        label: '이렇게 들었어요: ${result.text}. 맞으면 맞아요를 누르세요.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              result.lowConfidence ? '이렇게 들었는데, 맞을까요?' : '이렇게 들었어요',
              style: TextStyle(
                color: accent,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  result.text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 20 : 23,
                    height: 1.35,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (result.lowConfidence) ...<Widget>[
              const SizedBox(height: 6),
              const Text(
                '잘 못 알아들었을 수도 있어요.',
                style: TextStyle(
                  color: Color(0xFFFFD56A),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            SizedBox(height: compact ? 12 : 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: SizedBox(
                    height: compact ? 48 : 54,
                    child: FilledButton.icon(
                      onPressed: submitting ? null : onConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF72D6B7),
                        foregroundColor: const Color(0xFF10314A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 26),
                      label: const Text(
                        '맞아요',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: compact ? 48 : 54,
                    child: OutlinedButton.icon(
                      onPressed: submitting ? null : onRetry,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFFD56A),
                        side: const BorderSide(
                          color: Color(0xFFFFD56A),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 26),
                      label: const Text(
                        '다시 말할래요',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DialogueMicButton extends StatelessWidget {
  const DialogueMicButton({
    super.key,
    required this.ready,
    required this.recording,
    required this.busy,
    required this.onTap,
  });

  final bool ready;
  final bool recording;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: recording
          ? '마이크 켜짐'
          : ready
          ? '마이크 준비됨'
          : '마이크 준비 중',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: recording
              ? const Color(0xFFFF7B68)
              : ready
              ? const Color(0xFF77E0C4)
              : const Color(0xFF6D8094),
          shape: BoxShape.circle,
          boxShadow: recording
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x88FF7B68),
                    blurRadius: 18,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: IconButton(
          tooltip: recording
              ? '말하기 완료'
              : ready
              ? '눌러서 말하기'
              : '질문을 듣는 중이에요',
          onPressed: busy ? null : onTap,
          icon: busy
              ? const CircularProgressIndicator(strokeWidth: 3)
              : Icon(recording ? Icons.stop_rounded : AppIcons.speak),
          iconSize: 44,
          color: const Color(0xFF123252),
        ),
      ),
    );
  }
}

/// 대화 화면 상단의 동그란 조작 버튼(나가기 · 다시 듣기 · 소리 · 멈춤).
///
/// 학습 대화와 자유 대화가 같은 자리에 같은 모양의 버튼을 둡니다 — 아이가
/// 화면마다 다른 버튼을 새로 익히지 않게. 무엇을 놓을지는 화면이 정합니다.
class DialogueControlButton extends StatelessWidget {
  const DialogueControlButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: emphasized ? const Color(0xFFFFD56A) : const Color(0xCC102B48),
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              icon,
              size: 28,
              color: emphasized ? const Color(0xFF17314A) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
