import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';

/// 말하기 후 활동에서 사용하는 장면 카드 데이터입니다.
///
/// 이야기마다 [title], [image]만 교체하면 같은 UI를 재사용합니다.
class RecapSceneCard {
  const RecapSceneCard({
    required this.id,
    required this.title,
    required this.image,
  });

  final String id;

  /// 스크린리더 전용 설명입니다. **화면에는 절대 그리지 않습니다.**
  ///
  /// 이 활동은 그림만 보고 순서를 맞추는 활동이라, 제목을 화면에 띄우면
  /// 글을 읽을 수 있는 아이에게 정답이 그대로 새어 나갑니다.
  /// 대신 [Semantics.label]로만 넘겨서, 그림을 볼 수 없는 사용자도
  /// 같은 활동을 할 수 있게 합니다.
  final String title;

  /// 16:9 장면 그림의 에셋 경로입니다.
  final String image;
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

  /// **이야기 순서(정답 순서)대로** 넣어 주세요. 화면에서는 섞어서 보여 줍니다.
  final List<RecapSceneCard> sceneCards;
  final List<String> keywords;

  static const List<RecapSceneCard> _defaultCards = <RecapSceneCard>[
    RecapSceneCard(
      id: 'scene-1',
      title: '며느리가 방귀를 참느라 시무룩하게 서 있어요',
      image: 'assets/images/recap/banggui/scene_1.webp',
    ),
    RecapSceneCard(
      id: 'scene-2',
      title: '며느리의 방귀에 시아버지의 갓이 날아가 시아버지가 화를 냈어요',
      image: 'assets/images/recap/banggui/scene_2.webp',
    ),
    RecapSceneCard(
      id: 'scene-3',
      title: '며느리가 방귀로 배나무의 배를 우수수 떨어뜨렸어요',
      image: 'assets/images/recap/banggui/scene_3.webp',
    ),
    RecapSceneCard(
      id: 'scene-4',
      title: '마을 사람들이 배를 얻고 며느리에게 고마워했어요',
      image: 'assets/images/recap/banggui/scene_4.webp',
    ),
  ];

  static const List<String> _defaultKeywords = <String>[
    '참다',
    '쫓겨나다',
    '떨어뜨리다',
    '자신감',
  ];

  @override
  State<PlayRecapPage> createState() => _PlayRecapPageState();
}

enum _RecapStep { arrange, retell, completed }

/// 끌고 있는 카드가 어디에서 출발했는지 함께 넘깁니다.
class _RecapDragData {
  const _RecapDragData({required this.card, this.fromSlot});

  final RecapSceneCard card;

  /// 순서 자리에서 시작한 드래그면 그 자리 번호, 트레이에서 시작했으면 null입니다.
  final int? fromSlot;
}

class _PlayRecapPageState extends State<PlayRecapPage> {
  /// 트레이에 놓이는 순서. 한 번 정하면 바뀌지 않아서, 자리에 놓았다가
  /// 되돌린 카드가 늘 같은 위치로 돌아옵니다.
  late List<RecapSceneCard> _shuffled;

  /// 순서 자리. 비어 있으면 null입니다.
  late List<RecapSceneCard?> _slots;

  _RecapStep _step = _RecapStep.arrange;
  String? _selectedCardId;
  bool _showRetryHint = false;
  bool _isListening = false;
  bool _isSaving = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  static const String _demoTranscript =
      '며느리가 방귀를 참느라 시무룩했어요. 방귀 때문에 시아버지 갓이 날아가서 쫓겨났는데, '
      '배나무의 배를 우수수 떨어뜨려서 마을 사람들이 고마워했어요.';

  @override
  void initState() {
    super.initState();
    // 카드 개수는 이야기마다 다를 수 있어(기획: 4~5장) 항상 sceneCards 길이에서 파생시킵니다.
    _shuffled = _trayOrder(widget.sceneCards);
    _slots = List<RecapSceneCard?>.filled(
      widget.sceneCards.length,
      null,
      growable: false,
    );
  }

