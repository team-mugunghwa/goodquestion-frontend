import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';

/// 말하기 후 활동에서 사용하는 장면 카드 데이터입니다.
///
/// 이야기마다 [title], [visual], [accent]만 교체하면 같은 UI를 재사용합니다.
class RecapSceneCard {
  const RecapSceneCard({
    required this.id,
    required this.title,
    required this.visual,
    required this.accent,
  });

  final String id;
  final String title;
  final IconData visual;
  final Color accent;
}

/// 이야기 종료 후 `순서 맞추기 → 다시 말하기 → 저장 완료`를 진행하는 공통 화면입니다.
class PlayRecapPage extends StatefulWidget {
  const PlayRecapPage({
    required this.sessionId,
    this.storyTitle = '오늘의 이야기',
    this.sceneCards = _defaultCards,
    this.keywords = _defaultKeywords,
    super.key,
  });

  final String sessionId;
  final String storyTitle;
  final List<RecapSceneCard> sceneCards;
  final List<String> keywords;

  static const List<RecapSceneCard> _defaultCards = <RecapSceneCard>[
    RecapSceneCard(
      id: 'scene-1',
      title: '주인공에게 고민이 생겼어요',
      visual: Icons.sentiment_dissatisfied_rounded,
      accent: Color(0xFF8CC8E8),
    ),
    RecapSceneCard(
      id: 'scene-2',
      title: '친구에게 솔직하게 말했어요',
      visual: Icons.forum_rounded,
      accent: Color(0xFFFFC978),
    ),
    RecapSceneCard(
      id: 'scene-3',
      title: '함께 새로운 방법을 찾았어요',
      visual: Icons.lightbulb_rounded,
      accent: Color(0xFFA9D89D),
    ),
    RecapSceneCard(
      id: 'scene-4',
      title: '모두 웃으며 이야기가 끝났어요',
      visual: Icons.celebration_rounded,
      accent: Color(0xFFD1AFE8),
    ),
  ];

  static const List<String> _defaultKeywords = <String>[
    '고민',
    '솔직하게',
    '함께',
    '해결',
  ];

  @override
  State<PlayRecapPage> createState() => _PlayRecapPageState();
}

enum _RecapStep { arrange, retell, completed }

class _PlayRecapPageState extends State<PlayRecapPage> {
  late List<RecapSceneCard> _cards;
  _RecapStep _step = _RecapStep.arrange;
  int? _selectedIndex;
  bool _showRetryHint = false;
  bool _isListening = false;
  bool _isSaving = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  static const String _demoTranscript =
      '처음에는 주인공에게 고민이 생겼어요. 친구에게 솔직하게 말한 뒤, 함께 좋은 해결 방법을 찾았어요.';

  @override
  void initState() {
    super.initState();
    final List<RecapSceneCard> source = List<RecapSceneCard>.of(
      widget.sceneCards,
    );
    _cards = source.length >= 4
        ? <RecapSceneCard>[
            source[2],
            source[0],
            source[3],
            source[1],
            ...source.skip(4),
          ]
        : source.reversed.toList();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    super.dispose();
  }

  bool get _isCorrect {
    if (_cards.length != widget.sceneCards.length) return false;
    for (int i = 0; i < _cards.length; i++) {
      if (_cards[i].id != widget.sceneCards[i].id) return false;
    }
    return true;
  }

  void _moveSelected(int delta) {
    final int? current = _selectedIndex;
    if (current == null) return;
    final int next = current + delta;
    if (next < 0 || next >= _cards.length) return;
    setState(() {
      final RecapSceneCard card = _cards.removeAt(current);
      _cards.insert(next, card);
      _selectedIndex = next;
      _showRetryHint = false;
    });
  }

  void _checkOrder() {
    if (!_isCorrect) {
      setState(() => _showRetryHint = true);
      return;
    }
    setState(() {
      _step = _RecapStep.retell;
      _selectedIndex = null;
      _showRetryHint = false;
    });
    Timer(const Duration(milliseconds: 700), _startListening);
  }

