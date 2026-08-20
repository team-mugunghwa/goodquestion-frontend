import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/text/korean_keyword_match.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_canvas.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/kid_button.dart';
import '../../../../core/widgets/kid_speech_bubble.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../../core/widgets/story_cover.dart';
import '../../domain/entities/play_session.dart';
import '../../domain/repositories/play_repository.dart';
import '../voice/mission_voice_recorder.dart';

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

/// 이야기 종료 후 `순서 맞추기 → 다시 말하기 → 저장 완료`를 진행하는 아이 화면입니다.
///
/// ## 배치 — 전 폭에서 하나의 세로 레이아웃
///
/// ```
/// 상단 바 (뒤로 · 단계)        고정
/// ────────────────────────
/// 본문                        스크롤(넘칠 때만)
/// ────────────────────────
/// 하단 조작 (확인 / 마이크)     고정
/// ```
///
/// 폭에 따라 레이아웃을 갈아 끼우지 않습니다. 본문 높이가 모자라면 본문만
/// 스크롤되고 **하단 조작은 늘 같은 자리**에 남습니다. 폰 가로(844×390)처럼
/// 세로가 짧은 화면에서 "넓은 화면"으로 분류돼 무너지는 일이 없습니다.
///
/// ## 두 단계가 세로를 다르게 씁니다
///
/// 1단계(순서 맞추기)는 **한 화면 안에** 자리와 트레이를 다 담아야 해서 세로
/// 예산을 역산합니다 — 카드를 끌어다 놓는 활동이라 스크롤이 곧 오조작입니다.
///
/// 2단계(다시 말하기)는 **채팅 로그**라 스크롤이 정상입니다. 대신
/// [_RetellStep.sceneImageMinHeight] 로 장면 그림이 작아지는 것만 막습니다 —
/// 아이는 말하는 내내 그 그림을 봅니다.
class PlayRecapPage extends StatefulWidget {
  const PlayRecapPage({
    required this.sessionId,
    this.storyTitle = '오늘의 이야기',
    this.storyId,
    this.lastCharacterName,
    this.repository,
    this.voiceRecorder,
    this.sceneCards = _defaultCards,
    this.keywords = _defaultKeywords,
    super.key,
  });

  final String sessionId;
  final String storyTitle;

  /// 방금 끝낸 이야기. **완료 화면의 "○○와 더 이야기하기" 진입점에만**
  /// 씁니다. 활동 API 는 세션만 알고 이야기를 안 내려줘서, 화면을 여는
  /// 재생 화면이 주소에 실어 보냅니다. → `AppRoutes.playRecapOf`
  ///
  /// `null` 이면 진입점을 **그리지 않습니다**. 이야기를 모르면 인물 목록을
  /// 부를 수 없는데, 눌러 놓고 빈 화면을 보여 주는 것이 더 나쁩니다.
  final String? storyId;

  /// 마지막 대화 장면의 인물 이름. 진입점 버튼이 이 이름을 부릅니다 —
  /// "이야기 친구"보다 아이가 훨씬 빨리 알아봅니다. 없으면 일반 문구로
  /// 되돌아갑니다.
  final String? lastCharacterName;

  /// 서버와 이어 주는 통로. **null 이면 데모 모드**입니다 - 아래 고정값으로
  /// 화면만 돌려 봅니다(`lib/main_recap_preview.dart` · 위젯 테스트).
  /// 앱에서는 라우터가 늘 넣어 줍니다.
  final PlayRepository? repository;

  /// null 이면 [DeviceMissionVoiceRecorder] 를 씁니다.
  final MissionVoiceRecorder? voiceRecorder;

  /// **데모 모드 전용 고정 카드.** [repository] 가 있으면 서버가 준 카드가
  /// 대신 들어오고 이 값은 쓰이지 않습니다.
  ///
  /// 데모에서는 **이야기 순서(정답 순서)대로** 넣어 주세요. 화면에서는 섞어서
  /// 보여 주고, 정답도 이 순서로 판정합니다. 서버 모드에서는 프런트가 정답
  /// 순서를 아예 알지 못합니다.
  final List<RecapSceneCard> sceneCards;

  /// **데모 모드 전용 고정 낱말.** 서버 모드에서는 순서를 맞힌 뒤 `order`
  /// 응답의 `retellingKeywords` 가 들어옵니다.
  ///
  /// 장면과 **1:1로 짝지어집니다**. `keywords[i]` 가 [sceneCards]`[i]` 의
  /// 낱말이고, 2단계에서 그 장면 카드 안에 붙어서 보입니다.
  ///
  /// 개수가 장면과 달라도 화면은 깨지지 않습니다(모자라면 낱말 없는 장면,
  /// 남으면 마지막 장면에 몰아 붙임). 다만 그건 콘텐츠 오류입니다.
  ///
  /// **1단계에서는 쓰지 않습니다** — 낱말이 곧 장면의 정답 단서라 순서가
  /// 새어 나갑니다. (`docs/BACKEND_REQUESTS_POST_ACTIVITY.md` 3장)
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

/// 장면 하나에 대한 아이의 답변.
///
/// 장면마다 따로 녹음하므로 발화·낱말 체크가 **장면 단위로 갈립니다** -
/// 재녹음해도 다른 장면 답변은 건드리지 않고, 체크도 그 장면의 최신
/// 텍스트로만 다시 계산합니다(이전 것과 합집합하지 않습니다).
class _SceneAnswer {
  const _SceneAnswer({
    required this.text,
    this.rawText,
    this.usedKeywords = const <String>{},
  });

  /// 확정 텍스트. 데모 모드에서는 고정 문장, 서버 모드에서는 STT 교정 결과.
  final String text;

  /// STT 원문(서버가 교정하기 전). 없으면(데모 모드 등) `null`.
  final String? rawText;

  /// 이 장면 텍스트에서 실제로 매칭된 낱말.
  final Set<String> usedKeywords;
}

/// [sceneIndex] 번째 장면에 붙는 낱말 목록입니다.
///
/// 낱말이 장면보다 적으면 남는 장면은 빈 목록(낱말 없음)이고, 많으면 남는
/// 낱말을 **마지막 장면에 몰아 붙입니다.** 조용히 버리면 어휘가 화면에서
/// 사라진 걸 아무도 모르고, 새 줄을 만들면 참고자료 칩 줄이 도로 생깁니다.
///
/// `_SceneStrip`(화면에 뭘 그릴지)과 `_PlayRecapPageState`(무엇을 매칭
/// 판정에 쓸지) 양쪽이 **이 함수 하나**를 부릅니다. 규칙이 두 군데로
/// 갈라지면 화면과 판정이 어긋납니다.
List<String> _keywordsForScene(
  List<String> keywords,
  int sceneIndex,
  int sceneCount,
) {
  if (sceneIndex >= keywords.length) return const <String>[];
  final bool isLast = sceneIndex == sceneCount - 1;
  if (isLast && keywords.length > sceneCount) {
    return keywords.sublist(sceneIndex);
  }
  return <String>[keywords[sceneIndex]];
}

class _PlayRecapPageState extends State<PlayRecapPage> {
  /// 트레이에 놓이는 순서. 한 번 정하면 바뀌지 않아서, 자리에 놓았다가
  /// 되돌린 카드가 늘 같은 위치로 돌아옵니다.
  ///
  /// 서버 모드에서는 **서버가 준 순서 그대로**입니다 - 여기서 또 섞으면
  /// 재진입할 때마다 배치가 달라집니다(서버는 세션마다 시드를 고정합니다).
  List<RecapSceneCard> _shuffled = const <RecapSceneCard>[];

  /// 순서 자리. 비어 있으면 null입니다.
  List<RecapSceneCard?> _slots = const <RecapSceneCard?>[];

  /// 2단계에 보여 줄 낱말. 서버 모드에서는 **순서를 맞힌 뒤에야** 채워집니다 -
  /// 낱말이 곧 순서의 단서라 그전에는 화면에 있으면 안 됩니다.
  List<String> _keywords = const <String>[];

  _RecapStep _step = _RecapStep.arrange;
  String? _selectedCardId;
  bool _showRetryHint = false;
  bool _isListening = false;

  /// 카드를 받아 오는 중.
  bool _loading = false;
  String? _loadError;

  /// 순서 채점(서버 왕복) 중. 같은 순서를 두 번 보내지 않게 막습니다.
  bool _checking = false;

  bool _recording = false;
  bool _transcribing = false;
  bool _isSaving = false;

  /// 장면별 답변. 길이는 늘 **정답 순서 장면 수와 같습니다** - 이야기마다
  /// 장면이 4~5장으로 다를 수 있어 길이를 박아 두지 않고 [_enterRetell]
  /// 에서 그때그때 만듭니다. `null` = 아직 그 장면을 말하지 않았습니다.
  List<_SceneAnswer?> _answers = const <_SceneAnswer?>[];

  /// 지금 답하는 장면. **뒤로 가는 길은 없습니다** - 막히면 [_skipScene] 로
  /// 빠져나갑니다.
  int _sceneIndex = 0;

  /// 지금 장면에서 STT 가 연속으로 실패한 횟수. 2번 연속 실패하면
  /// [_skipScene] 를 쓸 수 있습니다 - 마이크가 계속 안 되는 아이가 활동에
  /// 갇히지 않게 하는 탈출구입니다. 장면을 넘어가거나 그 장면이 성공하면
  /// 0으로 돌아갑니다.
  int _sceneFailCount = 0;