  /// 정답 순서를 섞습니다. 홀수 자리 → 짝수 자리 역순으로 엮으면 카드 개수가
  /// 몇 장이든 **어떤 카드도 제자리에 남지 않아서**, 우연히 정답이 되지 않습니다.
  /// (`Random` 을 쓰지 않는 이유: 미리보기와 테스트에서 같은 배치를 보려고)
  static List<RecapSceneCard> _trayOrder(List<RecapSceneCard> cards) {
    final List<RecapSceneCard> odd = <RecapSceneCard>[];
    final List<RecapSceneCard> even = <RecapSceneCard>[];
    for (int i = 0; i < cards.length; i++) {
      (i.isOdd ? odd : even).add(cards[i]);
    }
    return <RecapSceneCard>[...odd, ...even.reversed];
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    super.dispose();
  }

  /// 아직 자리에 놓이지 않은 카드들입니다.
  List<RecapSceneCard> get _trayCards => _shuffled
      .where(
        (RecapSceneCard card) =>
            !_slots.any((RecapSceneCard? slot) => slot?.id == card.id),
      )
      .toList(growable: false);

  bool get _isReady => !_slots.contains(null);

  bool get _isCorrect {
    for (int i = 0; i < _slots.length; i++) {
      if (_slots[i]?.id != widget.sceneCards[i].id) return false;
    }
    return true;
  }

  /// 카드를 [slotIndex] 자리에 놓습니다.
  ///
  /// - 트레이에서 온 카드가 이미 찬 자리에 놓이면, 원래 있던 카드는 트레이로 돌아갑니다.
  /// - 다른 자리에서 온 카드면 두 자리를 맞바꿉니다.
  void _drop(_RecapDragData data, int slotIndex) {
    if (data.fromSlot == slotIndex) return;
    setState(() {
      final RecapSceneCard? occupant = _slots[slotIndex];
      if (data.fromSlot != null) {
        _slots[data.fromSlot!] = occupant;
      }
      _slots[slotIndex] = data.card;
      _selectedCardId = null;
      _showRetryHint = false;
    });
  }

  void _returnToTray(int slotIndex) {
    setState(() {
      _slots[slotIndex] = null;
      _selectedCardId = null;
      _showRetryHint = false;
    });
  }

  /// 탭 대체 경로: 트레이 카드를 고른 뒤 자리를 누르면 놓입니다.
  void _handleSlotTap(int slotIndex) {
    final String? selectedId = _selectedCardId;
    if (selectedId != null) {
      for (final RecapSceneCard card in _trayCards) {
        if (card.id == selectedId) {
          _drop(_RecapDragData(card: card), slotIndex);
          return;
        }
      }
      return;
    }
    if (_slots[slotIndex] != null) _returnToTray(slotIndex);
  }

