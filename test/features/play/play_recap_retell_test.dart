import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/features/play/domain/entities/play_session.dart';
import 'package:goodquestion/features/play/domain/repositories/play_repository.dart';
import 'package:goodquestion/features/play/presentation/views/play_recap_view.dart';
import 'package:goodquestion/features/play/presentation/voice/mission_voice_recorder.dart';

/// 2단계 "다시 말하기"를 **장면 하나씩 녹음**하는 상태 모델과, 그 답변에서
/// 켜지는 **낱말 체크**를 봅니다. 배치(채팅 로그가 어떻게 쌓이는지)는
/// `play_recap_view_test.dart` 가 지킵니다.
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

  /// 데모 모드(서버 없이) 전용. 장면 개수를 4로 가정한 곳을 잡아내려고
  /// 5장짜리 이야기를 여기서 씁니다.
  Future<void> pumpDemoRecap(
    WidgetTester tester, {
    required List<RecapSceneCard> cards,
    required List<String> keywords,
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
          sessionId: 'demo-session',
          sceneCards: cards,
          keywords: keywords,
        ),
      ),
    );
    await tester.pump();
  }

  Finder slot(int index) => find.byKey(ValueKey<String>('recap-slot-$index'));
  Finder trayCard(String id) => find.byKey(ValueKey<String>('recap-tray-$id'));

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

  Future<void> placeAllInOrder(WidgetTester tester, List<String> ids) async {
    // 좁은 화면의 트레이는 가로 스크롤이라 보이는 카드만 만들어집니다 -
    // 늘 지금 트레이에 있는 카드를 골라 제자리에 놓습니다.
    final List<String> remaining = List<String>.of(ids);
    while (remaining.isNotEmpty) {
      final String next = remaining.firstWhere(
        (String id) => trayCard(id).evaluate().isNotEmpty,
        orElse: () => remaining.first,
      );
      await place(tester, next, ids.indexOf(next));
      remaining.remove(next);
    }
  }

  /// 서버가 준 순서 그대로 자리에 놓고 확인을 눌러 2단계로 넘어갑니다.
  Future<void> submitOrder(
    WidgetTester tester, [
    List<String> ids = const <String>['card_1', 'card_2', 'card_3', 'card_4'],
  ]) async {
    for (int i = 0; i < ids.length; i++) {
      await place(tester, ids[i], i);
    }
    await tester.tap(find.text('확인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  /// 마이크를 눌러 녹음하고 다시 눌러 STT 까지 받습니다. 지금 장면 하나만
  /// 채웁니다 - 다음 장면으로 넘어가는 건 호출하는 쪽이 합니다.
  Future<void> speak(WidgetTester tester) async {
    await tester.tap(find.text('말하기'));
    await tester.pump();
    await tester.tap(find.text('멈추기'));
    await tester.pump();
    await tester.pump();
  }

  /// 낱말 칩. **체크 상태가 스크린리더 라벨에 들어 있습니다** — 켜짐과 꺼짐을
  /// 다른 finder 로 찾아야 "안 쓴 낱말에 체크가 켜졌다"를 잡을 수 있습니다.
  Finder keywordChip(String word, {required bool used}) =>
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Semantics &&
            widget.properties.label ==
                (used
                    ? RecapStrings.keywordUsed(word)
                    : RecapStrings.keywordUnused(word)),
      );

  testWidgets('장면 4개를 차례로 답하면 /retelling 이 한 번만, 이어 붙인 텍스트로 호출된다', (
    WidgetTester tester,
  ) async {
    final _ScriptedRepository repository = _ScriptedRepository()
      ..script.addAll(<PlayTranscription>[
        const PlayTranscription(
          text: '첫 장면 답이에요.',
          confidence: .9,
          lowConfidence: false,
        ),
        const PlayTranscription(
          text: '둘째 장면 답이에요.',
          confidence: .9,
          lowConfidence: false,
        ),
        const PlayTranscription(
          text: '셋째 장면 답이에요.',
          confidence: .9,
          lowConfidence: false,
        ),
        const PlayTranscription(
          text: '넷째 장면 답이에요.',
          confidence: .9,
          lowConfidence: false,
        ),
      ]);
    await pumpRecap(tester, repository: repository);
    await submitOrder(tester);

    for (int i = 0; i < 4; i++) {
      await speak(tester);
      final bool isLast = i == 3;
      await tester.tap(
        find.text(isLast ? RecapStrings.finish : RecapStrings.next),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      repository.transcribeCalls,
      4,
      reason: 'STT 는 장면마다 한 번씩 - 4번 불려야 합니다',
    );
    expect(repository.retellingCalls, 1, reason: '/retelling 은 정확히 한 번만 불립니다');
    expect(repository.retellingTexts, <String>[
      '첫 장면 답이에요. 둘째 장면 답이에요. 셋째 장면 답이에요. 넷째 장면 답이에요.',
    ]);
    expect(find.text('이야기를 멋지게 들려줬어!'), findsOneWidget);
  });

  testWidgets('중간 장면을 재녹음하면 그 장면만 덮어써지고 다른 장면 답변은 남는다', (
    WidgetTester tester,
  ) async {
    final _ScriptedRepository repository = _ScriptedRepository()
      ..script.addAll(<PlayTranscription>[
        const PlayTranscription(
          text: '첫 장면 원래 답.',
          confidence: .9,
          lowConfidence: false,
        ), // 장면 0
        const PlayTranscription(
          text: '둘째 장면 첫 시도.',
          confidence: .9,
          lowConfidence: false,
        ), // 장면 1 - 첫 시도
        const PlayTranscription(
          text: '둘째 장면 다시 말한 답.',
          confidence: .9,
          lowConfidence: false,
        ), // 장면 1 - 재녹음
        const PlayTranscription(
          text: '셋째 장면 답.',
          confidence: .9,
          lowConfidence: false,
        ), // 장면 2
        const PlayTranscription(
          text: '넷째 장면 답.',
          confidence: .9,
          lowConfidence: false,
        ), // 장면 3
      ]);
    await pumpRecap(tester, repository: repository);
    await submitOrder(tester);

    // 장면 0.
    await speak(tester);
    await tester.tap(find.text(RecapStrings.next));
    await tester.pump();

    // 장면 1 - 처음 답.
    await speak(tester);
    expect(find.textContaining('둘째 장면 첫 시도'), findsOneWidget);

    // 같은 장면에서 마이크를 다시 누르면 재녹음입니다 - 이전 답은 지워지고
    // 새 텍스트로 통째로 덮어써집니다. (낱말 체크도 같이 다시 계산되는지는
    // 아래 "재녹음해서 낱말을 빼면 체크가 꺼진다" 가 화면에서 확인합니다)
    await speak(tester);
    expect(find.textContaining('둘째 장면 다시 말한 답'), findsOneWidget);
    expect(find.textContaining('둘째 장면 첫 시도'), findsNothing);

    await tester.tap(find.text(RecapStrings.next));
    await tester.pump();

    // 장면 2, 3.
    await speak(tester);
    await tester.tap(find.text(RecapStrings.next));
    await tester.pump();
    await speak(tester);
    await tester.tap(find.text(RecapStrings.finish));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.retellingTexts, <String>[
      '첫 장면 원래 답. 둘째 장면 다시 말한 답. 셋째 장면 답. 넷째 장면 답.',
    ], reason: '재녹음 전 답은 남지 않고, 다른 장면 답은 그대로입니다');
  });

  testWidgets('한 장면을 건너뛰어도 나머지 답변으로 제출된다', (WidgetTester tester) async {
    const ServerFailure silence = ServerFailure(
      message: '무음입니다',
      code: 'STT_EMPTY_TEXT',
    );
    final _ScriptedRepository repository = _ScriptedRepository()
      ..script.addAll(<Object>[
        const PlayTranscription(
          text: '첫 장면 답.',
          confidence: .9,
          lowConfidence: false,
        ), // 장면 0
        silence, // 장면 1 - 시도 1 (실패)
        silence, // 장면 1 - 시도 2 (실패, 건너뛰기 가능)
        const PlayTranscription(
          text: '셋째 장면 답.',
          confidence: .9,
          lowConfidence: false,
        ), // 장면 2
        const PlayTranscription(
          text: '넷째 장면 답.',
          confidence: .9,
          lowConfidence: false,
        ), // 장면 3
      ]);
    await pumpRecap(tester, repository: repository);
    await submitOrder(tester);

    await speak(tester);
    await tester.tap(find.text(RecapStrings.next));
    await tester.pump();

    // 장면 1 - 한 번 실패로는 건너뛸 수 없습니다.
    await speak(tester);
    expect(find.text(RecapStrings.sttEmpty), findsOneWidget);
    expect(find.text(RecapStrings.skipScene), findsNothing);

    // 두 번째도 실패하면 건너뛰기가 뜹니다 - 마이크에 갇히지 않는 탈출구입니다.
    await speak(tester);
    expect(find.text(RecapStrings.skipScene), findsOneWidget);

    await tester.tap(find.text(RecapStrings.skipScene));
    await tester.pump();

    // 장면 2, 3.
    await speak(tester);
    await tester.tap(find.text(RecapStrings.next));
    await tester.pump();
    await speak(tester);
    await tester.tap(find.text(RecapStrings.finish));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.retellingTexts, <String>[
      '첫 장면 답. 셋째 장면 답. 넷째 장면 답.',
    ], reason: '건너뛴 장면은 빠지고 나머지만 순서대로 이어 붙습니다');
    expect(find.text('이야기를 멋지게 들려줬어!'), findsOneWidget);
  });

  testWidgets('답이 하나도 없으면 제출되지 않는다', (WidgetTester tester) async {
    const ServerFailure silence = ServerFailure(
      message: '무음입니다',
      code: 'STT_EMPTY_TEXT',
    );
    // 4 장면 × (2번 연속 실패해야 건너뛰기가 뜹니다) = 8번.
    final _ScriptedRepository repository = _ScriptedRepository()
      ..script.addAll(List<Object>.filled(8, silence));
    await pumpRecap(tester, repository: repository);
    await submitOrder(tester);

    for (int scene = 0; scene < 4; scene++) {
      await speak(tester);
      await speak(tester);
      await tester.tap(find.text(RecapStrings.skipScene));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(
      repository.retellingCalls,
      0,
      reason: '보낼 답이 하나도 없으면 /retelling 을 부르지 않습니다',
    );
    expect(find.text(RecapStrings.sttEmpty), findsOneWidget);
    expect(find.text('이야기를 멋지게 들려줬어!'), findsNothing);
  });

  testWidgets('장면이 5개인 이야기에서도 5단계로 돈다', (WidgetTester tester) async {
    const List<RecapSceneCard> fiveCards = <RecapSceneCard>[
      RecapSceneCard(id: 'a', title: '가', image: 'assets/images/recap/a.webp'),
      RecapSceneCard(id: 'b', title: '나', image: 'assets/images/recap/b.webp'),
      RecapSceneCard(id: 'c', title: '다', image: 'assets/images/recap/c.webp'),
      RecapSceneCard(id: 'd', title: '라', image: 'assets/images/recap/d.webp'),
      RecapSceneCard(id: 'e', title: '마', image: 'assets/images/recap/e.webp'),
    ];
    const List<String> fiveKeywords = <String>['하나', '둘', '셋', '넷', '다섯'];

    await pumpDemoRecap(tester, cards: fiveCards, keywords: fiveKeywords);
    await placeAllInOrder(tester, <String>['a', 'b', 'c', 'd', 'e']);
    await tester.tap(find.text('확인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // 장면이 4장이라고 박아 둔 곳이 있으면 다섯 번째에서 어긋납니다.
    for (int i = 0; i < 5; i++) {
      await tester.tap(find.text('말하기'));
      await tester.pump();
      final bool isLast = i == 4;
      final Finder button = find.text(
        isLast ? RecapStrings.finish : RecapStrings.next,
      );
      expect(button, findsOneWidget, reason: '${i + 1}번째 장면에서 다음 버튼을 못 찾았습니다');
      await tester.tap(button);
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('이야기를 멋지게 들려줬어!'), findsOneWidget);
  });

  // ── 낱말 체크 ────────────────────────────────────────────
  //
  // **판정이 아니라 격려 장식입니다.** 체크가 안 켜져도 다음으로 갈 수 있어야
  // 하고, 안 쓴 낱말에 체크가 켜지는 오탐이 못 쓴 것보다 훨씬 나쁩니다.

  testWidgets('낱말을 쓴 답변에는 체크가 켜지고, 안 쓴 답변에는 안 켜진다', (
    WidgetTester tester,
  ) async {
    final _ScriptedRepository repository = _ScriptedRepository()
      ..script.addAll(<PlayTranscription>[
        // 장면 0 낱말 "참다" - 활용형으로 썼습니다.
        const PlayTranscription(
          text: '며느리가 방귀를 참았어요.',
          confidence: .9,
          lowConfidence: false,
        ),
        // 장면 1 낱말 "쫓겨나다" - 뜻은 맞지만 그 낱말은 안 썼습니다.
        const PlayTranscription(
          text: '시아버지가 집에서 나가라고 했어요.',
          confidence: .9,
          lowConfidence: false,
        ),
      ]);
    await pumpRecap(tester, repository: repository);
    await submitOrder(tester);

    // 말하기 전에는 "이 말을 써 보자"는 안내입니다 - 체크는 꺼져 있습니다.
    expect(keywordChip('참다', used: false), findsOneWidget);
    expect(keywordChip('참다', used: true), findsNothing);

    await speak(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(keywordChip('참다', used: true), findsOneWidget);
    expect(keywordChip('참다', used: false), findsNothing);

    // 체크가 켜졌다고 다음으로 가는 조건이 되지는 않습니다 - 다음 버튼은
    // 말하기만 하면 삽니다.
    await tester.tap(find.text(RecapStrings.next));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await speak(tester);
    await tester.pump(const Duration(milliseconds: 400));
    // 낱말을 안 썼어도 체크만 꺼져 있을 뿐, 막지도 혼내지도 않습니다.
    expect(keywordChip('쫓겨나다', used: false), findsOneWidget);
    expect(keywordChip('쫓겨나다', used: true), findsNothing);
    expect(
      find.text(RecapStrings.next),
      findsOneWidget,
      reason: '낱말을 안 썼다고 다음으로 가는 길을 막으면 안 됩니다',
    );
  });

  testWidgets('재녹음해서 낱말을 빼면 체크가 꺼진다', (WidgetTester tester) async {
    final _ScriptedRepository repository = _ScriptedRepository()
      ..script.addAll(<PlayTranscription>[
        const PlayTranscription(
          text: '며느리가 방귀를 참았어요.',
          confidence: .9,
          lowConfidence: false,
        ),
        // 같은 장면 재녹음 - 이번엔 낱말이 빠졌습니다.
        const PlayTranscription(
          text: '그냥 서 있었어요.',
          confidence: .9,
          lowConfidence: false,
        ),
      ]);
    await pumpRecap(tester, repository: repository);
    await submitOrder(tester);

    await speak(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(keywordChip('참다', used: true), findsOneWidget);

    // 체크는 그 장면의 **최신 텍스트로만** 다시 계산합니다 - 이전 답과
    // 합집합하면 지운 말이 체크로 남습니다.
    await speak(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('그냥 서 있었어요'), findsOneWidget);
    expect(keywordChip('참다', used: true), findsNothing);
    expect(keywordChip('참다', used: false), findsOneWidget);
  });
}

/// 장면마다 다른 STT 결과를 순서대로 돌려주는 가짜 서버.
///
/// `play_recap_api_test.dart` 의 `_RecapSpyRepository` 는 매번 같은 텍스트를
/// 돌려줘서 "장면마다 다른 답"을 다루는 시나리오(재녹음·건너뛰기·이어
/// 붙이기)를 표현할 수 없습니다. 여기서는 [transcribeAudio] 호출 **순서대로**
/// [script] 를 재생합니다 - 원소가 [PlayTranscription] 이면 성공, [Failure]
/// 면 그 차례에 실패합니다.
class _ScriptedRepository implements PlayRepository {
  static const List<PlayPostActivityCard> cards = <PlayPostActivityCard>[
    PlayPostActivityCard(cardId: 'card_1', text: '방귀를 참았어요'),
    PlayPostActivityCard(cardId: 'card_2', text: '갓이 날아갔어요'),
    PlayPostActivityCard(cardId: 'card_3', text: '배를 떨어뜨렸어요'),
    PlayPostActivityCard(cardId: 'card_4', text: '고마워했어요'),
  ];

  static const List<String> keywords = <String>['참다', '쫓겨나다', '떨어뜨리다', '자신감'];

  final List<Object> script = <Object>[];
  int transcribeCalls = 0;

  final List<String> retellingTexts = <String>[];
  final List<String?> retellingRawTexts = <String?>[];
  int retellingCalls = 0;

  @override
  Future<PlayPostActivityStart> startPostActivity(String sessionId) async =>
      const PlayPostActivityStart(cards: cards, attemptCount: 0);

  @override
  Future<PlayCardOrderResult> submitCardOrder(
    String sessionId, {
    required List<String> submittedOrder,
  }) async =>
      const PlayCardOrderResult(correct: true, retellingKeywords: keywords);

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async {
    final Object result = script[transcribeCalls];
    transcribeCalls++;
    if (result is Failure) throw result;
    return result as PlayTranscription;
  }

  @override
  Future<PlayRetellingResult> submitRetelling(
    String sessionId, {
    required String text,
    String? sttRawText,
  }) async {
    retellingCalls++;
    retellingTexts.add(text);
    retellingRawTexts.add(sttRawText);
    return const PlayRetellingResult(sessionStatus: 'COMPLETED');
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