  /// 말풍선에 띄우는 한 줄 안내. 재녹음·재시도처럼 **아이가 그 자리에서
  /// 풀 수 있는** 상황을 화면 전체 에러로 바꾸지 않기 위한 자리입니다.
  String? _hint;

  /// 완료 응답. 별가루·해금 아이템을 완료 화면에 그리는 데 씁니다.
  PlayRetellingResult? _result;

  /// 실제로 녹음할 때(서버 모드) 처음 만듭니다 - 데모 모드에서는 마이크
  /// 플러그인을 아예 건드리지 않습니다.
  MissionVoiceRecorder? _recorderOrNull;
  MissionVoiceRecorder get _recorder =>
      _recorderOrNull ??= widget.voiceRecorder ?? DeviceMissionVoiceRecorder();

  /// 녹음 상한. 서버 업로드 한도에 닿기 전에 스스로 끊습니다.
  Timer? _recordLimit;

  /// 데모 모드의 저장 시늉. `Future.delayed` 대신 [Timer] 를 쓰고 [dispose] 에서
  /// 끕니다 — 화면을 나간 뒤 `setState` 가 불리면 위젯 테스트가 죽습니다.
  Timer? _saveTimer;

  /// 데모 모드 전용 고정 문장. **장면 수만큼 쪼갭니다** - 한 덩어리를 계속
  /// 보여 주면 장면마다 다른 말을 하는 척도 안 나고, 재녹음해도 늘 같은
  /// 전체 줄거리만 반복됩니다.
  ///
  /// 장면이 이 목록보다 많으면(콘텐츠가 늘어난 경우) **순환시키지 않고
  /// 마지막 문장을 그대로 재사용**합니다. 순환시키면 뒷장면에 앞장면
  /// 문장이 다시 붙어서 "어라, 아까 그 말인데?" 하고 아이가 헷갈릴 수
  /// 있습니다 - 이야기가 끝나가는 느낌은 마지막 문장을 밀어 쓰는 쪽이 낫습니다.
  static const List<String> _demoTranscripts = <String>[
    '며느리가 방귀를 참다가 시무룩하게 서 있었어요.',
    '방귀 때문에 시아버지 갓이 날아가서 화가 났어요.',
    '며느리가 방귀로 배나무의 배를 우수수 떨어뜨렸어요.',
    '마을 사람들이 배를 얻고 며느리에게 고마워했어요.',
  ];

  String _demoTextFor(int sceneIndex) =>
      _demoTranscripts[math.min(sceneIndex, _demoTranscripts.length - 1)];

  @override
  void initState() {
    super.initState();
    if (widget.repository == null) {
      // 데모 모드 - 고정 카드를 프런트가 섞어서 씁니다.
      // 카드 개수는 이야기마다 다를 수 있어(기획: 4~5장) 항상 길이에서 파생시킵니다.
      _shuffled = _trayOrder(widget.sceneCards);
      _slots = List<RecapSceneCard?>.filled(
        widget.sceneCards.length,
        null,
        growable: false,
      );
      return;
    }
    unawaited(_start());
  }