  void _handleTrayCardTap(RecapSceneCard card) {
    setState(() {
      _selectedCardId = _selectedCardId == card.id ? null : card.id;
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
      _selectedCardId = null;
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
      // 초록은 진행바·확인 버튼·놓을 자리 같은 "신호"에만 씁니다.
      // 바탕까지 초록이면 신호가 묻히므로 바탕은 옅은 하늘빛으로 둡니다.
      backgroundColor: const Color(0xFFEFF4F8),
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
                        slots: _slots,
                        tray: _trayCards,
                        selectedCardId: _selectedCardId,
                        showRetryHint: _showRetryHint,
                        isReady: _isReady,
                        compact: compact,
                        onSlotTap: _handleSlotTap,
                        onTrayCardTap: _handleTrayCardTap,
                        onDropOnSlot: _drop,
                        onReturnToTray: _returnToTray,
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

/// 1단계 — 위쪽 빈 자리에 아래 트레이의 그림 카드를 끌어다 놓습니다.
class _ArrangeStep extends StatelessWidget {
  const _ArrangeStep({
    required this.slots,
    required this.tray,
    required this.selectedCardId,
    required this.showRetryHint,
    required this.isReady,
    required this.compact,
    required this.onSlotTap,
    required this.onTrayCardTap,
    required this.onDropOnSlot,
    required this.onReturnToTray,
    required this.onCheck,
    super.key,
  });

  final List<RecapSceneCard?> slots;
  final List<RecapSceneCard> tray;
  final String? selectedCardId;
  final bool showRetryHint;
  final bool isReady;
  final bool compact;
  final ValueChanged<int> onSlotTap;
  final ValueChanged<RecapSceneCard> onTrayCardTap;
  final void Function(_RecapDragData data, int slotIndex) onDropOnSlot;
  final ValueChanged<int> onReturnToTray;
  final VoidCallback onCheck;

  static const double _gap = 14;

  /// 자리 줄과 트레이 사이(안내 문구 포함)에 들어가는 세로 여백입니다.
  static const double _boardToTrayGap = 14 + 20 + 8;

  /// 순서 자리는 트레이 카드보다 작습니다. 큰 그림은 트레이에 두고,
  /// 자리는 놓을 곳을 가리키는 표지 역할만 합니다.
  static const double _slotScale = .68;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 14 : 22, 8, compact ? 14 : 22, 20),
      child: Column(
        children: <Widget>[
          const _InstructionHeader(
            eyebrow: '첫 번째 활동',
            title: '장면을 이야기 순서대로 놓아 보세요',
            description: '아래 카드를 위쪽 빈 자리에 끌어다 놓아요. 카드를 누른 뒤 자리를 눌러도 돼요.',
            icon: Icons.view_carousel_rounded,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.maxWidth;
                final int count = slots.length;

                // 한 줄에 다 펼쳤을 때 칸이 너무 얇아지면(카드가 많거나 화면이 좁으면)
                // 2열 격자로 접습니다. 4장 기준 매직 넘버 없이 개수에서 파생시킵니다.
                final double oneRowWidth = (width - _gap * (count - 1)) / count;
                final bool grid = compact || oneRowWidth < 150;
                final int perRow = grid ? 2 : count;
                final int rows = (count / perRow).ceil();

                // 아이가 들여다보는 건 트레이의 그림입니다. 그래서 **트레이 카드 크기를
                // 먼저 정하고** 순서 자리는 그보다 작게 둡니다. 자리는 "여기에 놓는다"만
                // 알려 주면 되는 표지라 클 필요가 없습니다.
                // 32 = 트레이 안쪽 여백 24 + 테두리 여유 8
                final double trayFit = (width - 32 - 12 * (count - 1)) / count;
                final bool trayScrolls = compact || trayFit < 150;
                final double chrome =
                    rows * 12 + (rows - 1) * _gap + _boardToTrayGap + 38;
                final double byHeight =
                    (constraints.maxHeight - chrome) *
                    16 /
                    9 /
                    (rows * _slotScale + 1);
                final double trayWidth = trayScrolls
                    // 스크롤되는 트레이는 폭에 매이지 않으니 화면의 62%까지 키웁니다.
                    // 다음 카드가 살짝 걸쳐 보여서 "옆에 더 있다"도 같이 알려 줍니다.
                    ? math.max(180, math.min(byHeight, width * .62))
                    : math.max(150, math.min(trayFit, byHeight));
                final double slotWidth = trayWidth * _slotScale;

                // 자리와 트레이는 한 덩어리로 세로 가운데에 둡니다. 위로 붙여 놓으면
                // 넓은 화면에서 확인 버튼과의 사이가 텅 빈 채로 남습니다.
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        _buildBoard(slotWidth, perRow),
                        const SizedBox(height: 14),
                        const _TrayCaption(),
                        const SizedBox(height: 8),
                        _buildTray(trayWidth, scrollable: trayScrolls),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: showRetryHint
                ? const Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 10),
                    child: _GentleHint(),
                  )
                : const SizedBox(height: 42),
          ),
          SizedBox(
            width: compact ? double.infinity : 340,
            height: 64,
            child: FilledButton.icon(
              onPressed: isReady ? onCheck : null,
              icon: const Icon(Icons.check_circle_rounded, size: 28),
              label: const Text('이 순서로 확인하기'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF347F69),
                disabledBackgroundColor: const Color(0xFFCBDCD8),
                disabledForegroundColor: const Color(0xFF6E8B85),
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

  Widget _buildBoard(double slotWidth, int perRow) {
    final List<Widget> tiles = List<Widget>.generate(
      slots.length,
      (int index) => _OrderSlot(
        index: index,
        card: slots[index],
        width: slotWidth,
        // 트레이 카드를 고른 상태에서는 빈 자리를 눈에 띄게 해서
        // "여기를 누르면 놓인다"를 그림만으로 알 수 있게 합니다.
        highlightEmpty: selectedCardId != null,
        onTap: () => onSlotTap(index),
        onAccept: (_RecapDragData data) => onDropOnSlot(data, index),
      ),
    );

    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < tiles.length; i += perRow) {
      final List<Widget> chunk = tiles.sublist(
        i,
        math.min(i + perRow, tiles.length),
      );
      // 카드가 홀수여서 마지막 줄이 덜 차면(예: 5장 → 2/2/1) 빈 칸을 남겨
      // 위 줄과 세로로 나란히 서게 합니다.
      final int missing = perRow - chunk.length;
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (int j = 0; j < chunk.length; j++) ...<Widget>[
              if (j > 0) const SizedBox(width: _gap),
              chunk[j],
            ],
            for (int j = 0; j < missing; j++) SizedBox(width: slotWidth + _gap),
          ],
        ),
      );
    }

    return Column(
      children: <Widget>[
        for (int i = 0; i < rows.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: _gap),
          rows[i],
        ],
      ],
    );
  }

