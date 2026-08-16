import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/router/app_routes.dart';
import 'package:goodquestion/core/widgets/app_canvas.dart';
import 'package:goodquestion/core/widgets/kid_speech_bubble.dart';
import 'package:goodquestion/features/play/domain/entities/play_session.dart';
import 'package:goodquestion/features/play/domain/repositories/play_repository.dart';
import 'package:goodquestion/features/play/presentation/views/play_view.dart';
import 'package:goodquestion/features/play/presentation/voice/mission_voice_recorder.dart';
import 'package:goodquestion/features/play/presentation/voice/story_audio_player.dart';

/// 말하기가 끝나고 **말하기 후 활동으로 넘어가는 전환**만 보는 테스트.
///
/// 여기서 지키는 약속은 다섯 가지입니다.
/// 1. 이야기가 끝나면 화면이 곧바로 바뀌지 않고, 제목·한마디·`시작` 이 있는
///    전환 화면이 한 번 낀다
/// 2. 그 화면은 **뒤가 비치지 않는다** (직전 대사·마이크 패널이 남으면 안 됩니다)
/// 3. 가만히 둬도 저절로 넘어간다 (아이가 뭘 눌러야 넘어가면 안 됩니다)
/// 4. 기다리기 싫으면 `시작` 을 눌러 바로 넘어갈 수 있다
/// 5. 어느 쪽으로 넘어가든 후속 활동으로는 **한 번만** 간다
void main() {
  /// 후속 활동 화면이 몇 번 그려졌는지. `context.go` 가 두 번 나가면 이
  /// 숫자가 따라 올라갑니다.
  late int recapBuilds;
  late _SpyPlayer player;

  /// 재생 화면을 라우터 안에 띄웁니다.
  ///
  /// **[tester.pumpAndSettle] 로 띄우지 않습니다** - 전환 오버레이는 스스로
  /// 넘어가는 시계를 들고 있어서, 다 가라앉을 때까지 돌리면 오버레이를 보기도
  /// 전에 후속 활동으로 넘어가 버립니다.
  Future<void> pumpHandoff(
    WidgetTester tester, {
    Size size = const Size(1280, 720),
  }) async {
    recapBuilds = 0;
    player = _SpyPlayer();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.playOf('handoff-session'),
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => const Scaffold(body: Text('홈 화면')),
        ),
        GoRoute(
          path: AppRoutes.playPath,
          builder: (_, GoRouterState state) => PlayPage(
            sessionId: state.pathParameters[AppRoutes.sessionIdParam]!,
            repository: _PostActivityRepository(),
            voiceRecorder: const _FakeRecorder(),
            audioPlayer: player,
          ),
        ),
        GoRoute(
          path: AppRoutes.playRecapPath,
          builder: (_, __) {
            recapBuilds++;
            return const Scaffold(body: Text('후속 활동 화면'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    // resume() 응답을 받아 오는 한 프레임 + 오버레이가 올라오는 한 프레임.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('이야기가 끝나면 곧바로 넘어가지 않고 전환 화면이 한 번 낀다', (
    WidgetTester tester,
  ) async {
    await pumpHandoff(tester);

    expect(
      find.text(PlayStrings.toRecapTitle),
      findsOneWidget,
      reason: '화면이 통째로 바뀌는 자리라, 다음에 할 일의 이름을 먼저 대 줍니다',
    );
    expect(find.text(PlayStrings.toRecap), findsOneWidget);
    expect(
      find.text(PlayStrings.toRecapStart),
      findsOneWidget,
      reason: '넘어가는 방법이 눈에 보여야 아이가 화면을 더듬지 않습니다',
    );
    expect(
      find.text('후속 활동 화면'),
      findsNothing,
      reason: '전환을 보여 주는 동안에는 아직 넘어가지 않습니다',
    );
    expect(
      player.stopCount,
      greaterThan(0),
      reason: '전환 화면 뒤에서 이전 장면의 대사가 계속 흘러나오면 안 됩니다',
    );
  });

  testWidgets('전환 화면은 대화 화면을 통째로 덮는다', (WidgetTester tester) async {
    await pumpHandoff(tester);
    await tester.pump(const Duration(milliseconds: 700));

    // 반투명 막이면 직전 캐릭터 대사가 새 말풍선 위에 겹쳐 읽히고, 하단
    // 마이크 패널이 "질문이 끝나면 마이크가 켜져요"라고 거짓말을 하며,
    // 상단 컨트롤이 눌리지도 않으면서 밝게 남습니다. 그래서 **바탕이 화면을
    // 꽉 채워야** 합니다.
    expect(tester.getSize(find.byType(AppCanvas)), const Size(1280, 720));

    // 빈 자리를 눌러도 아무 일도 없습니다 - 뒤에 남은 마이크·닫기 버튼이
    // 눌려서도 안 되고, 숨은 탭 영역으로 넘어가서도 안 됩니다.
    await tester.tapAt(const Offset(640, 24));
    await tester.pump();

    expect(find.text('후속 활동 화면'), findsNothing);
    expect(recapBuilds, 0);
  });

  testWidgets('가만히 둬도 저절로 후속 활동으로 넘어간다', (WidgetTester tester) async {
    await pumpHandoff(tester);

    // 아무것도 누르지 않습니다. 글을 못 읽는 아이가 대상이라 `시작` 버튼을
    // 통과 조건으로 두면 이야기가 여기서 멈춥니다.
    await tester.pump(const Duration(milliseconds: 4600));
    await tester.pumpAndSettle();

    expect(find.text('후속 활동 화면'), findsOneWidget);
    expect(find.text(PlayStrings.toRecap), findsNothing);
    expect(recapBuilds, 1);
  });

  testWidgets('기다리기 싫으면 `시작` 을 눌러 바로 넘어간다', (WidgetTester tester) async {
    await pumpHandoff(tester);
    // 말풍선과 버튼이 올라오는 모션(600ms)만 끝내고, 자동으로 넘어가는 시각
    // (4500ms) 보다 한참 앞에서 누릅니다.
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text(PlayStrings.toRecapStart));
    await tester.pumpAndSettle();

    expect(
      find.text('후속 활동 화면'),
      findsOneWidget,
      reason: '`시작` 은 남은 기다림을 건너뛰는 지름길입니다',
    );
    expect(recapBuilds, 1);
  });

  testWidgets('`시작` 으로 넘어간 뒤 시계가 다시 화면을 넘기지 않는다', (WidgetTester tester) async {
    await pumpHandoff(tester);
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text(PlayStrings.toRecapStart));
    await tester.pumpAndSettle();
    // 눌러서 넘어간 뒤, 원래 자동으로 넘어갔을 시각을 한참 지나 봅니다.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(recapBuilds, 1, reason: '버튼과 시계가 겹쳐도 후속 활동으로는 한 번만 갑니다');
    expect(tester.takeException(), isNull);
  });

  testWidgets('전환 화면은 다음 활동의 정답을 한 글자도 비추지 않는다', (WidgetTester tester) async {
    await pumpHandoff(tester);

    // 바로 다음 활동이 "장면 그림을 이야기 순서대로 놓기"입니다. 장면 그림·
    // 제목·낱말이 여기 새어 나오면 그게 곧 정답입니다.
    // (`play_recap_view.dart` 의 RecapSceneCard.title)
    expect(
      find.descendant(
        of: find.byType(KidSpeechBubble),
        matching: find.byType(Text),
      ),
      findsOneWidget,
      reason: '말풍선 안의 글은 전환 한마디 하나뿐이어야 합니다',
    );
    expect(
      find.descendant(
        of: find.byType(KidSpeechBubble),
        matching: find.byType(Image),
      ),
      findsNothing,
    );
  });

  testWidgets('폰 폭에서는 제목·한마디·버튼이 세로로 쌓이고 잘리지 않는다', (WidgetTester tester) async {
    await pumpHandoff(tester, size: const Size(390, 844));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text(PlayStrings.toRecapTitle), findsOneWidget);
    expect(find.text(PlayStrings.toRecap), findsOneWidget);
    expect(find.text(PlayStrings.toRecapStart), findsOneWidget);

    // 위에서 아래로: 제목 → 말풍선 → 시작.
    final double title = tester
        .getCenter(find.text(PlayStrings.toRecapTitle))
        .dy;
    final double line = tester.getCenter(find.text(PlayStrings.toRecap)).dy;
    final double start = tester
        .getCenter(find.text(PlayStrings.toRecapStart))
        .dy;
    expect(title, lessThan(line));
    expect(line, lessThan(start));

    // 넘치면 여기서 RenderFlex overflow 가 잡힙니다.
    expect(tester.takeException(), isNull);
  });

  testWidgets('폰 가로처럼 세로가 짧아도 `시작` 이 화면 밖으로 밀리지 않는다', (
    WidgetTester tester,
  ) async {
    await pumpHandoff(tester, size: const Size(844, 390));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text(PlayStrings.toRecapTitle), findsOneWidget);
    expect(find.text(PlayStrings.toRecap), findsOneWidget);

    // 버튼이 화면 안에 온전히 들어와야 누를 수 있습니다.
    final Rect start = tester.getRect(find.text(PlayStrings.toRecapStart));
    expect(start.bottom, lessThanOrEqualTo(390));

    expect(tester.takeException(), isNull);
  });
}