  void _startListening() {
    if (!mounted || _step != _RecapStep.retell) return;
    setState(() {
      _isListening = true;
      _recordingSeconds = 0;
    });
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isListening) setState(() => _recordingSeconds++);
    });
  }

  void _stopListening() {
    _recordingTimer?.cancel();
    setState(() => _isListening = false);
  }

  Future<void> _completeActivity() async {
    _stopListening();
    setState(() => _isSaving = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _step = _RecapStep.completed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8F7),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compact = constraints.maxWidth < 780;
            return Column(
              children: <Widget>[
                _RecapTopBar(
                  title: widget.storyTitle,
                  step: _step,
                  onExit: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: switch (_step) {
                      _RecapStep.arrange => _ArrangeStep(
                        key: const ValueKey<String>('arrange'),
                        cards: _cards,
                        selectedIndex: _selectedIndex,
                        showRetryHint: _showRetryHint,
                        compact: compact,
                        onSelected: (int index) => setState(() {
                          _selectedIndex = _selectedIndex == index
                              ? null
                              : index;
                          _showRetryHint = false;
                        }),
                        onReorder: (int oldIndex, int newIndex) {
                          setState(() {
                            final RecapSceneCard card = _cards.removeAt(
                              oldIndex,
                            );
                            _cards.insert(newIndex, card);
                            _selectedIndex = newIndex;
                            _showRetryHint = false;
                          });
                        },
                        onMoveLeft: () => _moveSelected(-1),
                        onMoveRight: () => _moveSelected(1),
                        onCheck: _checkOrder,
                      ),
                      _RecapStep.retell => _RetellStep(
                        key: const ValueKey<String>('retell'),
                        cards: widget.sceneCards,
                        keywords: widget.keywords,
                        isListening: _isListening,
                        seconds: _recordingSeconds,
                        isSaving: _isSaving,
                        compact: compact,
                        transcript: _isListening || _recordingSeconds > 0
                            ? _demoTranscript
                            : null,
                        onMic: _isListening ? _stopListening : _startListening,
                        onComplete: _completeActivity,
                      ),
                      _RecapStep.completed => _CompletionStep(
                        key: const ValueKey<String>('completed'),
                        onDone: () => Navigator.of(context).maybePop(),
                      ),
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RecapTopBar extends StatelessWidget {
  const _RecapTopBar({
    required this.title,
    required this.step,
    required this.onExit,
  });

  final String title;
  final _RecapStep step;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final int progress = step == _RecapStep.arrange ? 1 : 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      child: Row(
        children: <Widget>[
          IconButton.filledTonal(
            tooltip: '활동 나가기',
            onPressed: onExit,
            icon: const Icon(AppIcons.close),
            style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF294662),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress / 2,
                    minHeight: 9,
                    color: const Color(0xFF53AE91),
                    backgroundColor: const Color(0xFFD6E8E5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0xFFC9DFDA)),
            ),
            child: Text(
              step == _RecapStep.completed ? '완료!' : '$progress / 2 단계',
              style: const TextStyle(
                color: Color(0xFF357963),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrangeStep extends StatelessWidget {
  const _ArrangeStep({
    required this.cards,
    required this.selectedIndex,
    required this.showRetryHint,
    required this.compact,
    required this.onSelected,
    required this.onReorder,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onCheck,
    super.key,
  });

  final List<RecapSceneCard> cards;
  final int? selectedIndex;
  final bool showRetryHint;
  final bool compact;
  final ValueChanged<int> onSelected;
  final ReorderCallback onReorder;
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 14 : 28, 8, compact ? 14 : 28, 20),
      child: Column(
        children: <Widget>[
          const _InstructionHeader(
            eyebrow: '첫 번째 활동',
            title: '장면을 이야기 순서대로 놓아 보세요',
            description: '카드를 길게 눌러 끌거나, 카드를 고른 뒤 화살표를 눌러도 돼요.',
            icon: Icons.view_carousel_rounded,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              onReorderItem: onReorder,
              proxyDecorator:
                  (Widget child, int index, Animation<double> animation) =>
                      Material(
                        color: Colors.transparent,
                        elevation: 12,
                        borderRadius: BorderRadius.circular(26),
                        child: child,
                      ),
              itemCount: cards.length,
              itemBuilder: (BuildContext context, int index) {
                return SizedBox(
                  key: ValueKey<String>(cards[index].id),
                  width: compact ? 210 : 246,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: _SceneCard(
                      card: cards[index],
                      index: index,
                      order: index + 1,
                      selected: selectedIndex == index,
                      onTap: () => onSelected(index),
                    ),
                  ),
                );
              },
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: selectedIndex == null
                ? const SizedBox(height: 58)
                : _MoveControls(
                    key: const ValueKey<String>('move-controls'),
                    canMoveLeft: selectedIndex! > 0,
                    canMoveRight: selectedIndex! < cards.length - 1,
                    onLeft: onMoveLeft,
                    onRight: onMoveRight,
                  ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: showRetryHint
                ? const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: _GentleHint(),
                  )
                : const SizedBox(height: 42),
          ),
          SizedBox(
            width: compact ? double.infinity : 340,
            height: 64,
            child: FilledButton.icon(
              onPressed: onCheck,
              icon: const Icon(Icons.check_circle_rounded, size: 28),
              label: const Text('이 순서로 확인하기'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF347F69),
                textStyle: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({
    required this.card,
    required this.index,
    required this.order,
    required this.selected,
    required this.onTap,
  });

  final RecapSceneCard card;
  final int index;
  final int order;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$order번째 카드, ${card.title}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        elevation: selected ? 9 : 2,
        shadowColor: const Color(0x553B6571),
        child: InkWell(
          key: ValueKey<String>('recap-card-${card.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: selected
                    ? const Color(0xFF347F69)
                    : const Color(0xFFD4E4E1),
                width: selected ? 4 : 2,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFF173B57),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$order',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const Spacer(),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Tooltip(
                        message: '길게 눌러 옮기기',
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: Color(0xFF7A929C),
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: card.accent.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      card.visual,
                      size: 76,
                      color: const Color(0xFF294E67),
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  card.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF20384E),
                    fontSize: 17,
                    height: 1.35,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoveControls extends StatelessWidget {
  const _MoveControls({
    required this.canMoveLeft,
    required this.canMoveRight,
    required this.onLeft,
    required this.onRight,
    super.key,
  });

  final bool canMoveLeft;
  final bool canMoveRight;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          IconButton.filledTonal(
            tooltip: '왼쪽으로 옮기기',
            onPressed: canMoveLeft ? onLeft : null,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              '선택한 카드 옮기기',
              style: TextStyle(
                color: Color(0xFF496579),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: '오른쪽으로 옮기기',
            onPressed: canMoveRight ? onRight : null,
            icon: const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }
}

class _GentleHint extends StatelessWidget {
  const _GentleHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2D9),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.lightbulb_rounded, color: Color(0xFF9A6618)),
          SizedBox(width: 8),
          Text(
            '거의 다 왔어요! 처음에 어떤 일이 있었는지 다시 살펴볼까요?',
            style: TextStyle(
              color: Color(0xFF795218),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RetellStep extends StatelessWidget {
  const _RetellStep({
    required this.cards,
    required this.keywords,
    required this.isListening,
    required this.seconds,
    required this.isSaving,
    required this.compact,
    required this.transcript,
    required this.onMic,
    required this.onComplete,
    super.key,
  });

  final List<RecapSceneCard> cards;
  final List<String> keywords;
  final bool isListening;
  final int seconds;
  final bool isSaving;
  final bool compact;
  final String? transcript;
  final VoidCallback onMic;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final Widget reference = _StoryReference(cards: cards, keywords: keywords);
    final Widget recorder = _RetellRecorder(
      isListening: isListening,
      seconds: seconds,
      isSaving: isSaving,
      transcript: transcript,
      onMic: onMic,
      onComplete: onComplete,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 14 : 28, 8, compact ? 14 : 28, 22),
      child: Column(
        children: <Widget>[
          const _InstructionHeader(
            eyebrow: '두 번째 활동',
            title: '장면과 낱말을 보며 이야기를 들려주세요',
            description: '정답처럼 똑같이 말하지 않아도 괜찮아요. 기억나는 대로 편하게 말해요.',
            icon: AppIcons.speak,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: compact
                ? ListView(
                    children: <Widget>[
                      reference,
                      const SizedBox(height: 14),
                      recorder,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(flex: 9, child: reference),
                      const SizedBox(width: 18),
                      Expanded(flex: 11, child: recorder),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _StoryReference extends StatelessWidget {
  const _StoryReference({required this.cards, required this.keywords});

  final List<RecapSceneCard> cards;
  final List<String> keywords;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFD4E5E1), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.auto_stories_rounded, color: Color(0xFF347F69)),
              SizedBox(width: 8),
              Text(
                '이야기 순서',
                style: TextStyle(
                  color: Color(0xFF294662),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              separatorBuilder: (_, __) => const Icon(
                Icons.arrow_forward_rounded,
                color: Color(0xFF80A295),
              ),
              itemBuilder: (BuildContext context, int index) => SizedBox(
                width: 112,
                child: Column(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: cards[index].accent.withValues(alpha: .4),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Icon(
                            cards[index].visual,
                            size: 46,
                            color: const Color(0xFF294E67),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Color(0xFF456579),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '꼭 써 볼 낱말',
            style: TextStyle(
              color: Color(0xFF294662),
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: keywords
                .take(4)
                .map(
                  (String word) => Chip(
                    avatar: const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFE6A828),
                      size: 19,
                    ),
                    label: Text(word),
                    backgroundColor: const Color(0xFFFFF4CE),
                    side: const BorderSide(color: Color(0xFFFFD56A)),
                    labelStyle: const TextStyle(
                      color: Color(0xFF6C5114),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _RetellRecorder extends StatelessWidget {
  const _RetellRecorder({
    required this.isListening,
    required this.seconds,
    required this.isSaving,
    required this.transcript,
    required this.onMic,
    required this.onComplete,
  });

  final bool isListening;
  final int seconds;
  final bool isSaving;
  final String? transcript;
  final VoidCallback onMic;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF173B57),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x44233F55),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                isListening ? AppIcons.speaking : AppIcons.speak,
                color: const Color(0xFF7DE1C3),
              ),
              const SizedBox(width: 9),
              Text(
                isListening ? '잘 듣고 있어요 · $seconds초' : '말하기 준비가 되었어요',
                style: const TextStyle(
                  color: Color(0xFF9BE7D2),
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: transcript == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.format_quote_rounded,
                          color: Color(0xFF8DB2C4),
                          size: 50,
                        ),
                        SizedBox(height: 10),
                        Text(
                          '말한 내용이 여기에 글자로 보여요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF547187),
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Text(
                        transcript!,
                        style: const TextStyle(
                          color: Color(0xFF20384E),
                          fontSize: 21,
                          height: 1.65,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              SizedBox(
                width: 82,
                height: 82,
                child: IconButton.filled(
                  tooltip: isListening ? '말하기 멈추기' : '다시 말하기',
                  onPressed: onMic,
                  icon: Icon(
                    isListening ? Icons.stop_rounded : AppIcons.speak,
                    size: 38,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: isListening
                        ? const Color(0xFFFFD56A)
                        : const Color(0xFF7DE1C3),
                    foregroundColor: const Color(0xFF173B57),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 64,
                  child: FilledButton.icon(
                    onPressed: transcript == null || isSaving
                        ? null
                        : onComplete,
                    icon: isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(isSaving ? '저장하고 있어요' : '이야기 다 했어요'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD56A),
                      foregroundColor: const Color(0xFF173B57),
                      disabledBackgroundColor: const Color(0xFF718597),
                      textStyle: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InstructionHeader extends StatelessWidget {
  const _InstructionHeader({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: Color(0xFFDDF2EA),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF347F69), size: 31),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                eyebrow,
                style: const TextStyle(
                  color: Color(0xFF43866F),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1E3A52),
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF587287),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompletionStep extends StatelessWidget {
  const _CompletionStep({required this.onDone, super.key});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x33305766), blurRadius: 30),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF1BD),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFE0A21F),
                size: 54,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '이야기를 멋지게 다시 들려줬어요!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF1E3A52),
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '장면 순서와 말한 내용을 안전하게 저장했어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF587287),
                fontSize: 17,
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                onPressed: onDone,
                icon: const Icon(Icons.home_rounded),
                label: const Text('활동 마치기'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF347F69),
                  textStyle: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