  Widget _buildTray(double cardWidth, {required bool scrollable}) {
    final double cardHeight = cardWidth * 9 / 16 + 10;
    final List<Widget> cards = <Widget>[
      for (int i = 0; i < tray.length; i++) ...<Widget>[
        if (i > 0) const SizedBox(width: 12),
        _TrayCard(
          card: tray[i],
          width: cardWidth,
          // 그림이 없을 때 카드를 서로 구분하려고 트레이 자리 번호를 씁니다.
          // (섞인 자리 번호라 정답이 새지 않습니다)
          fallbackLabel: '${i + 1}',
          selected: selectedCardId == tray[i].id,
          scrollable: scrollable,
          onTap: () => onTrayCardTap(tray[i]),
        ),
      ],
    ];

    return DragTarget<_RecapDragData>(
      onWillAcceptWithDetails: (DragTargetDetails<_RecapDragData> details) =>
          details.data.fromSlot != null,
      onAcceptWithDetails: (DragTargetDetails<_RecapDragData> details) =>
          onReturnToTray(details.data.fromSlot!),
      builder:
          (
            BuildContext context,
            List<_RecapDragData?> candidate,
            List<dynamic> rejected,
          ) {
            final bool hovered = candidate.isNotEmpty;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hovered ? const Color(0xFFE4F2EC) : Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: hovered
                      ? const Color(0xFF347F69)
                      : const Color(0xFFDCE5EB),
                  width: hovered ? 3 : 2,
                ),
              ),
              child: SizedBox(
                // 가로 스크롤일 때만 화면 폭을 다 씁니다. 넓은 화면에서는
                // 카드 폭만큼만 차지해서 띠가 텅 비어 보이지 않게 합니다.
                width: scrollable || tray.isEmpty ? double.infinity : null,
                height: cardHeight,
                child: tray.isEmpty
                    ? const Center(child: _TrayEmptyMessage())
                    : scrollable
                    ? ListView(
                        scrollDirection: Axis.horizontal,
                        children: cards,
                      )
                    : Row(mainAxisSize: MainAxisSize.min, children: cards),
              ),
            );
          },
    );
  }
}