/// 말하기가 끝난 세션. `resume` 이 곧바로 후속 활동 단계를 돌려줍니다 -
/// 마지막 장면이 닫히면 화면이 다시 `resume` 을 부르고 이 응답을 받습니다.
class _PostActivityRepository implements PlayRepository {
  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      const PlaySessionSnapshot(
        phase: PlayPhase.postActivity,
        currentScene: null,
      );

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) async =>
      const PlaySessionSnapshot(
        phase: PlayPhase.postActivity,
        currentScene: null,
      );

  @override
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) async => const <PlayMessage>[];

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(text: '', audioUrl: null, alreadyOpened: true);

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async =>
      const PlayTranscription(
        text: '이렇게 해 보면 좋겠어',
        confidence: .9,
        lowConfidence: false,
      );

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async => const PlaySpeechAudio(audioUrl: 'stub://handoff');

  @override
  Future<PlayTurnResult> submitUtterance(
    String sessionId, {
    required String text,
    String? missionId,
    String? sttRawText,
    double? sttConfidence,
    int sttRetryCount = 0,
    String? idempotencyKey,
  }) async => const PlayTurnResult(
    characterText: '고마워!',
    characterAudioUrl: null,
    mission: null,
    sceneTransition: PlaySceneTransition(
      next: PlayTransitionTarget.postActivity,
      closingReason: 'GOAL_MET',
    ),
  );

  @override
  Future<PlayPostActivityStart> startPostActivity(String sessionId) async =>
      const PlayPostActivityStart(
        cards: <PlayPostActivityCard>[],
        attemptCount: 0,
      );

  @override
  Future<PlayCardOrderResult> submitCardOrder(
    String sessionId, {
    required List<String> submittedOrder,
  }) async => const PlayCardOrderResult(correct: true);

  @override
  Future<PlayRetellingResult> submitRetelling(
    String sessionId, {
    required String text,
    String? sttRawText,
  }) async => const PlayRetellingResult(sessionStatus: 'COMPLETED');

  @override
  Future<void> stop(String sessionId) async {}
}

class _FakeRecorder implements MissionVoiceRecorder {
  const _FakeRecorder();

  @override
  Future<bool> start() async => true;

  @override
  Future<Uint8List?> stop() async => Uint8List.fromList(<int>[1, 2, 3]);

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

/// 소리를 실제로 끊었는지만 세어 보는 재생기.
class _SpyPlayer implements StoryAudioPlayer {
  int stopCount = 0;

  @override
  Stream<Duration> get onPosition => const Stream<Duration>.empty();

  @override
  bool get canResume => false;

  @override
  Future<void> playUrl(String url) async {}

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async => stopCount++;

  @override
  Future<void> dispose() async {}
}
