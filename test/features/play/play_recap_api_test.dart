import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/router/app_routes.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/core/widgets/kid_button.dart';
import 'package:goodquestion/features/play/domain/entities/play_session.dart';
import 'package:goodquestion/features/play/domain/repositories/play_repository.dart';
import 'package:goodquestion/features/play/presentation/views/play_recap_view.dart';
import 'package:goodquestion/features/play/presentation/voice/mission_voice_recorder.dart';

/// 서버와 이어진 말하기 후 활동. **판정과 데이터가 서버에서 온다**는 것만
/// 봅니다 — 화면 배치는 `play_recap_view_test.dart` 가 지킵니다.
void main() {
  Future<void> pumpRecap(
    WidgetTester tester, {
    required PlayRepository repository,
    MissionVoiceRecorder? recorder,
    Size size = const Size(1280, 720),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PlayRecapPage(
          sessionId: 'session-1',
          repository: repository,
          voiceRecorder: recorder ?? _FakeRecorder(),
        ),
      ),
    );
    await tester.pump();
  }

  Finder slot(int index) => find.byKey(ValueKey<String>('recap-slot-$index'));
  Finder trayCard(String id) => find.byKey(ValueKey<String>('recap-tray-$id'));

  KidPrimaryButton buttonWith(WidgetTester tester, String label) => tester
      .widget<KidPrimaryButton>(find.widgetWithText(KidPrimaryButton, label));

  Future<void> place(WidgetTester tester, String cardId, int slotIndex) async {
    await tester.ensureVisible(trayCard(cardId));
    await tester.pump();
    await tester.tap(trayCard(cardId));
    await tester.pump();
    await tester.ensureVisible(slot(slotIndex));
    await tester.pump();
    await tester.tap(slot(slotIndex));
    await tester.pump();
  }

  /// 서버가 준 순서 그대로 자리에 놓고 확인을 누릅니다.
  Future<void> submitOrder(
    WidgetTester tester, [
    List<String> ids = const <String>['card_3', 'card_1', 'card_4', 'card_2'],
  ]) async {
    for (int i = 0; i < ids.length; i++) {
      await place(tester, ids[i], i);
    }
    await tester.tap(find.text('확인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  /// 마이크를 눌러 녹음하고 다시 눌러 STT 까지 받습니다. **장면 하나만**
  /// 채웁니다 - 실패·재시도처럼 한 장면 안에서의 상태만 볼 때 씁니다.
  Future<void> speak(WidgetTester tester) async {
    await tester.tap(find.text('말하기'));
    await tester.pump();
    await tester.tap(find.text('멈추기'));
    await tester.pump();
    await tester.pump();
  }

  /// [count] 장면을 순서대로 다 채웁니다. 마지막이 아니면 "다음"을 눌러
  /// 다음 장면으로 넘어갑니다 - `submitOrder` 로 채운 4장 기준입니다.
  Future<void> speakAllScenes(WidgetTester tester, {int count = 4}) async {
    for (int i = 0; i < count; i++) {
      await speak(tester);
      final bool isLast = i == count - 1;
      if (!isLast) {
        await tester.tap(find.text(RecapStrings.next));
        await tester.pump();
      }
    }
  }

  testWidgets('카드를 서버에서 받아 온다 - 받기 전에는 카드를 깔지 않는다', (
    WidgetTester tester,
  ) async {
    final _RecapSpyRepository repository = _RecapSpyRepository()
      ..startDelay = Completer<void>();
    await pumpRecap(tester, repository: repository);

    // 아직 카드가 없습니다. 고정 카드를 미리 깔면 아이가 놓기 시작한 순간
    // 서버 카드로 갈아치워집니다.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(trayCard('card_1'), findsNothing);
    expect(find.text('며느리가 방귀를 참느라 시무룩하게 서 있어요'), findsNothing);

    repository.startDelay!.complete();
    await tester.pump();
    await tester.pump();

    expect(repository.startCalls, <String>['session-1']);
    for (final String id in <String>['card_1', 'card_2', 'card_3', 'card_4']) {
      expect(trayCard(id), findsOneWidget);
    }
  });

  testWidgets('트레이는 서버가 섞어 준 순서 그대로다 - 프런트가 다시 섞지 않는다', (
    WidgetTester tester,
  ) async {
    await pumpRecap(tester, repository: _RecapSpyRepository());
    await tester.pump();

    // 서버가 준 순서: card_3, card_1, card_4, card_2. 프런트가 한 번 더
    // 섞으면 이 순서가 어긋나고, 다시 들어올 때마다 배치가 달라집니다
    // (서버는 세션마다 셔플 시드를 고정합니다).
    final List<double> xs = <double>[
      for (final String id in <String>['card_3', 'card_1', 'card_4', 'card_2'])
        tester.getTopLeft(trayCard(id)).dx,
    ];
    expect(
      xs,
      orderedEquals(<double>[...xs]..sort()),
      reason: '트레이가 서버 순서와 다르게 놓였습니다 - 프런트가 또 섞고 있습니다',
    );
  });

  testWidgets('카드 그림은 cardId 번호로 프런트 에셋을 찾는다', (WidgetTester tester) async {
    await pumpRecap(tester, repository: _RecapSpyRepository());
    await tester.pump();

    final Iterable<Image> images = tester.widgetList<Image>(find.byType(Image));
    final Set<String> assets = <String>{
      for (final Image image in images)
        if (image.image is AssetImage) (image.image as AssetImage).assetName,
    };
    expect(
      assets,
      containsAll(<String>[
        'assets/images/recap/banggui/scene_1.webp',
        'assets/images/recap/banggui/scene_2.webp',
        'assets/images/recap/banggui/scene_3.webp',
        'assets/images/recap/banggui/scene_4.webp',
      ]),
      reason: '서버는 그림 경로를 주지 않습니다 - cardId 의 번호로 에셋을 찾아야 합니다',
    );
  });

  testWidgets('순서 판정은 서버가 한다 - 오답이면 다시 권하고 낱말을 주지 않는다', (
    WidgetTester tester,
  ) async {
    final _RecapSpyRepository repository = _RecapSpyRepository()
      ..orderCorrect = false;
    await pumpRecap(tester, repository: repository);
    await tester.pump();

    await submitOrder(tester);

    expect(repository.submittedOrders, <List<String>>[
      <String>['card_3', 'card_1', 'card_4', 'card_2'],
    ], reason: 'cardId 전체를 놓인 순서대로 보내야 합니다');
    expect(find.text('거의 다 왔어! 처음에 무슨 일이 있었는지 볼까?'), findsOneWidget);
    // 1단계에 낱말이 남아 있으면 순서가 그대로 새어 나갑니다.
    for (final String word in <String>['참다', '쫓겨나다', '떨어뜨리다', '자신감']) {
      expect(find.text(word), findsNothing);
    }
    // 재시도 횟수 제한이 없으니 확인 버튼은 살아 있어야 합니다.
    expect(buttonWith(tester, '확인').onPressed, isNotNull);
  });

  testWidgets('정답이면 서버가 준 낱말로 2단계를 그린다', (WidgetTester tester) async {
    final _RecapSpyRepository repository = _RecapSpyRepository()
      ..keywords = <String>['참다', '쫓겨나다', '떨어뜨리다', '자신감'];
    await pumpRecap(tester, repository: repository);
    await tester.pump();

    await submitOrder(tester);

    expect(find.text('그림 아래 낱말을 넣어서 들려줄래?'), findsOneWidget);
    for (final String word in <String>['참다', '쫓겨나다', '떨어뜨리다', '자신감']) {
      expect(find.text(word), findsOneWidget);
    }
  });

  testWidgets('마이크가 실제로 녹음하고 STT 로 받아쓴다 - 자동으로 켜지지 않는다', (
    WidgetTester tester,
  ) async {
    final _RecapSpyRepository repository = _RecapSpyRepository();
    final _FakeRecorder recorder = _FakeRecorder();
    await pumpRecap(tester, repository: repository, recorder: recorder);
    await tester.pump();
    await submitOrder(tester);

    // 아이가 직접 누르는 것이 "내 차례"의 신호입니다. (PRD F-04)
    expect(recorder.starts, 0);
    expect(find.text('말하기'), findsOneWidget);

    await tester.tap(find.text('말하기'));
    await tester.pump();
    expect(recorder.starts, 1);
    expect(find.text('멈추기'), findsOneWidget);

    await tester.tap(find.text('멈추기'));
    await tester.pump();
    await tester.pump();

    expect(recorder.stops, 1);
    expect(repository.transcribeCalls, 1);
    expect(find.textContaining('며느리가 방귀를 참다가'), findsOneWidget);
    // 카드 4장 - 첫 장면은 마지막이 아니니 "다 했어"가 아니라 "다음"입니다.
    expect(buttonWith(tester, RecapStrings.next).onPressed, isNotNull);
  });

  testWidgets('무음(STT_EMPTY_TEXT)이면 다시 말하라고 안내하고 그 자리에서 재녹음한다', (
    WidgetTester tester,
  ) async {
    final _RecapSpyRepository repository = _RecapSpyRepository()
      ..sttFailure = const ServerFailure(
        message: '무음입니다',
        code: 'STT_EMPTY_TEXT',
      );
    final _FakeRecorder recorder = _FakeRecorder();
    await pumpRecap(tester, repository: repository, recorder: recorder);
    await tester.pump();
    await submitOrder(tester);
    await speak(tester);

    expect(find.text('잘 못 들었어요. 다시 말해 볼까?'), findsOneWidget);
    expect(
      find.widgetWithText(KidPrimaryButton, '다 했어'),
      findsNothing,
      reason: '보낼 글자가 없으면 완료로 넘어갈 수 없습니다',
    );

    // 다시 녹음하면 이번에는 받아쓰기가 됩니다.
    repository.sttFailure = null;
    await speak(tester);
    expect(recorder.starts, 2);
    expect(find.textContaining('며느리가 방귀를 참다가'), findsOneWidget);
  });

  testWidgets('완료는 retelling 을 부르고 서버가 준 별가루를 보여 준다', (
    WidgetTester tester,
  ) async {
    final _RecapSpyRepository repository = _RecapSpyRepository();
    await pumpRecap(tester, repository: repository);
    await tester.pump();
    await submitOrder(tester);
    await speakAllScenes(tester);

    await tester.tap(find.text('다 했어'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 이 가짜 서버는 장면마다 같은 텍스트를 돌려줍니다 - 4장면을 다 말하면
    // 그 텍스트가 4번 이어 붙어서 한 번만(/retelling 한 번) 올라갑니다.
    expect(repository.retellingTexts, <String>[
      List<String>.filled(4, '며느리가 방귀를 참다가 배를 떨어뜨렸어요.').join(' '),
    ]);
    expect(repository.retellingRawTexts, <String?>[
      List<String>.filled(4, '며느리가 방구를 참다가 배를 떨어뜨렸어요.').join(' '),
    ], reason: '교정 전 원문을 이어 붙여 sttRawText 로 되올려야 합니다');
    // 완료 화면은 한 덩어리 문구입니다 - 칭찬 아래에 실제 지급 수치가 붙습니다.
    expect(find.textContaining('이야기를 멋지게 들려줬어!'), findsOneWidget);
    expect(find.textContaining('별가루 3개'), findsOneWidget);
    expect(find.textContaining('새 아이템 1개'), findsOneWidget);
  });

  testWidgets('완료가 실패하면 활동을 다시 시키지 않고 다시 누를 수 있게 둔다', (
    WidgetTester tester,
  ) async {
    final _RecapSpyRepository repository = _RecapSpyRepository()
      ..retellingFailure = const NetworkFailure();
    await pumpRecap(tester, repository: repository);
    await tester.pump();
    await submitOrder(tester);
    await speakAllScenes(tester);

    await tester.tap(find.text('다 했어'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('다시 눌러'), findsOneWidget);
    expect(find.textContaining('며느리가 방귀를 참다가'), findsOneWidget);
    expect(
      buttonWith(tester, '다 했어').onPressed,
      isNotNull,
      reason: '네트워크가 끊겼다고 아이가 활동을 처음부터 다시 하면 안 됩니다',
    );

    // 다시 누르면 이번에는 저장됩니다.
    repository.retellingFailure = null;
    await tester.tap(find.text('다 했어'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('이야기를 멋지게 들려줬어!'), findsOneWidget);
    expect(repository.retellingTexts.length, 2);
  });

  testWidgets('409 RETELLING_BEFORE_ORDER 면 순서 단계로 되돌린다', (
    WidgetTester tester,
  ) async {
    final _RecapSpyRepository repository = _RecapSpyRepository()
      ..retellingFailure = const ServerFailure(
        message: '순서를 먼저 맞혀 주세요',
        code: 'RETELLING_BEFORE_ORDER',
      );
    await pumpRecap(tester, repository: repository);
    await tester.pump();
    await submitOrder(tester);
    await speakAllScenes(tester);

    await tester.tap(find.text('다 했어'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('확인'), findsOneWidget, reason: '순서 맞추기로 돌아와야 합니다');
    // 되돌아온 화면에 낱말이 남아 있으면 순서가 새어 나갑니다.
    for (final String word in <String>['참다', '쫓겨나다', '떨어뜨리다', '자신감']) {
      expect(find.text(word), findsNothing);
    }
  });

  testWidgets('409 SESSION_NOT_IN_PROGRESS 면 완료 화면으로 보낸다', (
    WidgetTester tester,
  ) async {
    final _RecapSpyRepository repository = _RecapSpyRepository()
      ..retellingFailure = const ServerFailure(
        message: '이미 끝난 세션입니다',
        code: 'SESSION_NOT_IN_PROGRESS',
      );
    await pumpRecap(tester, repository: repository);
    await tester.pump();
    await submitOrder(tester);
    await speakAllScenes(tester);

    await tester.tap(find.text('다 했어'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('이야기를 멋지게 들려줬어!'), findsOneWidget);
  });

  testWidgets('마치기는 재생 화면을 거치지 않고 홈으로 간다', (WidgetTester tester) async {
    // 이 화면은 재생 화면 아래 중첩 라우트입니다. pop 으로 물러서면 방금
    // 끝낸 재생 화면에 머물러 홈까지 도달하지 못합니다.
    final _RecapSpyRepository repository = _RecapSpyRepository();
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.playRecapOf('session-1'),
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => const Scaffold(body: Text('홈 화면')),
        ),
        GoRoute(
          path: AppRoutes.playPath,
          builder: (_, __) => const Scaffold(body: Text('재생 화면')),
          routes: <RouteBase>[
            GoRoute(
              path: 'recap',
              builder: (_, GoRouterState state) => PlayRecapPage(
                sessionId: state.pathParameters[AppRoutes.sessionIdParam]!,
                repository: repository,
                voiceRecorder: _FakeRecorder(),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pump();
    await submitOrder(tester);
    await speakAllScenes(tester);
    await tester.tap(find.text('다 했어'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('마치기'));
    await tester.pumpAndSettle();

    expect(find.text('홈 화면'), findsOneWidget);
    expect(find.text('재생 화면'), findsNothing);
    expect(find.byType(PlayRecapPage), findsNothing);
  });

  testWidgets('카드를 못 받아 오면 다시 시도할 수 있다', (WidgetTester tester) async {
    final _RecapSpyRepository repository = _RecapSpyRepository()
      ..startFailure = const NetworkFailure();
    await pumpRecap(tester, repository: repository);
    await tester.pump();

    expect(find.text('네트워크에 연결할 수 없습니다.'), findsOneWidget);

    repository.startFailure = null;
    await tester.tap(find.text('다시 불러오기'));
    await tester.pump();
    await tester.pump();

    expect(trayCard('card_1'), findsOneWidget);
    expect(repository.startCalls.length, 2);
  });
}

class _RecapSpyRepository implements PlayRepository {
  /// 서버가 섞어 준 순서. 프런트가 이 순서를 그대로 써야 합니다.
  static const List<PlayPostActivityCard> _cards = <PlayPostActivityCard>[
    PlayPostActivityCard(cardId: 'card_3', text: '배를 떨어뜨렸어요'),
    PlayPostActivityCard(cardId: 'card_1', text: '방귀를 참았어요'),
    PlayPostActivityCard(cardId: 'card_4', text: '고마워했어요'),
    PlayPostActivityCard(cardId: 'card_2', text: '갓이 날아갔어요'),
  ];

  final List<String> startCalls = <String>[];
  final List<List<String>> submittedOrders = <List<String>>[];
  final List<String> retellingTexts = <String>[];
  final List<String?> retellingRawTexts = <String?>[];
  int transcribeCalls = 0;

  /// 응답을 붙잡아 두고 로딩 상태를 관찰하는 데 씁니다.
  Completer<void>? startDelay;
  Failure? startFailure;
  Failure? sttFailure;
  Failure? retellingFailure;
  bool orderCorrect = true;
  List<String> keywords = const <String>['참다', '쫓겨나다', '떨어뜨리다', '자신감'];

  @override
  Future<PlayPostActivityStart> startPostActivity(String sessionId) async {
    startCalls.add(sessionId);
    if (startDelay != null) await startDelay!.future;
    final Failure? failure = startFailure;
    if (failure != null) throw failure;
    return const PlayPostActivityStart(cards: _cards, attemptCount: 0);
  }

  @override
  Future<PlayCardOrderResult> submitCardOrder(
    String sessionId, {
    required List<String> submittedOrder,
  }) async {
    submittedOrders.add(submittedOrder);
    return orderCorrect
        ? PlayCardOrderResult(correct: true, retellingKeywords: keywords)
        : const PlayCardOrderResult(correct: false);
  }

  @override
  Future<PlayRetellingResult> submitRetelling(
    String sessionId, {
    required String text,
    String? sttRawText,
  }) async {
    retellingTexts.add(text);
    retellingRawTexts.add(sttRawText);
    final Failure? failure = retellingFailure;
    if (failure != null) throw failure;
    return const PlayRetellingResult(
      sessionStatus: 'COMPLETED',
      stardust: PlayStardust(earned: 3, balance: 12),
      unlockedItems: <PlayUnlockedItem>[
        PlayUnlockedItem(itemId: 'item-1', name: '달 모자'),
      ],
    );
  }

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async {
    transcribeCalls++;
    final Failure? failure = sttFailure;
    if (failure != null) throw failure;
    return const PlayTranscription(
      text: '며느리가 방귀를 참다가 배를 떨어뜨렸어요.',
      confidence: .9,
      lowConfidence: false,
      rawText: '며느리가 방구를 참다가 배를 떨어뜨렸어요.',
    );
  }

  // ── 이 화면이 쓰지 않는 나머지 ──

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      throw UnimplementedError();

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) async =>
      throw UnimplementedError();

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      throw UnimplementedError();

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) async => const <PlayMessage>[];

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async => const PlaySpeechAudio(audioUrl: '');

  @override
  Future<PlayTurnResult> submitUtterance(
    String sessionId, {
    required String text,
    String? missionId,
    String? sttRawText,
    double? sttConfidence,
    int sttRetryCount = 0,
    String? idempotencyKey,
  }) async => throw UnimplementedError();

  @override
  Future<void> stop(String sessionId) async {}
}

class _FakeRecorder implements MissionVoiceRecorder {
  int starts = 0;
  int stops = 0;

  @override
  Future<bool> start() async {
    starts++;
    return true;
  }

  @override
  Future<Uint8List?> stop() async {
    stops++;
    return Uint8List.fromList(<int>[1, 2, 3]);
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}