class _TrayCaption extends StatelessWidget {
  const _TrayCaption();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(Icons.arrow_upward_rounded, size: 20, color: Color(0xFF6C8798)),
        SizedBox(width: 6),
        Text(
          '여기 있는 카드를 위 자리에 놓아요',
          style: TextStyle(
            color: Color(0xFF5B7688),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TrayEmptyMessage extends StatelessWidget {
  const _TrayEmptyMessage();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.done_all_rounded, color: Color(0xFF347F69)),
        SizedBox(width: 8),
        Flexible(
          child: Text(
            '카드를 다 놓았어요! 순서를 확인해 볼까요?',
            style: TextStyle(
              color: Color(0xFF3E7266),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

/// 위쪽 순서 자리 하나입니다. 비어 있으면 자리 번호가 크게 보입니다.
class _OrderSlot extends StatelessWidget {
  const _OrderSlot({
    required this.index,
    required this.card,
    required this.width,
    required this.highlightEmpty,
    required this.onTap,
    required this.onAccept,
  });

  final int index;
  final RecapSceneCard? card;
  final double width;
  final bool highlightEmpty;
  final VoidCallback onTap;
  final ValueChanged<_RecapDragData> onAccept;

  @override
  Widget build(BuildContext context) {
    final int order = index + 1;
    final RecapSceneCard? placed = card;
    final double height = width * 9 / 16 + 12;

    return DragTarget<_RecapDragData>(
      onWillAcceptWithDetails: (DragTargetDetails<_RecapDragData> details) =>
          details.data.fromSlot != index,
      onAcceptWithDetails: (DragTargetDetails<_RecapDragData> details) =>
          onAccept(details.data),
      builder:
          (
            BuildContext context,
            List<_RecapDragData?> candidate,
            List<dynamic> rejected,
          ) {
            final bool hovered = candidate.isNotEmpty;
            // 카드를 고르면 빈 자리는 테두리만 굵어집니다. 면까지 칠하면
            // 자리가 전부 초록으로 물들어서 "지금 여기"가 안 보입니다.
            final bool outlined = highlightEmpty && placed == null;
            return Semantics(
              button: true,
              label: placed == null
                  ? '$order번째 자리, 비어 있음'
                  : '$order번째 자리, ${placed.title}',
              child: GestureDetector(
                key: ValueKey<String>('recap-slot-$index'),
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: width,
                  height: height,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: hovered ? const Color(0xFFDFF1E9) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: hovered || outlined
                          ? const Color(0xFF347F69)
                          : const Color(0xFFCBD8E0),
                      width: hovered || outlined ? 4 : 3,
                    ),
                    boxShadow: hovered
                        ? const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x3D347F69),
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: placed == null
                      ? _EmptySlotBody(
                          order: order,
                          size: math.min(66, width * 9 / 16 * .62),
                        )
                      : Stack(
                          children: <Widget>[
                            Positioned.fill(
                              child: Draggable<_RecapDragData>(
                                data: _RecapDragData(
                                  card: placed,
                                  fromSlot: index,
                                ),
                                feedback: _dragFeedback(
                                  card: placed,
                                  width: width,
                                  fallbackLabel: '$order',
                                ),
                                childWhenDragging: Opacity(
                                  opacity: .25,
                                  child: _SceneImage(
                                    card: placed,
                                    fallbackLabel: '$order',
                                    radius: 18,
                                  ),
                                ),
                                child: _SceneImage(
                                  card: placed,
                                  fallbackLabel: '$order',
                                  radius: 18,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 8,
                              top: 8,
                              child: _OrderBadge(order: order),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
    );
  }
}

class _EmptySlotBody extends StatelessWidget {
  const _EmptySlotBody({required this.order, required this.size});

  final int order;

  /// 자리 크기에 따라 번호 원도 같이 줄어듭니다. 고정 크기로 두면
  /// 작은 자리에서 원이 칸을 뚫고 나갑니다.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFEDF2F7),
          shape: BoxShape.circle,
        ),
        child: Text(
          '$order',
          style: TextStyle(
            color: const Color(0xFF4C6B82),
            fontSize: size * .48,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _OrderBadge extends StatelessWidget {
  const _OrderBadge({required this.order});

  final int order;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF173B57),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        '$order',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// 아직 자리에 놓이지 않은 그림 카드입니다. 제목 글자는 그리지 않습니다.
class _TrayCard extends StatelessWidget {
  const _TrayCard({
    required this.card,
    required this.width,
    required this.fallbackLabel,
    required this.selected,
    required this.scrollable,
    required this.onTap,
  });

  final RecapSceneCard card;
  final double width;
  final String fallbackLabel;
  final bool selected;

  /// 트레이가 가로 스크롤이면 세로 방향 드래그에서만 카드가 따라옵니다.
  /// (가로로 미는 동작은 스크롤에 양보합니다)
  final bool scrollable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double height = width * 9 / 16 + 10;
    final Widget body = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: width,
      height: height,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? const Color(0xFF347F69) : const Color(0xFFDCE5EB),
          width: selected ? 4 : 2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: selected ? const Color(0x40347F69) : const Color(0x1F3B5771),
            blurRadius: selected ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _SceneImage(card: card, fallbackLabel: fallbackLabel, radius: 17),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: card.title,
      child: GestureDetector(
        key: ValueKey<String>('recap-tray-${card.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Draggable<_RecapDragData>(
          data: _RecapDragData(card: card),
          affinity: scrollable ? Axis.vertical : null,
          feedback: _dragFeedback(
            card: card,
            width: width,
            fallbackLabel: fallbackLabel,
          ),
          childWhenDragging: Opacity(opacity: .25, child: body),
          child: body,
        ),
      ),
    );
  }
}

/// 끌고 있는 동안 손가락을 따라오는 카드. 살짝 커지고 그림자가 붙습니다.
Widget _dragFeedback({
  required RecapSceneCard card,
  required double width,
  required String fallbackLabel,
}) {
  final double dragWidth = width * 1.08;
  return Material(
    color: Colors.transparent,
    elevation: 16,
    shadowColor: const Color(0x66234B5F),
    borderRadius: BorderRadius.circular(20),
    child: SizedBox(
      width: dragWidth,
      height: dragWidth * 9 / 16,
      child: _SceneImage(card: card, fallbackLabel: fallbackLabel, radius: 20),
    ),
  );
}

/// 장면 그림. 에셋이 없어도 알아볼 수 있는 폴백을 그립니다.
class _SceneImage extends StatelessWidget {
  const _SceneImage({
    required this.card,
    required this.fallbackLabel,
    required this.radius,
  });

  final RecapSceneCard card;
  final String fallbackLabel;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        color: const Color(0xFFECF1F6),
        child: Image.asset(
          card.image,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stackTrace) =>
                  _SceneImageFallback(label: fallbackLabel),
        ),
      ),
    );
  }
}

class _SceneImageFallback extends StatelessWidget {
  const _SceneImageFallback({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFE7EEF5), Color(0xFFD6E3EF)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.image_rounded, size: 26, color: Color(0xFF83A6B0)),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF4E7684),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
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
          Flexible(
            child: Text(
              '거의 다 왔어요! 처음에 어떤 일이 있었는지 다시 살펴볼까요?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF795218),
                fontWeight: FontWeight.w800,
              ),
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
                      SizedBox(height: 420, child: recorder),
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

/// 2단계 참고판 — 정답 순서대로 놓인 장면 그림과 핵심 낱말.
class _StoryReference extends StatelessWidget {
  const _StoryReference({required this.cards, required this.keywords});

  final List<RecapSceneCard> cards;
  final List<String> keywords;

  static const double _thumbWidth = 138;

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
          SizedBox(
            height: _thumbWidth * 9 / 16 + 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const Center(
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF80A295),
                    ),
                  ),
              itemBuilder: (BuildContext context, int index) {
                final RecapSceneCard card = cards[index];
                return Semantics(
                  label: '${index + 1}번째 장면, ${card.title}',
                  child: SizedBox(
                    width: _thumbWidth,
                    child: Column(
                      children: <Widget>[
                        SizedBox(
                          height: _thumbWidth * 9 / 16,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFD4E4E1),
                                width: 2,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: _SceneImage(
                                card: card,
                                fallbackLabel: '${index + 1}',
                                radius: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
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
                );
              },
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
            // 개수를 자르지 않습니다. Wrap 이 알아서 줄바꿈하고,
            // take(n)으로 잘라 두면 낱말이 늘었을 때 말없이 사라집니다.
            children: keywords
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