  /// 카드 받아 오기. 실패해도 다시 시도할 수 있어야 합니다 - 여기서 막히면
  /// 아이는 활동 자체를 시작하지 못합니다.
  Future<void> _start() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final PlayPostActivityStart start = await widget.repository!
          .startPostActivity(widget.sessionId);
      if (!mounted) return;
      final List<RecapSceneCard> cards = <RecapSceneCard>[
        for (final PlayPostActivityCard card in start.cards)
          RecapSceneCard(
            id: card.cardId,
            title: card.text,
            image: _imageFor(card.cardId),
          ),
      ];
      setState(() {
        _loading = false;
        _shuffled = cards;
        _slots = List<RecapSceneCard?>.filled(
          cards.length,
          null,
          growable: false,
        );
      });
    } on Failure catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.message;
      });
    }
  }

  /// 카드 그림은 **서버가 주지 않습니다.** `card_1` ~ `card_4` 의 번호로
  /// 프런트 에셋을 찾습니다(백엔드 시드가 이 그림 4장에 맞춰져 있습니다).
  static String _imageFor(String cardId) =>
      'assets/images/recap/banggui/scene_${cardId.split('_').last}.webp';

  /// 정답 순서를 섞습니다. 홀수 자리 → 짝수 자리 역순으로 엮으면 카드 개수가
  /// 몇 장이든 **어떤 카드도 제자리에 남지 않아서**, 우연히 정답이 되지 않습니다.
  /// (`Random` 을 쓰지 않는 이유: 미리보기와 테스트에서 같은 배치를 보려고)
  ///
  /// **데모 모드에서만 씁니다.** 서버 모드에서는 서버가 섞어 줍니다.
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
    _saveTimer?.cancel();
    _recordLimit?.cancel();
    unawaited(_recorderOrNull?.dispose());
    super.dispose();
  }

  /// 아직 자리에 놓이지 않은 카드들입니다.
  List<RecapSceneCard> get _trayCards => _shuffled
      .where(
        (RecapSceneCard card) =>
            !_slots.any((RecapSceneCard? slot) => slot?.id == card.id),
      )
      .toList(growable: false);

  bool get _isReady => _slots.isNotEmpty && !_slots.contains(null);

  /// **데모 모드 전용 판정.** 서버 모드에서는 프런트가 정답 순서를 모릅니다.
  bool get _isDemoCorrect {
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
      _hint = null;
    });
  }

  void _returnToTray(int slotIndex) {
    setState(() {
      _slots[slotIndex] = null;
      _selectedCardId = null;
      _showRetryHint = false;
      _hint = null;
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

  /// 순서 채점. **서버가 판정합니다** - 프런트는 정답 순서를 모릅니다.
  Future<void> _checkOrder() async {
    if (_checking || !_isReady) return;
    final PlayRepository? repository = widget.repository;
    if (repository == null) {
      if (!_isDemoCorrect) {
        setState(() => _showRetryHint = true);
        return;
      }
      _enterRetell(widget.keywords);
      return;
    }

    setState(() {
      _checking = true;
      _hint = null;
    });
    try {
      final PlayCardOrderResult result = await repository.submitCardOrder(
        widget.sessionId,
        submittedOrder: <String>[
          for (final RecapSceneCard? card in _slots) card!.id,
        ],
      );
      if (!mounted) return;
      setState(() => _checking = false);
      if (!result.correct) {
        // 재시도 횟수 제한이 없습니다. 지금처럼 부드럽게 다시 권하기만 합니다.
        setState(() => _showRetryHint = true);
        return;
      }
      _enterRetell(result.retellingKeywords);
    } on Failure catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _hint = error.message;
      });
    }
  }

  void _enterRetell(List<String> keywords) {
    setState(() {
      _keywords = keywords;
      _step = _RecapStep.retell;
      _selectedCardId = null;
      _showRetryHint = false;
      _hint = null;
      // 장면 수는 이야기마다 다릅니다(4~5장) - 길이를 박지 않고 정답 순서
      // 카드 수에서 그대로 파생시킵니다.
      _answers = List<_SceneAnswer?>.filled(
        _orderedCards.length,
        null,
        growable: false,
      );
      _sceneIndex = 0;
      _sceneFailCount = 0;
    });
    // 마이크를 대신 눌러 주지 않습니다. 아이가 직접 누르는 게 "내 차례"의
    // 신호이고, 자동으로 켜면 "말하기 전" 상태가 한순간만 존재합니다. (PRD F-04)
  }

  /// 마이크. 누르면 녹음을 시작하고, 다시 누르면 끝내고 STT 로 글자를 받습니다.
  /// (`play_view.dart` 의 발화 흐름과 같은 구조입니다)
  Future<void> _toggleListening() async {
    if (_transcribing || _isSaving) return;
    final PlayRepository? repository = widget.repository;
    if (repository == null) {
      // 데모 모드 - 녹음도 STT 도 없이 고정 문장을 보여 줍니다. **시작하는
      // 순간**(눌러서 듣는 상태로 바뀌는 순간) 곧바로 채웁니다 - 이미 답한
      // 장면이면 이 시작이 곧 재녹음이라, 덮어써서 새로 받습니다.
      setState(() {
        final bool startingNow = !_isListening;
        _isListening = startingNow;
        if (startingNow) {
          final String text = _demoTextFor(_sceneIndex);
          _answers[_sceneIndex] = _SceneAnswer(
            text: text,
            usedKeywords: matchedKeywords(
              text,
              _keywordsForScene(_keywords, _sceneIndex, _answers.length),
            ),
          );
        }
      });
      return;
    }

    if (!_recording) {
      try {
        final bool allowed = await _recorder.start();
        if (!mounted) return;
        if (!allowed) {
          setState(() => _hint = RecapStrings.micDenied);
          return;
        }
        setState(() {
          _recording = true;
          _isListening = true;
          _hint = null;
        });
        // 업로드 한도(10MB)에 닿기 전에 스스로 끊습니다.
        _recordLimit?.cancel();
        _recordLimit = Timer(
          const Duration(seconds: maxRecordingSeconds),
          () => unawaited(_toggleListening()),
        );
      } on Object {
        if (mounted) setState(() => _hint = RecapStrings.micFailed);
      }
      return;
    }

    _recordLimit?.cancel();
    setState(() {
      _recording = false;
      _isListening = false;
      _transcribing = true;
    });
    try {
      final Uint8List? audio = await _recorder.stop();
      if (audio == null || audio.isEmpty) throw StateError('empty audio');
      final PlayTranscription transcription = await repository.transcribeAudio(
        audio,
      );
      if (!mounted) return;
      setState(() {
        _transcribing = false;
        _sceneFailCount = 0;
        // 재녹음이면 그 장면의 이전 답과 체크를 덮어씁니다 - 합집합하지
        // 않습니다. 장면끼리는 서로 영향을 주지 않습니다.
        _answers[_sceneIndex] = _SceneAnswer(
          text: transcription.text,
          rawText: transcription.rawText,
          usedKeywords: matchedKeywords(
            transcription.text,
            _keywordsForScene(_keywords, _sceneIndex, _answers.length),
          ),
        );
        _hint = null;
      });
    } on Failure catch (error) {
      if (!mounted) return;
      // 무음·인식 실패는 흔한 상황이라 화면을 통째로 에러로 바꾸지 않고
      // 말풍선으로만 안내한 뒤 그 자리에서 다시 녹음하게 둡니다.
      setState(() {
        _transcribing = false;
        _sceneFailCount++;
        _hint = _voiceRetryHint(error) ?? error.message;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _transcribing = false;
        _sceneFailCount++;
        _hint = RecapStrings.micFailed;
      });
    }
  }

  /// 이 장면에서 STT 가 2번 연속 실패했을 때만 켜집니다.
  bool get _canSkipScene =>
      _sceneFailCount >= 2 && _answers[_sceneIndex] == null;

  /// 다음 장면으로. **이전 장면으로 돌아가는 길은 없습니다** - 이번 범위 밖입니다.
  void _nextScene() {
    if (_answers[_sceneIndex] == null) return;
    setState(() {
      _sceneIndex++;
      _isListening = false;
      _sceneFailCount = 0;
      _hint = null;
    });
  }

  /// 마이크가 계속 안 되는 아이를 위한 탈출구. 이 장면은 `null` 로 남습니다.
  /// 마지막 장면이면 넘어갈 다음 장면이 없으니 곧바로 완료를 시도합니다.
  void _skipScene() {
    if (!_canSkipScene) return;
    final bool isLast = _sceneIndex == _answers.length - 1;
    setState(() {
      _sceneFailCount = 0;
      _hint = null;
      _isListening = false;
      if (!isLast) _sceneIndex++;
    });
    if (isLast) unawaited(_completeActivity());
  }

  /// 마이크 옆 안내로 처리할 실패인지. (`play_view.dart` 와 같은 표)
  String? _voiceRetryHint(Failure error) {
    if (error is! ServerFailure) return null;
    return switch (error.code) {
      'STT_EMPTY_TEXT' => RecapStrings.sttEmpty,
      'AUDIO_TOO_LARGE' => RecapStrings.sttTooLong,
      'AI_RATE_LIMITED' ||
      'AI_UPSTREAM_ERROR' ||
      'AI_UNAVAILABLE' => RecapStrings.sttUnavailable,
      _ => null,
    };
  }

  /// 완료. **이 한 번의 호출로 세션 완료·별가루·아이템 해금이 끝납니다.**
  /// `/retelling` 은 여기서 **정확히 한 번**만 불립니다 - 장면마다 부르지
  /// 않고, 말한 장면을 다 모아 한 번에 보냅니다.
  Future<void> _completeActivity() async {
    if (_isSaving) return;
    // 말한 장면만 순서대로 모읍니다. 건너뛴(=null) 장면은 빠집니다.
    final List<_SceneAnswer> spoken = <_SceneAnswer>[
      for (final _SceneAnswer? answer in _answers)
        if (answer != null) answer,
    ];
    // 답이 하나도 없으면(전부 건너뛴 경우 포함) 보낼 것이 없습니다.
    if (spoken.isEmpty) {
      setState(() => _hint = RecapStrings.sttEmpty);
      return;
    }

    final PlayRepository? repository = widget.repository;
    if (repository == null) {
      setState(() {
        _isListening = false;
        _isSaving = true;
      });
      _saveTimer?.cancel();
      _saveTimer = Timer(AppDurations.turn, () {
        if (!mounted) return;
        setState(() {
          _isSaving = false;
          _step = _RecapStep.completed;
        });
      });
      return;
    }

    final String text = spoken
        .map((_SceneAnswer answer) => answer.text)
        .join(' ')
        .trim();
    // 원문이 하나라도 있으면 같은 방식으로 이어 붙이고, 전부 없으면(데모
    // 등) sttRawText 자체를 보내지 않습니다.
    final bool hasRawText = spoken.any(
      (_SceneAnswer answer) => answer.rawText != null,
    );
    final String? sttRawText = hasRawText
        ? spoken
              .map((_SceneAnswer answer) => answer.rawText ?? answer.text)
              .join(' ')
              .trim()
        : null;

    setState(() {
      _isListening = false;
      _isSaving = true;
      _hint = null;
    });
    try {
      final PlayRetellingResult result = await repository.submitRetelling(
        widget.sessionId,
        text: text,
        sttRawText: sttRawText,
      );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _result = result;
        _step = _RecapStep.completed;
      });
    } on ServerFailure catch (error) {
      if (!mounted) return;
      switch (error.code) {
        // 순서를 맞히기 전이라고 서버가 돌려세웠습니다 - 1단계로 되돌립니다.
        case 'RETELLING_BEFORE_ORDER':
          setState(() {
            _isSaving = false;
            _step = _RecapStep.arrange;
            _showRetryHint = true;
            _keywords = const <String>[];
          });
        // 이미 끝난 세션입니다. 다시 제출하게 두면 계속 같은 벽에 부딪힙니다.
        case 'SESSION_NOT_IN_PROGRESS':
          setState(() {
            _isSaving = false;
            _step = _RecapStep.completed;
          });
        default:
          _failSaving(error.message);
      }
    } on Failure catch (error) {
      if (!mounted) return;
      _failSaving(error.message);
    }
  }

  /// 저장 실패. **활동을 처음부터 다시 하게 만들지 않습니다** - 말한 내용을
  /// 그대로 들고 완료 버튼만 다시 누를 수 있게 둡니다.
  void _failSaving(String message) {
    setState(() {
      _isSaving = false;
      _hint = RecapStrings.saveFailed(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppCanvas.day(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final ScreenMetrics metrics = ScreenMetrics.of(
                constraints.maxWidth,
              );
              return Column(
                children: <Widget>[
                  _RecapTopBar(
                    metrics: metrics,
                    step: _step,
                    onExit: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: respect(context, AppDurations.normal),
                      switchInCurve: AppCurves.standard,
                      switchOutCurve: AppCurves.exit,
                      // 기본 layoutBuilder 는 자식을 Stack 가운데에 느슨하게
                      // 놓습니다. 세로로 쌓은 본문을 그렇게 두면 전환 중 두
                      // 단계가 동시에 트리에 있는 동안 넘칩니다.
                      layoutBuilder: (Widget? current, List<Widget> previous) =>
                          Stack(
                            fit: StackFit.expand,
                            alignment: Alignment.topCenter,
                            children: <Widget>[
                              ...previous,
                              if (current != null) current,
                            ],
                          ),
                      child: _buildStep(metrics),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStep(ScreenMetrics metrics) {
    // 카드를 받기 전에는 고정 카드를 대신 깔지 않습니다. 만질 수 있는 카드가
    // 먼저 떠 있으면 아이가 놓기 시작한 순간 서버 카드로 갈아치워지고,
    // 그 카드들은 이 세션의 정답과 아무 관계가 없습니다.
    if (_loading) {
      return const AppLoadingView(key: ValueKey<String>('loading'));
    }
    final String? loadError = _loadError;
    if (loadError != null) {
      return AppKidErrorView(
        key: const ValueKey<String>('load-error'),
        message: loadError,
        messageStyle: metrics.text(AppTypography.kidBody),
        onRetry: () => unawaited(_start()),
      );
    }
    return switch (_step) {
      _RecapStep.arrange => _ArrangeStep(
        key: const ValueKey<String>('arrange'),
        metrics: metrics,
        slots: _slots,
        tray: _trayCards,
        selectedCardId: _selectedCardId,
        showRetryHint: _showRetryHint,
        hint: _hint,
        isReady: _isReady && !_checking,
        onSlotTap: _handleSlotTap,
        onTrayCardTap: _handleTrayCardTap,
        onDropOnSlot: _drop,
        onReturnToTray: _returnToTray,
        onCheck: () => unawaited(_checkOrder()),
      ),
      _RecapStep.retell => _RetellStep(
        key: const ValueKey<String>('retell'),
        metrics: metrics,
        cards: _orderedCards,
        keywords: _keywords,
        isListening: _isListening,
        isTranscribing: _transcribing,
        isSaving: _isSaving,
        hint: _hint,
        answers: _answers,
        sceneIndex: _sceneIndex,
        canSkip: _canSkipScene,
        onMic: () => unawaited(_toggleListening()),
        onNextScene: _nextScene,
        onComplete: () => unawaited(_completeActivity()),
        onSkip: _skipScene,
      ),
      _RecapStep.completed => _CompletedStep(
        key: const ValueKey<String>('completed'),
        metrics: metrics,
        message: _completedMessage,
        // 완주한 이야기에만 진입점이 뜹니다. 이 화면 자체가 완주의 끝이라
        // 완주 여부를 따로 물을 필요가 없고, 이야기를 알 때만 그립니다.
        freeTalkLabel: widget.storyId == null
            ? null
            : FreeTalkStrings.entryAction(widget.lastCharacterName),
        onFreeTalk: _goFreeTalk,
        onHome: _goHome,
      ),
    };
  }

  /// 2단계에 보여 줄 **정답 순서** 카드. 순서를 맞히고 나서야 그리는 화면이라
  /// 아이가 놓은 자리가 곧 정답 순서입니다 - 서버가 정답 순서를 따로 주지
  /// 않아도 됩니다. (데모 모드는 고정 정답 순서를 그대로 씁니다)
  List<RecapSceneCard> get _orderedCards => widget.repository == null
      ? widget.sceneCards
      : <RecapSceneCard>[
          for (final RecapSceneCard? card in _slots)
            if (card != null) card,
        ];

  /// 마치기 — **pop 이 아니라 go 입니다.**
  ///
  /// 이 화면은 재생 화면 아래 중첩 라우트라 pop 하면 방금 끝낸 재생 화면으로
  /// 돌아갑니다. 거기서 세션을 다시 불러 홈으로 튕겨 주기를 기대할 수는
  /// 없습니다 - 실제로 홈까지 가지 못하고 재생 화면에 머뭅니다. 끝난 활동의
  /// 다음 자리는 홈이므로 곧장 홈으로 갑니다.
  ///
  /// 라우터가 없는 자리(미리보기·위젯 테스트)에서는 pop 으로 물러섭니다.
  void _goHome() {
    final GoRouter? router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
      return;
    }
    router.go(AppRoutes.home);
  }

  /// "○○와 더 이야기하기" — 인물 고르기로 넘깁니다.
  ///
  /// **pop 이 아니라 go 입니다.** [_goHome] 과 같은 이유로, 이 화면은 재생
  /// 화면 아래 중첩 라우트라 pop 하면 방금 끝낸 재생 화면으로 돌아갑니다.
  void _goFreeTalk() {
    final String? storyId = widget.storyId;
    if (storyId == null) return;
    final GoRouter? router = GoRouter.maybeOf(context);
    if (router == null) return;
    router.go(AppRoutes.freeTalkOf(storyId));
  }

  /// 완료 화면 문구. 별가루와 해금 아이템은 **서버 응답에서** 옵니다.
  String get _completedMessage {
    final PlayRetellingResult? result = _result;
    final PlayStardust? stardust = result?.stardust;
    return <String>[
      RecapStrings.completed,
      if (stardust != null && stardust.earned > 0)
        RecapStrings.completedStardust(stardust.earned),
      if (result != null && result.unlockedItems.isNotEmpty)
        RecapStrings.completedUnlocked(result.unlockedItems.length),
    ].join('\n');
  }
}

/// 저장이 끝난 뒤의 마지막 화면.
///
/// 원래는 [AppKidMessageView] 하나(축하 문구 + "마치기")였습니다. 여기에
/// **후속 자유 대화 진입점**이 붙으면서 나가는 문이 둘이 됐습니다.
///
/// 아이 화면은 보통 선택지를 하나만 둡니다 — "취소"가 막다른 길이 되기
/// 때문입니다. 여기는 다릅니다. 둘 다 앞으로 가는 길이고, 하나는 오늘을
/// 끝내는 길, 하나는 정 붙은 친구와 더 이야기하는 길입니다.
///
/// [freeTalkLabel] 이 `null` 이면 예전 그대로 "마치기" 하나만 그립니다.
class _CompletedStep extends StatelessWidget {
  const _CompletedStep({
    required this.metrics,
    required this.message,
    required this.freeTalkLabel,
    required this.onFreeTalk,
    required this.onHome,
    super.key,
  });

  final ScreenMetrics metrics;
  final String message;
  final String? freeTalkLabel;
  final VoidCallback onFreeTalk;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final String? label = freeTalkLabel;
    if (label == null) {
      return AppKidMessageView(
        message: message,
        messageStyle: metrics.text(AppTypography.kidTitle),
        actionIcon: AppIcons.home,
        actionLabel: RecapStrings.completedAction,
        onAction: onHome,
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.asset(
              AppAssets.logoMark,
              width: AppSizes.illustration,
              height: AppSizes.illustration,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.bubbleMaxWidth,
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: metrics.text(AppTypography.kidTitle),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            // 이야기가 끝났다고 헤어질 필요는 없다 - 그래서 이쪽이 주 버튼이다.
            KidPrimaryButton(
              icon: AppIcons.characterSpeaking,
              label: label,
              labelStyle: metrics.text(AppTypography.kidButton),
              onPressed: onFreeTalk,
            ),
            const SizedBox(height: AppSpacing.sm),
            KidSecondaryButton(
              icon: AppIcons.home,
              label: RecapStrings.completedAction,
              labelStyle: metrics.text(AppTypography.kidButton),
              onPressed: onHome,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// 공통 뼈대
// ─────────────────────────────────────────────────────────

/// 상단 바 — 나가는 문 + 지금 몇 단계인지.
///
/// 진행바 대신 점과 **단어**를 씁니다. 초1~3은 막대가 얼마나 찼는지보다
/// "순서 맞추기 / 다시 말하기"라는 말을 훨씬 빨리 읽습니다.
class _RecapTopBar extends StatelessWidget {
  const _RecapTopBar({
    required this.metrics,
    required this.step,
    required this.onExit,
  });

  final ScreenMetrics metrics;
  final _RecapStep step;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final int current = step == _RecapStep.arrange ? 1 : 2;
    final String label = step == _RecapStep.arrange
        ? RecapStrings.stepArrange
        : RecapStrings.stepRetell;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        AppSpacing.sm,
        metrics.screenPadding,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          KidBackButton(
            onPressed: onExit,
            labelStyle: metrics.text(AppTypography.kidLabel),
          ),
          const SizedBox(width: AppSpacing.md),
          // Spacer 를 쓰면 남은 폭을 전부 먹어서, 좁은 화면에서 단계 칩이
          // "다…" 로 뭉개집니다. 칩에 남은 폭을 주고 오른쪽으로 붙입니다.
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                label: RecapStrings.stepOf(current, 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (int i = 1; i <= 2; i++) ...<Widget>[
                        if (i > 1) const SizedBox(width: AppSpacing.xs),
                        _StepDot(filled: i <= current),
                      ],
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: metrics
                              .text(AppTypography.kidLabel)
                              .copyWith(color: AppColors.brandBlueDeep),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.md,
      height: AppSpacing.md,
      decoration: BoxDecoration(
        color: filled ? AppColors.brandBlueDeep : AppColors.ink300,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 화면 아래에 고정되는 조작 줄. 두 단계가 같은 자리·같은 여백을 씁니다.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.metrics, required this.child});

  final ScreenMetrics metrics;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        AppSpacing.md,
        metrics.screenPadding,
        AppSpacing.md,
      ),
      child: child,
    );
  }
}

/// 캐릭터가 거는 말. 두 단계가 같은 자리에서 같은 말풍선을 씁니다.
///
/// 안내·힌트·상태를 **한 자리**에 몰아넣은 이유는 두 가지입니다.
/// 한 화면에 한 가지만 시키기 위해서, 그리고 힌트가 뜰 때마다 아래 것들이
/// 밀려 내려가지 않게 하기 위해서입니다.
class _GuideBubble extends StatelessWidget {
  const _GuideBubble({
    required this.metrics,
    required this.message,
    this.caution = false,
  });

  final ScreenMetrics metrics;
  final String message;

  /// "한 번 더 해볼까?" 톤. 아이 화면에서 빨강 대신 쓰는 유일한 경고색입니다.
  final bool caution;

  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );

  /// 한 줄짜리 안내가 차지하는 높이. 세로 예산 계산에 씁니다.
  static double heightOf(BuildContext context, ScreenMetrics metrics) =>
      metrics.lineHeight(context, AppTypography.kidBody) +
      KidSpeechBubble.chromeOf(padding);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // 캐릭터 에셋이 나오기 전까지는 로고의 말풍선 Q 가 대신 말합니다.
        Image.asset(
          AppAssets.logoMark,
          width: AppSizes.tapChildSecondary,
          height: AppSizes.tapChildSecondary,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: KidSpeechBubble(
            padding: padding,
            color: caution ? AppColors.cautionSurface : null,
            child: AnimatedSwitcher(
              duration: respect(context, AppDurations.quick),
              child: Text(
                message,
                key: ValueKey<String>(message),
                style: metrics
                    .text(AppTypography.kidBody)
                    .copyWith(
                      color: caution ? AppColors.caution : AppColors.ink900,
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// 1단계 — 순서 맞추기
// ─────────────────────────────────────────────────────────

/// 위쪽 빈 자리에 아래 트레이의 그림 카드를 끌어다 놓습니다.
///
/// **트레이가 비면 트레이 영역을 접습니다.** 빈 흰 띠를 남기면 화면에
/// "아직 할 일이 있다"는 거짓 신호가 남고, 접은 만큼 장면 그림이 커집니다.
class _ArrangeStep extends StatelessWidget {
  const _ArrangeStep({
    required this.metrics,
    required this.slots,
    required this.tray,
    required this.selectedCardId,
    required this.showRetryHint,
    required this.hint,
    required this.isReady,
    required this.onSlotTap,
    required this.onTrayCardTap,
    required this.onDropOnSlot,
    required this.onReturnToTray,
    required this.onCheck,
    super.key,
  });

  final ScreenMetrics metrics;
  final List<RecapSceneCard?> slots;
  final List<RecapSceneCard> tray;
  final String? selectedCardId;
  final bool showRetryHint;

  /// 서버 왕복이 실패했을 때의 한 줄 안내. 있으면 말풍선을 대신 차지합니다 -
  /// 안내·힌트·상태는 늘 한 자리에 모읍니다.
  final String? hint;
  final bool isReady;
  final ValueChanged<int> onSlotTap;
  final ValueChanged<RecapSceneCard> onTrayCardTap;
  final void Function(_RecapDragData data, int slotIndex) onDropOnSlot;
  final ValueChanged<int> onReturnToTray;
  final VoidCallback onCheck;

  /// 카드 그림 둘레의 흰 테. 이보다 얇으면 카드가 배경에 붙어 보입니다.
  static const double _cardPad = AppSpacing.sm;

  /// 이보다 작아지면 아이가 장면을 알아보지 못합니다. 여기서 더 줄이는 대신
  /// 2열로 접고, 그래도 모자라면 본문을 스크롤합니다.
  static const double _cardMinWidth = 120;

  @override
  Widget build(BuildContext context) {
    final String message =
        hint ??
        (showRetryHint
            ? RecapStrings.arrangeRetry
            : isReady
            ? RecapStrings.arrangeReady
            : RecapStrings.arrangeGuide);

    return Column(
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double contentWidth =
                  constraints.maxWidth - metrics.screenPadding * 2;
              final int count = slots.length;
              final bool trayVisible = tray.isNotEmpty;

              // ① 한 줄에 다 펼쳤을 때 카드가 너무 얇아지면 2열로 접습니다.
              //    카드 4장을 가정하지 않고 개수에서 파생시킵니다.
              double widthFor(int perRow) =>
                  (contentWidth -
                      AppSpacing.md * 2 -
                      AppSpacing.md * (perRow - 1)) /
                  perRow;
              int perRow = count;
              if (widthFor(perRow) < _cardMinWidth && count > 2) perRow = 2;
              final int rows = (count / perRow).ceil();

              // ② 세로로도 담기는 폭을 구합니다. 트레이가 접히면 프레임이
              //    하나 줄어서 그만큼 장면 그림이 커집니다.
              final double guide = _GuideBubble.heightOf(context, metrics);
              final int frames = rows + (trayVisible ? 1 : 0);
              final double chrome =
                  frames * _cardPad * 2 +
                  (rows - 1) * AppSpacing.md +
                  (trayVisible ? AppSpacing.md * 2 + AppSpacing.lg : 0);
              final double free =
                  constraints.maxHeight - guide - AppSpacing.md - chrome;
              final double byHeight = free / frames * 16 / 9;

              // ③ 세로가 아주 짧은 화면(폰 가로)에서는 어차피 본문이 스크롤됩니다.
              //    그럴 때까지 카드를 쥐어짜면 넓은 화면에 손톱만 한 그림이
              //    떠 있게 되므로, 최소 폭 아래로 내려가면 세로 기준을 버리고
              //    폭 기준을 씁니다.
              final double fit = math.min(widthFor(perRow), byHeight);
              final double cardWidth = math.max(
                _cardMinWidth,
                fit >= _cardMinWidth ? fit : widthFor(perRow),
              );
              // 트레이 카드가 한 줄에 다 안 들어가면 가로 스크롤로 바뀝니다.
              // 다음 카드가 살짝 걸쳐 보여서 "옆에 더 있다"도 함께 알려 줍니다.
              final bool trayScrolls =
                  tray.length * cardWidth + (tray.length - 1) * AppSpacing.md >
                  contentWidth - AppSpacing.md * 2;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: metrics.screenPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      _GuideBubble(
                        metrics: metrics,
                        message: message,
                        caution: showRetryHint || hint != null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildBoard(cardWidth, perRow),
                      // 트레이가 비면 캡션과 띠를 통째로 접습니다.
                      AnimatedSize(
                        duration: respect(context, AppDurations.normal),
                        curve: AppCurves.standard,
                        alignment: Alignment.topCenter,
                        child: trayVisible
                            ? Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSpacing.lg,
                                ),
                                child: _buildTray(
                                  cardWidth,
                                  scrollable: trayScrolls,
                                ),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _BottomBar(
          metrics: metrics,
          child: Center(
            child: KidPrimaryButton(
              icon: AppIcons.done,
              label: RecapStrings.check,
              labelStyle: metrics.text(AppTypography.kidButton),
              onPressed: isReady ? onCheck : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoard(double cardWidth, int perRow) {
    final List<Widget> tiles = List<Widget>.generate(
      slots.length,
      (int index) => _OrderSlot(
        index: index,
        card: slots[index],
        width: cardWidth,
        pad: _cardPad,
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
              if (j > 0) const SizedBox(width: AppSpacing.md),
              chunk[j],
            ],
            for (int j = 0; j < missing; j++)
              SizedBox(width: cardWidth + AppSpacing.md),
          ],
        ),
      );
    }

    return Column(
      children: <Widget>[
        for (int i = 0; i < rows.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          rows[i],
        ],
      ],
    );
  }

  Widget _buildTray(double cardWidth, {required bool scrollable}) {
    final double cardHeight = cardWidth * 9 / 16 + _cardPad * 2;
    final List<Widget> cards = <Widget>[
      for (int i = 0; i < tray.length; i++) ...<Widget>[
        if (i > 0) const SizedBox(width: AppSpacing.md),
        _TrayCard(
          card: tray[i],
          width: cardWidth,
          pad: _cardPad,
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
              key: const ValueKey<String>('recap-tray'),
              duration: respect(context, AppDurations.quick),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: hovered
                    ? AppColors.brandBlueSurface
                    : AppColors.ink100.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: SizedBox(
                height: cardHeight,
                child: scrollable
                    ? ListView(
                        scrollDirection: Axis.horizontal,
                        children: cards,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: cards,
                      ),
              ),
            );
          },
    );
  }
}

/// 위쪽 순서 자리 하나입니다. 비어 있으면 자리 번호가 크게 보입니다.
class _OrderSlot extends StatelessWidget {
  const _OrderSlot({
    required this.index,
    required this.card,
    required this.width,
    required this.pad,
    required this.highlightEmpty,
    required this.onTap,
    required this.onAccept,
  });

  final int index;
  final RecapSceneCard? card;
  final double width;
  final double pad;
  final bool highlightEmpty;
  final VoidCallback onTap;
  final ValueChanged<_RecapDragData> onAccept;

  @override
  Widget build(BuildContext context) {
    final int order = index + 1;
    final RecapSceneCard? placed = card;
    final double height = width * 9 / 16 + pad * 2;

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
            // 자리가 전부 물들어서 "지금 여기"가 안 보입니다.
            final bool outlined = highlightEmpty && placed == null;
            return PressScale(
              key: ValueKey<String>('recap-slot-$index'),
              onTap: onTap,
              borderRadius: AppRadius.xl,
              semanticLabel: placed == null
                  ? RecapStrings.slotEmpty(order)
                  : RecapStrings.slotFilled(order, placed.title),
              child: AnimatedContainer(
                duration: respect(context, AppDurations.quick),
                width: width,
                height: height,
                padding: EdgeInsets.all(pad),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                    color: hovered || outlined
                        ? AppColors.brandBlueDeep
                        : AppColors.ink300,
                    width: hovered || outlined ? 3 : 2,
                  ),
                  boxShadow: hovered ? AppShadows.lift : AppShadows.soft,
                ),
                child: placed == null
                    ? _EmptySlotBody(
                        order: order,
                        size: math.min(72, width * 9 / 16 * 0.6),
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
                                opacity: 0.25,
                                child: _SceneImage(
                                  card: placed,
                                  fallbackLabel: '$order',
                                  radius: AppRadius.lg,
                                ),
                              ),
                              child: _SceneImage(
                                card: placed,
                                fallbackLabel: '$order',
                                radius: AppRadius.lg,
                              ),
                            ),
                          ),
                          Positioned(
                            left: AppSpacing.sm,
                            top: AppSpacing.sm,
                            child: _OrderBadge(order: order),
                          ),
                        ],
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
          color: AppColors.ink100,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$order',
          style: AppTypography.kidTitle.copyWith(
            fontSize: size * 0.46,
            color: AppColors.ink500,
          ),
        ),
      ),
    );
  }
}

/// 그림 위 좌상단의 순서 배지.
///
/// 그림 **밑에** 번호를 두면 줄 높이를 이미지 + 상수로 잡은 자리에서 글자
/// 확대 설정을 만나는 순간 넘칩니다. 두 단계가 같은 표기를 쓰는 이점도 있습니다.
class _OrderBadge extends StatelessWidget {
  const _OrderBadge({required this.order});

  final int order;

  static const double size = 36;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.brandBlueDeep,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surface, width: 2),
      ),
      child: Text(
        '$order',
        style: AppTypography.kidLabel.copyWith(color: AppColors.surface),
      ),
    );
  }
}

/// 아직 자리에 놓이지 않은 그림 카드입니다. 제목 글자는 그리지 않습니다.
class _TrayCard extends StatelessWidget {
  const _TrayCard({
    required this.card,
    required this.width,
    required this.pad,
    required this.fallbackLabel,
    required this.selected,
    required this.scrollable,
    required this.onTap,
  });

  final RecapSceneCard card;
  final double width;
  final double pad;
  final String fallbackLabel;
  final bool selected;

  /// 트레이가 가로 스크롤이면 세로 방향 드래그에서만 카드가 따라옵니다.
  /// (가로로 미는 동작은 스크롤에 양보합니다)
  final bool scrollable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double height = width * 9 / 16 + pad * 2;
    final Widget body = AnimatedContainer(
      duration: respect(context, AppDurations.quick),
      width: width,
      height: height,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: selected ? AppColors.brandBlueDeep : AppColors.surface,
          width: selected ? 3 : 2,
        ),
        boxShadow: selected ? AppShadows.lift : AppShadows.soft,
      ),
      child: _SceneImage(
        card: card,
        fallbackLabel: fallbackLabel,
        radius: AppRadius.lg,
      ),
    );

    return Semantics(
      selected: selected,
      child: PressScale(
        key: ValueKey<String>('recap-tray-${card.id}'),
        onTap: onTap,
        borderRadius: AppRadius.xl,
        semanticLabel: card.title,
        child: Draggable<_RecapDragData>(
          data: _RecapDragData(card: card),
          affinity: scrollable ? Axis.vertical : null,
          feedback: _dragFeedback(
            card: card,
            width: width,
            fallbackLabel: fallbackLabel,
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: body),
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
    child: Container(
      width: dragWidth,
      height: dragWidth * 9 / 16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.lift,
      ),
      child: _SceneImage(
        card: card,
        fallbackLabel: fallbackLabel,
        radius: AppRadius.lg,
      ),
    ),
  );
}

/// 장면 그림. 에셋이 없어도 카드끼리 구분되는 폴백을 그립니다.
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
      child: Image.asset(
        card.image,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        excludeFromSemantics: true,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                _SceneImageFallback(seed: card.id, label: fallbackLabel),
      ),
    );
  }
}

/// 그림 에셋이 없을 때의 표지.
///
/// 네 장이 전부 같은 그림이면 순서 맞추기 자체가 불가능해집니다.
/// 카드 id 에서 뽑은 색으로 서로 달라 보이게 합니다.
class _SceneImageFallback extends StatelessWidget {
  const _SceneImageFallback({required this.seed, required this.label});

  final String seed;
  final String label;

  static const List<String> _topics = <String>['옛이야기', '가족', '용기', '동물', '일상'];

  @override
  Widget build(BuildContext context) {
    // hashCode 는 실행마다 달라질 수 있어 골든이 흔들립니다. 코드 유닛 합은
    // 같은 문자열이면 늘 같은 값입니다.
    final int index =
        seed.codeUnits.fold<int>(0, (int a, int b) => a + b) % _topics.length;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        StoryCover(palette: StoryCoverPalette.forTopic(_topics[index])),
        Center(
          child: Text(
            label,
            style: AppTypography.kidTitle.copyWith(color: AppColors.surface),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// 2단계 — 다시 말하기
// ─────────────────────────────────────────────────────────

/// 장면 하나씩 묻고 답하는 **채팅**입니다.
///
/// ```
/// ← 1번째 그림이야. 무슨 일이 있었어?          지나간 장면은
///            며느리가 방귀를 참았어요. →       질문과 답만 남습니다
/// ← 2번째 그림이야. 무슨 일이 있었어?
///        ┌────────────────┐
///        │    장면 그림    │                  지금 말할 장면만
///        │ ✓참다  ○쫓겨나다 │                  크게 그립니다
///        └────────────────┘
/// ```
///
/// **그림은 현재 장면 한 장뿐입니다.** 지나간 장면 그림까지 다 남기면 로그가
/// 끝없이 길어지고, 아이가 "지금 어느 그림을 말할 차례인지"를 놓칩니다.
/// 대신 지나간 장면은 답변 말풍선 안에 작은 썸네일을 달아, 어느 그림에 한
/// 말인지 되짚을 수 있게 합니다.
///
/// **낱말은 그림 바로 아래**에 칩으로 붙어 있습니다. 별도의 칩 줄로 모아 두면
/// 아이에게 "참고자료"로 읽혀서 안 쓰고 넘어갑니다. 실제로 쓴 낱말은 체크가
/// 켜지지만 **판정이 아니라 격려**입니다 — 체크가 하나도 안 켜져도 다음으로
/// 갈 수 있고, 안 썼다고 막거나 되돌리지 않습니다.
///
/// **스크롤되는 것은 채팅 로그뿐입니다.** 마이크와 다음/다 했어는 늘 같은
/// 자리에 남습니다. (파일 상단 배치 규칙)
class _RetellStep extends StatefulWidget {
  const _RetellStep({
    required this.metrics,
    required this.cards,
    required this.keywords,
    required this.isListening,
    required this.isTranscribing,
    required this.isSaving,
    required this.hint,
    required this.answers,
    required this.sceneIndex,
    required this.canSkip,
    required this.onMic,
    required this.onNextScene,
    required this.onComplete,
    required this.onSkip,
    super.key,
  });

  final ScreenMetrics metrics;
  final List<RecapSceneCard> cards;
  final List<String> keywords;
  final bool isListening;

  /// 녹음을 끝내고 글자를 받아 오는 중. 이 사이에 마이크를 다시 누르면
  /// 앞 녹음의 결과와 뒤 녹음이 엉킵니다.
  final bool isTranscribing;
  final bool isSaving;

  /// 다시 녹음·다시 저장처럼 **아이가 그 자리에서 풀 수 있는** 안내.
  /// 채팅에서는 캐릭터가 뒤이어 거는 말풍선으로 로그 맨 아래에 붙습니다.
  final String? hint;

  /// 장면별 답변. 길이는 [cards] 와 같습니다. `null` = 아직 그 장면을
  /// 말하지 않았습니다.
  final List<_SceneAnswer?> answers;

  /// 지금 답하는 장면. 로그는 여기까지만 그립니다 - 아직 묻지 않은 장면을
  /// 미리 보여 주면 그림이 곧 다음 질문의 정답이 됩니다.
  final int sceneIndex;

  /// 지금 장면에서 STT 가 2번 연속 실패해 건너뛸 수 있는 상태인지.
  final bool canSkip;
  final VoidCallback onMic;

  /// 지금 장면 답을 확정하고 다음 장면으로. 마지막 장면이 아닐 때만 씁니다.
  final VoidCallback onNextScene;

  /// 마지막 장면까지 다 답했을 때 - 여기서만 `/retelling` 을 부릅니다.
  final VoidCallback onComplete;

  /// 마이크가 계속 안 되는 아이를 위한 탈출구.
  final VoidCallback onSkip;

  /// 장면 그림 한 장의 세로 하한·상한.
  ///
  /// 채팅 로그는 스크롤을 허용하므로 예전처럼 세로 예산을 역산할 필요는
  /// 없지만, **그림이 작아지는 것만은 막습니다** — 아이는 말하는 내내 이
  /// 그림을 봅니다. 폰 가로(844×390)처럼 세로가 짧은 화면에서는 하한을
  /// 지키고 로그가 스크롤되는 쪽을 고릅니다.
  static const double sceneImageMinHeight = 140;
  static const double sceneImageMaxHeight = 280;

  /// 로그가 보이는 높이 중 그림에 내주는 몫. 나머지는 말풍선 몫입니다.
  ///
  /// 1280×720 에서 "인사 + 질문 + 그림 + 아이 답 + 칭찬"이 딱 한 번의 스크롤
  /// 안에 들어오는 값입니다. 더 키우면 답하고 나서 그림 윗부분이 잘립니다.
  static const double sceneImageShare = .4;

  /// 마이크 옆에 완료 버튼을 놓으려면 한쪽에 이만큼은 있어야 합니다.
  /// (아이콘 40 + 여백 + "다 했어")
  static const double _finishSlot = 190;

  @override
  State<_RetellStep> createState() => _RetellStepState();
}

class _RetellStepState extends State<_RetellStep> {
  final ScrollController _log = ScrollController();

  /// 직전 프레임의 [_tail]. **`oldWidget` 과 비교하면 안 됩니다** — 답변
  /// 목록은 화면 상태가 제자리에서 고쳐 쓰는 같은 [List] 인스턴스라,
  /// `oldWidget.answers` 도 이미 새 답을 들고 있습니다.
  ///
  /// `late … = _tail` 로 두면 안 됩니다 — `late` 초기화는 **처음 읽을 때**
  /// 실행돼서, 첫 비교 시점에 새 값으로 채워지고 늘 "안 바뀌었다"가 됩니다.
  String _lastTail = '';

  /// 로그 맨 아래가 지금 무엇인지. 이 값이 바뀌면 말풍선이 새로 붙은 것이라
  /// 아래로 따라 내려갑니다.
  ///
  /// **듣는 중·받아쓰는 중은 넣지 않습니다.** 말하는 동안 로그가 따라 내려가면
  /// 아이가 보고 말하던 그림이 위로 밀려 올라갑니다. 그 두 상태는 마이크가
  /// 이미 크게 알려 주고 있고, 정작 봐야 할 그림을 뺏을 이유가 없습니다.
  String get _tail => <String>[
    '${widget.sceneIndex}',
    for (final _SceneAnswer? answer in widget.answers) answer?.text ?? '',
    widget.hint ?? '',
  ].join('|');

  @override
  void initState() {
    super.initState();
    // 들어온 첫 프레임은 따라갈 것이 없습니다 - 기준선만 잡아 둡니다.
    _lastTail = _tail;
  }

  @override
  void didUpdateWidget(covariant _RetellStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String tail = _tail;
    if (tail == _lastTail) return;
    _lastTail = tail;
    _followLog();
  }

  @override
  void dispose() {
    _log.dispose();
    super.dispose();
  }

  /// 새 말풍선이 붙으면 로그를 아래 끝으로 내립니다. 화면 밖에서 대화가
  /// 이어지면 아이는 자기가 한 말이 어디로 갔는지 모릅니다.
  ///
  /// 스크린리더는 스크롤을 따라오지 않으므로, 새로 붙는 말풍선 쪽에서
  /// `liveRegion` 으로 함께 읽어 줍니다. ([_live])
  void _followLog() {
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted || !_log.hasClients) return;
      final ScrollPosition position = _log.position;
      if (!position.hasContentDimensions) return;
      final Duration duration = respect(context, AppDurations.normal);
      // "동작 줄이기" 설정에서는 respect 가 0을 돌려주는데, 0으로 animateTo
      // 를 부르면 프레임워크 단언에 걸립니다.
      if (duration == Duration.zero) {
        position.jumpTo(position.maxScrollExtent);
        return;
      }
      unawaited(
        position.animateTo(
          position.maxScrollExtent,
          duration: duration,
          curve: AppCurves.standard,
        ),
      );
    });
  }

  /// 로그 맨 아래에 붙는 캐릭터의 상태 한마디. 없으면 아무 말도 하지
  /// 않습니다 — 아직 말하기 전에는 질문과 그림만으로 할 일이 분명합니다.
  String? get _status {
    if (widget.hint != null) return widget.hint;
    if (widget.isListening) return RecapStrings.retellListening;
    if (widget.isTranscribing) return RecapStrings.retellTranscribing;
    if (widget.answers[widget.sceneIndex] != null) {
      return RecapStrings.retellSpoken;
    }
    return null;
  }

  /// 장면 그림 세로. 로그가 보이는 높이와 폭 양쪽에서 깎은 뒤 하한을 지킵니다.
  double _sceneImageHeight(double viewportHeight, double contentWidth) {
    final double byHeight = viewportHeight * _RetellStep.sceneImageShare;
    final double byWidth = contentWidth * 9 / 16;
    return math
        .min(byHeight, byWidth)
        .clamp(
          _RetellStep.sceneImageMinHeight,
          _RetellStep.sceneImageMaxHeight,
        );
  }

  /// 방금 붙은 말풍선을 스크린리더가 따라 읽게 합니다.
  ///
  /// [_GuideBubble] 은 1단계와 함께 쓰는 위젯이라 건드리지 않고 밖에서
  /// 감쌉니다. `excludeSemantics` 로 안쪽 글자 노드를 접어야 같은 문장이
  /// 두 번 읽히지 않습니다.
  Widget _live(String label, Widget child) => Semantics(
    container: true,
    liveRegion: true,
    label: label,
    excludeSemantics: true,
    child: child,
  );

  /// 장면 질문. **[RecapSceneCard.title] 을 그리지 않습니다** — 그건 장면
  /// 설명이고 곧 정답이라, 읽을 수 있는 아이에게 답을 그대로 줍니다.
  Widget _question(int index) {
    final bool isCurrent = index == widget.sceneIndex;
    final String message = index == widget.answers.length - 1
        ? RecapStrings.sceneQuestionLast
        : RecapStrings.sceneQuestion(index + 1);
    final Widget bubble = _GuideBubble(
      metrics: widget.metrics,
      message: message,
    );
    return isCurrent ? _live(message, bubble) : bubble;
  }

  /// 채팅 로그 한 벌. 위에서 아래로 시간 순입니다.
  List<Widget> _entries(double imageHeight, double contentWidth) {
    final List<Widget> log = <Widget>[
      // 첫 인사. 낱말이 과제의 일부라는 걸 여기서 한 번만 말합니다.
      _GuideBubble(metrics: widget.metrics, message: RecapStrings.retellGuide),
    ];
    for (int i = 0; i <= widget.sceneIndex; i++) {
      final bool isCurrent = i == widget.sceneIndex;
      log.add(_question(i));
      if (isCurrent) {
        log.add(
          _SceneStage(
            metrics: widget.metrics,
            card: widget.cards[i],
            order: i + 1,
            keywords: _keywordsForScene(
              widget.keywords,
              i,
              widget.cards.length,
            ),
            used: widget.answers[i]?.usedKeywords ?? const <String>{},
            imageHeight: imageHeight,
            maxWidth: contentWidth,
          ),
        );
      }
      final _SceneAnswer? answer = widget.answers[i];
      if (answer != null) {
        log.add(
          _AnswerBubble(
            metrics: widget.metrics,
            text: answer.text,
            // 지나간 장면은 큰 그림이 로그에서 사라지므로, 어느 그림에 한
            // 말인지 되짚을 실마리를 답변 안에 남깁니다.
            thumbnail: isCurrent ? null : widget.cards[i],
            live: isCurrent,
          ),
        );
      } else if (!isCurrent) {
        log.add(_SkippedNote(metrics: widget.metrics));
      }
    }
    final String? status = _status;
    if (status != null) {
      log.add(
        _live(
          status,
          _GuideBubble(
            metrics: widget.metrics,
            message: status,
            caution: widget.hint != null,
          ),
        ),
      );
    }

    return <Widget>[
      for (int i = 0; i < log.length; i++) ...<Widget>[
        if (i > 0) const SizedBox(height: AppSpacing.md),
        log[i],
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    // 말하기를 한 번이라도 마쳤는지는 **이 장면의 받아쓴 글자**로 판별합니다.
    // 녹음 시간이나 마이크 상태에서 파생시키면, 0초에 멈춘 아이의 화면에서
    // 다음/완료 버튼이 죽습니다.
    final bool hasSpoken = widget.answers[widget.sceneIndex] != null;
    final bool isLastScene = widget.sceneIndex == widget.answers.length - 1;

    return Column(
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              // 태블릿에서 로그를 화면 끝까지 늘리지 않습니다. 말풍선이 좌우
              // 끝으로 흩어지면 가운데 장면 그림과 따로 노는 세 덩어리가 되고,
              // 한 줄도 길어져 아이가 눈으로 줄을 놓칩니다.
              final double logWidth = math.min(
                constraints.maxWidth - widget.metrics.screenPadding * 2,
                AppBreakpoints.maxContentWidth,
              );
              return SingleChildScrollView(
                controller: _log,
                padding: EdgeInsets.fromLTRB(
                  widget.metrics.screenPadding,
                  0,
                  widget.metrics.screenPadding,
                  AppSpacing.md,
                ),
                child: ContentContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _entries(
                      _sceneImageHeight(constraints.maxHeight, logWidth),
                      logWidth,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _BottomBar(
          metrics: widget.metrics,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget mic = _MicButton(
                metrics: widget.metrics,
                listening: widget.isListening,
                onTap: widget.isSaving || widget.isTranscribing
                    ? null
                    : widget.onMic,
              );
              // 말하기 전에는 다음/완료 버튼을 내보내지 않습니다. 한 화면에서
              // 아이가 고를 것을 하나로 줄이면 다음 행동이 분명해집니다.
              // 마지막 장면이면 "다 했어", 아니면 "다음" - 같은 자리를 씁니다.
              final Widget? finish = hasSpoken
                  ? KidPrimaryButton(
                      icon: AppIcons.done,
                      label: isLastScene
                          ? (widget.isSaving
                                ? RecapStrings.saving
                                : RecapStrings.finish)
                          : RecapStrings.next,
                      labelStyle: widget.metrics.text(AppTypography.kidButton),
                      onPressed: widget.isSaving
                          ? null
                          : (isLastScene
                                ? widget.onComplete
                                : widget.onNextScene),
                    )
                  // 말하기 전인데 이 장면에서 STT 가 2번 연속 실패했으면
                  // 같은 자리에 건너뛰기가 뜹니다 - 마이크에 갇히지 않게.
                  : (widget.canSkip
                        ? KidSecondaryButton(
                            icon: AppIcons.next,
                            label: RecapStrings.skipScene,
                            labelStyle: widget.metrics.text(
                              AppTypography.kidButton,
                            ),
                            onPressed: widget.onSkip,
                          )
                        : null);

              // 마이크는 **늘 화면 한가운데**입니다. 완료 버튼이 나타났다고
              // 마이크가 옆으로 밀리면, 아이 손이 기억한 자리가 어긋납니다.
              // 양옆에 같은 폭의 칸을 두면 오른쪽이 비어도 중심이 안 움직입니다.
              if (constraints.maxWidth >=
                  AppSizes.mic + _RetellStep._finishSlot * 2) {
                return Row(
                  children: <Widget>[
                    const Expanded(child: SizedBox.shrink()),
                    mic,
                    Expanded(
                      child: finish == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(
                                left: AppSpacing.lg,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: finish,
                              ),
                            ),
                    ),
                  ],
                );
              }
              // 폰 세로처럼 옆에 둘 수 없는 폭에서만 아래로 내립니다.
              // **버튼이 없어도 자리는 비워 둡니다** - 접었다 폈다 하면 마이크가
              // 위아래로 움직이고, 그만큼 채팅 로그 높이도 흔들려서 장면 그림이
              // 말할 때마다 커졌다 작아졌다 합니다.
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  mic,
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: AppSizes.tapChildPrimary,
                    child: Center(child: finish ?? const SizedBox.shrink()),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 지금 말할 장면. 그림 한 장과 그 장면의 낱말 칩이 한 덩어리입니다.
///
/// 낱말을 그림 **위에** 얹지 않습니다. 아이는 말하는 내내 그림을 보고 있어서,
/// 조금이라도 가리면 이야기의 단서가 사라집니다.
class _SceneStage extends StatelessWidget {
  const _SceneStage({
    required this.metrics,
    required this.card,
    required this.order,
    required this.keywords,
    required this.used,
    required this.imageHeight,
    required this.maxWidth,
  });

  final ScreenMetrics metrics;
  final RecapSceneCard card;

  /// 정답 순서에서 몇 번째인지. 배지와 스크린리더 라벨에 씁니다.
  final int order;

  /// 이 장면에 붙는 낱말. 없을 수 있습니다. ([_keywordsForScene])
  final List<String> keywords;

  /// 이 장면 답변에서 **실제로 쓴** 낱말. 체크가 여기서 켜집니다.
  final Set<String> used;

  final double imageHeight;

  /// 카드가 쓸 수 있는 최대 폭. 그림이 16:9 라 세로에서 폭이 나오지만,
  /// 화면이 좁으면 이쪽이 먼저 걸립니다.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(maxWidth, imageHeight * 16 / 9),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            // 이 화면에서 그림은 한 장뿐이고, 지금 아이가 보아야 할
            // 하나입니다. 떠 있는 그림자로 로그 위에 세웁니다.
            boxShadow: AppShadows.lift,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: imageHeight,
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      // 제목은 **스크린리더에만** 갑니다. 화면에 그리면 그게
                      // 곧 정답입니다.
                      child: Semantics(
                        image: true,
                        label: RecapStrings.sceneOrder(order, card.title),
                        child: _SceneImage(
                          card: card,
                          fallbackLabel: '$order',
                          radius: AppRadius.md,
                        ),
                      ),
                    ),
                    Positioned(
                      left: AppSpacing.sm,
                      top: AppSpacing.sm,
                      // 배지는 그림 라벨("1번째 장면, …")이 이미 말해 주는
                      // 숫자입니다. 그대로 두면 스크린리더가 "1" 을 따로 한 번
                      // 더 읽습니다.
                      child: ExcludeSemantics(child: _OrderBadge(order: order)),
                    ),
                  ],
                ),
              ),
              if (keywords.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.xs,
                    right: AppSpacing.xs,
                    bottom: AppSpacing.xs,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final String word in keywords)
                        _KeywordChip(
                          metrics: metrics,
                          word: word,
                          used: used.contains(word),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 장면 그림 아래의 낱말 칩. 말하기 전에는 "이 말을 써 보자"는 안내이고,
/// 실제로 쓰면 체크가 켜집니다.
///
/// **판정이 아닙니다.** 체크가 하나도 안 켜져도 다음으로 갈 수 있고, 못 쓴
/// 낱말을 빨강이나 경고로 표시하지 않습니다. 아이 화면에 실패는 없습니다.
///
/// 노란색을 쓰지 않습니다 — 노랑은 별가루(보상) 전용이라 낱말에 쓰면 아이가
/// 낱말을 보상으로 오해합니다. (`docs/DESIGN_SYSTEM.md` 3장)
/// 켜짐/꺼짐은 **면 색·글자색·아이콘 세 가지가 함께** 바뀝니다. 색만 바꾸면
/// 색을 구분하기 어려운 아이에게는 아무 일도 일어나지 않습니다.
class _KeywordChip extends StatelessWidget {
  const _KeywordChip({
    required this.metrics,
    required this.word,
    required this.used,
  });

  final ScreenMetrics metrics;
  final String word;
  final bool used;

  @override
  Widget build(BuildContext context) {
    final Duration duration = respect(context, AppDurations.quick);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: used
          ? RecapStrings.keywordUsed(word)
          : RecapStrings.keywordUnused(word),
      child: AnimatedContainer(
        duration: duration,
        curve: AppCurves.standard,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: used
              ? AppColors.brandGreenSurface
              : AppColors.brandBlueSurface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          // 테두리는 켜졌을 때만 보이지만 자리는 늘 차지합니다. 두께가
          // 오가면 칩 폭이 흔들려서 줄바꿈이 튑니다.
          border: Border.all(
            color: used ? AppColors.brandGreenDeep : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedSwitcher(
              duration: duration,
              // 체크가 켜질 때만 살짝 튑니다. 아이 화면의 등장 곡선입니다.
              transitionBuilder: (Widget child, Animation<double> animation) =>
                  ScaleTransition(
                    scale: animation.drive(
                      CurveTween(curve: AppCurves.playful),
                    ),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
              child: Icon(
                used ? AppIcons.checked : AppIcons.unchecked,
                key: ValueKey<bool>(used),
                size: AppSizes.iconInline,
                color: used ? AppColors.brandGreenDeep : AppColors.ink300,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                word,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: metrics
                    .text(AppTypography.kidLabel)
                    .copyWith(
                      color: used
                          ? AppColors.brandGreenDeep
                          : AppColors.brandBlueDeep,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 아이가 한 말. **아이 발화라 말풍선입니다** — 오른쪽, 아이 면 색.
class _AnswerBubble extends StatelessWidget {
  const _AnswerBubble({
    required this.metrics,
    required this.text,
    required this.thumbnail,
    required this.live,
  });

  final ScreenMetrics metrics;
  final String text;

  /// 지나간 장면의 그림. 로그에서 큰 그림이 사라진 뒤 어느 장면에 한 말인지
  /// 되짚는 실마리입니다. 지금 장면은 바로 위에 그림이 있어 `null` 입니다.
  final RecapSceneCard? thumbnail;

  /// 방금 붙은 말풍선인지. 스크린리더가 새 답변을 따라 읽게 합니다.
  final bool live;

  /// 썸네일 폭. 16:9 라 세로는 여기서 나옵니다.
  static const double _thumbnailWidth = 72;

  static const EdgeInsets _padding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );

  @override
  Widget build(BuildContext context) {
    final RecapSceneCard? scene = thumbnail;
    return KidSpeechBubble(
      speaker: KidSpeaker.child,
      padding: _padding,
      child: Semantics(
        container: true,
        liveRegion: live,
        excludeSemantics: true,
        label: RecapStrings.myAnswer(text),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (scene != null) ...<Widget>[
              SizedBox(
                width: _thumbnailWidth,
                height: _thumbnailWidth * 9 / 16,
                child: _SceneImage(
                  card: scene,
                  fallbackLabel: '',
                  radius: AppRadius.xs,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Flexible(
              child: Text(
                text,
                style: metrics.text(AppTypography.kidTranscript),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 건너뛴 장면 자리에 남는 조용한 표시.
///
/// 아이 말풍선으로 두면 하지 않은 말을 한 것처럼 보이고, 아무것도 안 두면
/// 질문만 덩그러니 남아 답을 잃어버린 것처럼 보입니다. 그래서 화자가 없는
/// 가운데 정렬 꼬리표입니다.
class _SkippedNote extends StatelessWidget {
  const _SkippedNote({required this.metrics});

  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.ink100,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          RecapStrings.sceneSkipped,
          style: metrics
              .text(AppTypography.kidLabel)
              .copyWith(color: AppColors.ink700),
        ),
      ),
    );
  }
}

/// 마이크. 화면에서 가장 큰 조작 요소이고 늘 하단에 있습니다.
///
/// 아이콘만 두지 않습니다 — 초1~3은 아이콘 관습을 아직 모릅니다.
/// 듣는 중은 아이콘·글자·발광이 **동시에** 바뀌어서, 색을 구분하기 어려운
/// 아이도 상태를 압니다.
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.metrics,
    required this.listening,
    required this.onTap,
  });

  final ScreenMetrics metrics;
  final bool listening;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String label = listening
        ? RecapStrings.stopSpeaking
        : RecapStrings.speak;
    return PressScale(
      onTap: onTap,
      borderRadius: AppRadius.pill,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: respect(context, AppDurations.quick),
        width: AppSizes.mic,
        height: AppSizes.mic,
        decoration: BoxDecoration(
          color: AppColors.brandBlueDeep,
          shape: BoxShape.circle,
          // 발광은 그림자라 레이아웃을 밀지 않습니다. 링을 위젯으로 두면
          // 듣는 중일 때만 하단 조작 줄이 커집니다.
          boxShadow: listening
              ? <BoxShadow>[
                  ...AppShadows.lift,
                  const BoxShadow(
                    color: AppColors.brandMint,
                    blurRadius: 16,
                    spreadRadius: 8,
                  ),
                ]
              : AppShadows.lift,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              listening ? AppIcons.speaking : AppIcons.speak,
              size: AppSizes.iconChild,
              color: AppColors.surface,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: metrics
                  .text(AppTypography.kidLabel)
                  .copyWith(color: AppColors.surface),
            ),
          ],
        ),
      ),
    );
  }
}
