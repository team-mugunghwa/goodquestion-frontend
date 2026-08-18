import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/router/app_routes.dart';
import 'package:goodquestion/core/theme/app_spacing.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/core/widgets/kid_button.dart';
import 'package:goodquestion/features/free_talk/domain/entities/free_talk.dart';
import 'package:goodquestion/features/free_talk/presentation/views/free_talk_view.dart';
import 'package:goodquestion/features/free_talk/presentation/widgets/free_talk_farewell.dart';
import 'package:goodquestion/features/play/presentation/voice/story_audio_player.dart';

import 'fakes.dart';

const FreeTalkCharacter _character = FreeTalkCharacter(
  characterId: 'c-1',
  name: '방귀쟁이 며느리',
  characterKey: 'daughter_in_law',
);

/// 확인 카드가 내놓는 세 갈래. 순서까지 이 순서여야 합니다 — 되돌아가는 쪽이
/// 맨 위입니다.
const List<String> _exitOptions = <String>['더 이야기하기', '인사하고 나가기', '바로 나가기'];

const FreeTalkTurn _endingTurn = FreeTalkTurn(
  characterMessage: FreeTalkSpeech(
    text: '오늘 참 즐거웠어. 다음에 또 보자!',
    audioUrl: '/tts/last.mp3',
  ),
  turnCount: 10,
  ended: true,
);

void main() {
  Future<void> pumpTalk(
    WidgetTester tester, {
    required FakeFreeTalkRepository repository,
    FakeVoicePlayRepository? voice,
    StoryAudioPlayer audioPlayer = const FakeAudioPlayer(),
    Size size = const Size(1280, 720),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FreeTalkPage(
          storyId: 'story-1',
          characterId: 'c-1',
          repository: repository,
          voiceRepository: voice ?? FakeVoicePlayRepository(),
          initialCharacter: _character,
          voiceRecorder: const FakeVoiceRecorder(),
          audioPlayer: audioPlayer,
        ),
      ),
    );
    await tester.pump();
  }

  /// 진짜 [GoRouter] 위에 띄웁니다.
  ///
  /// "홈으로 갔다"를 확인하려면 라우터가 있어야 합니다 — 없으면 화면이
  /// `maybePop` 으로 조용히 제자리에 남아서, 안 나간 것을 못 나간 것으로도
  /// 잘 나간 것으로도 읽을 수 없습니다.
  Future<void> pumpTalkOnRouter(
    WidgetTester tester, {
    required FakeFreeTalkRepository repository,
  }) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.freeTalkChatOf('story-1', 'c-1'),
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => const Scaffold(body: Text('홈 화면')),
        ),
        GoRoute(
          path: AppRoutes.freeTalkChatPath,
          builder: (_, GoRouterState state) => FreeTalkPage(
            storyId: state.pathParameters[AppRoutes.storyIdParam]!,
            characterId: state.pathParameters[AppRoutes.characterIdParam]!,
            repository: repository,
            voiceRepository: FakeVoicePlayRepository(),
            initialCharacter: _character,
            voiceRecorder: const FakeVoiceRecorder(),
            audioPlayer: const FakeAudioPlayer(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pump();
  }

  /// 확인 카드를 띄웁니다.
  Future<void> openExitPrompt(WidgetTester tester) async {
    await tester.tap(find.byTooltip('나가기'));
    await tester.pump();
  }

  /// 캐릭터 대사가 끝나 아이 차례가 될 때까지 밀어 줍니다.
  Future<void> settleTurn(WidgetTester tester) async {
    for (int i = 0; i < 3; i++) {
      await tester.pump();
    }
  }

  /// 마이크를 멈추고 변환 결과를 "맞아요"로 보냅니다.
  Future<void> speakAndConfirm(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('마이크 켜짐'));
    await settleTurn(tester);
    await tester.tap(find.text('맞아요'));
    await settleTurn(tester);
  }

  testWidgets('첫 대사를 말풍선에 띄우고 마이크를 넘긴다', (WidgetTester tester) async {
    await pumpTalk(tester, repository: FakeFreeTalkRepository());
    await settleTurn(tester);

    expect(find.text('방귀쟁이 며느리의 질문'), findsOneWidget);
    expect(find.text('또 왔구나! 오늘은 무슨 얘기 할까?'), findsOneWidget);
    expect(find.bySemanticsLabel('마이크 켜짐'), findsOneWidget);
  });

  testWidgets('학습 화면의 진행바·장면 표시를 그리지 않는다', (WidgetTester tester) async {
    await pumpTalk(tester, repository: FakeFreeTalkRepository());
    await settleTurn(tester);

    // 나가기·다시 듣기·소리만 남습니다. 멈춤(학습 화면 전용)도 없습니다.
    expect(find.byTooltip('나가기'), findsOneWidget);
    expect(find.byTooltip('다시 듣기'), findsOneWidget);
    expect(find.byTooltip('소리 끄기'), findsOneWidget);
    expect(find.byTooltip('잠시 멈춤'), findsNothing);
    // 진행바는 이 Semantics 라벨로 자기를 알립니다. 그 라벨이 없어야 합니다.
    expect(find.bySemanticsLabel('이야기 진행'), findsNothing);
  });

  testWidgets('남은 턴 수를 화면 어디에도 적지 않는다', (WidgetTester tester) async {
    // 세는 순간 대화가 과제가 됩니다(설계 결정).
    await pumpTalk(
      tester,
      repository: FakeFreeTalkRepository(
        turns: const <FreeTalkTurn>[
          FreeTalkTurn(
            characterMessage: FreeTalkSpeech(
              text: '재밌었겠다!',
              audioUrl: '/tts/turn.mp3',
            ),
            turnCount: 7,
            ended: false,
          ),
        ],
      ),
    );
    await settleTurn(tester);
    await speakAndConfirm(tester);

    expect(find.textContaining('턴'), findsNothing);
    expect(find.textContaining('남은'), findsNothing);
    expect(find.textContaining('10'), findsNothing);
  });

  testWidgets('말한 내용을 먼저 보여 주고 확인해야 보낸다', (WidgetTester tester) async {
    final FakeFreeTalkRepository repository = FakeFreeTalkRepository();
    await pumpTalk(tester, repository: repository);
    await settleTurn(tester);

    // 녹음 끝내기 → 변환 결과 확인 화면
    await tester.tap(find.bySemanticsLabel('마이크 켜짐'));
    await settleTurn(tester);

    expect(find.text('이렇게 들었어요'), findsOneWidget);
    expect(find.text('나는 방귀가 세서 좋아!'), findsOneWidget);
    // 아직 안 보냈습니다 - 오인식을 되돌릴 수 있는 유일한 시점입니다.
    expect(repository.sentTexts, isEmpty);

    await tester.tap(find.text('맞아요'));
    await settleTurn(tester);

    expect(repository.sentTexts, <String>['나는 방귀가 세서 좋아!']);
    // Idempotency-Key 없이 보내지 않습니다.
    expect(repository.sentKeys.single, isNotNull);
    expect(find.text('그랬구나!'), findsOneWidget);
  });

  testWidgets('"다시 말할래요"를 고르면 보내지 않고 다시 녹음한다', (WidgetTester tester) async {
    final FakeFreeTalkRepository repository = FakeFreeTalkRepository();
    await pumpTalk(tester, repository: repository);
    await settleTurn(tester);
    await tester.tap(find.bySemanticsLabel('마이크 켜짐'));
    await settleTurn(tester);

    await tester.tap(find.text('다시 말할래요'));
    await settleTurn(tester);

    expect(repository.sentTexts, isEmpty);
    expect(find.bySemanticsLabel('마이크 켜짐'), findsOneWidget);
  });

  testWidgets('ended=true 여도 마무리 대사를 다 읽기 전에는 화면을 넘기지 않는다', (
    WidgetTester tester,
  ) async {
    // 낭독이 끝나기 전에 엔드카드가 뜨면 인사가 잘립니다.
    final ControlledAudioPlayer player = ControlledAudioPlayer();
    final FakeFreeTalkRepository repository = FakeFreeTalkRepository(
      turns: const <FreeTalkTurn>[_endingTurn],
    );
    await pumpTalk(tester, repository: repository, audioPlayer: player);
    await settleTurn(tester);

    // 첫 대사를 다 읽어야 아이 차례가 됩니다.
    expect(find.bySemanticsLabel('마이크 켜짐'), findsNothing);
    player.finish();
    await settleTurn(tester);
    expect(find.bySemanticsLabel('마이크 켜짐'), findsOneWidget);

    await speakAndConfirm(tester);

    expect(find.text('오늘 참 즐거웠어. 다음에 또 보자!'), findsOneWidget);
    expect(find.text('또 만나자!'), findsNothing);

    player.finish();
    await settleTurn(tester);

    expect(find.text('또 만나자!'), findsOneWidget);
    expect(find.text('홈으로'), findsOneWidget);
    expect(find.text('이야기 보기'), findsOneWidget);
    // 서버가 이미 닫은 대화에는 end 를 부르지 않습니다 - 인사가 두 번 됩니다.
    expect(repository.endCalls, 0);
  });

  testWidgets('나가기를 누르면 고를 수 있는 길이 셋이다', (WidgetTester tester) async {
    await pumpTalk(tester, repository: FakeFreeTalkRepository());
    await settleTurn(tester);

    // 대조군 — 카드를 열기 전에는 셋 다 화면에 없습니다. 이걸 안 보면 아래
    // 검사가 "원래부터 있던 글자"를 보고 통과할 수 있습니다.
    for (final String label in _exitOptions) {
      expect(find.text(label), findsNothing);
    }

    await openExitPrompt(tester);

    expect(find.text('이야기를 그만할까?'), findsOneWidget);
    for (final String label in _exitOptions) {
      expect(find.text(label), findsOneWidget);
    }
    // 인사가 이제 고르는 것이 됐으니, 본문이 "인사하고 보내 준다"고 단정하면
    // 한쪽 갈래에 대해 거짓말이 됩니다.
    expect(find.text('인사를 듣고 가도 되고, 바로 나가도 돼.'), findsOneWidget);
    expect(find.text('인사하고 끝내기'), findsNothing);
  });

  testWidgets('선택지가 셋이 되어도 아이 손가락 크기를 지킨다', (WidgetTester tester) async {
    // 세로로 쌓았으니 좁아지는 것이 아니라 카드가 길어져야 합니다.
    await pumpTalk(tester, repository: FakeFreeTalkRepository());
    await settleTurn(tester);
    await openExitPrompt(tester);

    final Size keep = tester.getSize(
      find.widgetWithText(KidPrimaryButton, _exitOptions[0]),
    );
    expect(keep.height, AppSizes.tapChildPrimary);
    // 카드 안쪽 340 에서 좌우 여백 24 를 두 번 뺀 값. 여백을 빼먹으면 여기가
    // 340 으로 잡혀 실제보다 넓다고 착각합니다.
    expect(keep.width, 340 - AppSpacing.lg * 2);

    for (final String label in _exitOptions.sublist(1)) {
      final Size option = tester.getSize(
        find.widgetWithText(KidSecondaryButton, label),
      );
      expect(option.height, AppSizes.tapChildSecondary);
      expect(option.width, keep.width);
    }
  });

  testWidgets('가로로 누운 작은 화면에서도 카드가 넘치지 않는다', (WidgetTester tester) async {
    // 선택지가 늘어 카드가 길어졌습니다. 세로가 모자란 화면에서 잘려 버리면
    // 마지막 갈래가 아예 없는 것과 같습니다 — 밀려서 스크롤돼야 합니다.
    await pumpTalk(
      tester,
      repository: FakeFreeTalkRepository(),
      size: const Size(640, 360),
    );
    await settleTurn(tester);
    await openExitPrompt(tester);

    for (final String label in _exitOptions) {
      expect(find.text(label), findsOneWidget);
    }
    // RenderFlex 오버플로는 예외로 올라옵니다. 눈으로 안 보고도 잡히는
    // 유일한 신호라 여기서 받습니다.
    expect(tester.takeException(), isNull);
  });

  testWidgets('"인사하고 나가기"는 인사를 받아 온 뒤 끝낸다', (WidgetTester tester) async {
    final FakeFreeTalkRepository repository = FakeFreeTalkRepository(
      closing: const FreeTalkSpeech(
        text: '벌써 가려고? 잘 가, 또 놀러 와!',
        audioUrl: '/tts/bye.mp3',
      ),
    );
    await pumpTalk(tester, repository: repository);
    await settleTurn(tester);

    await openExitPrompt(tester);
    expect(find.text('이야기를 그만할까?'), findsOneWidget);

    // 잘못 눌렀으면 되돌아옵니다.
    await tester.tap(find.text('더 이야기하기'));
    await tester.pump();
    expect(find.text('이야기를 그만할까?'), findsNothing);
    expect(repository.endCalls, 0);

    await openExitPrompt(tester);
    await tester.tap(find.text('인사하고 나가기'));
    await settleTurn(tester);
    await settleTurn(tester);

    expect(repository.endCalls, 1);
    // 이쪽은 닫기만 하는 경로를 타지 않습니다 — 인사를 지어 오는 요청 안에
    // 대화를 닫는 일까지 들어 있습니다.
    expect(repository.leaveCalls, 0);
    expect(find.text('또 만나자!'), findsOneWidget);
    // 인사는 말풍선에서도 한 번 읽히므로 엔드카드 안에서 찾습니다.
    expect(
      find.descendant(
        of: find.byType(FreeTalkFarewellScreen),
        matching: find.text('벌써 가려고? 잘 가, 또 놀러 와!'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('"바로 나가기"는 인사도 기다림도 없이 홈으로 간다', (WidgetTester tester) async {
    // 닫기 요청을 **끝나지 않게** 붙잡아 둡니다. 응답을 기다리는 구현이라면
    // 홈이 뜨지 않으므로, "기다리지 않는다"가 여기서 실제로 검사됩니다.
    final Completer<void> gate = Completer<void>();
    final FakeFreeTalkRepository repository = FakeFreeTalkRepository(
      leaveGate: gate,
    );
    await pumpTalkOnRouter(tester, repository: repository);
    await settleTurn(tester);

    await openExitPrompt(tester);
    await tester.tap(find.text('바로 나가기'));
    await tester.pumpAndSettle();

    expect(repository.leaveCalls, 1);
    // 인사를 지어 오는 경로는 타지 않습니다 — 그게 이 갈래의 존재 이유입니다.
    expect(repository.endCalls, 0);
    expect(find.text('또 만나자!'), findsNothing);
    expect(find.text('홈 화면'), findsOneWidget);

    // 붙잡아 둔 요청을 풀어 줍니다. 이 시점의 화면은 이미 홈입니다.
    gate.complete();
    await tester.pump();
    expect(find.text('홈 화면'), findsOneWidget);
  });

  testWidgets('닫기 요청이 실패해도 아이는 홈으로 나간다', (WidgetTester tester) async {
    final FakeFreeTalkRepository repository = FakeFreeTalkRepository(
      leaveError: const ServerFailure(message: '서버 오류', code: 'UNKNOWN'),
    );
    await pumpTalkOnRouter(tester, repository: repository);
    await settleTurn(tester);

    await openExitPrompt(tester);
    await tester.tap(find.text('바로 나가기'));
    await tester.pumpAndSettle();

    // 부르기는 불렀습니다. 안 부르고 나가면 대화가 열린 채로 남습니다.
    expect(repository.leaveCalls, 1);
    expect(find.text('홈 화면'), findsOneWidget);
    // 실패는 아이에게 보이지 않습니다 — 테스트 밖으로 새어 나오지도 않아야
    // 합니다(삼키지 않으면 여기서 잡힙니다).
    expect(tester.takeException(), isNull);
  });

  testWidgets('시작에 실패하면 다시 시도할 수 있다', (WidgetTester tester) async {
    await pumpTalk(
      tester,
      repository: FakeFreeTalkRepository(
        startError: const ServerFailure(message: '서버 오류', code: 'UNKNOWN'),
      ),
    );
    await settleTurn(tester);

    expect(find.text('지금은 이야기를 시작하지 못했어. 다시 해볼까?'), findsOneWidget);
  });

  testWidgets('목소리를 못 알아들어도 화면을 갈아엎지 않고 다시 말하게 둔다', (
    WidgetTester tester,
  ) async {
    await pumpTalk(
      tester,
      repository: FakeFreeTalkRepository(),
      voice: FakeVoicePlayRepository(
        transcribeError: const ServerFailure(
          message: '무음',
          code: 'STT_EMPTY_TEXT',
        ),
      ),
    );
    await settleTurn(tester);
    await tester.tap(find.bySemanticsLabel('마이크 켜짐'));
    await settleTurn(tester);

    expect(find.text('잘 못 들었어요. 다시 말해 볼까?'), findsOneWidget);
    // 대화 화면 그대로입니다 - 전면 에러 화면이 아닙니다.
    expect(find.text('방귀쟁이 며느리의 질문'), findsOneWidget);
  });

  testWidgets('"또 만나자" 에서 홈으로 나갈 수 있다', (WidgetTester tester) async {
    await pumpTalkOnRouter(
      tester,
      repository: FakeFreeTalkRepository(
        turns: const <FreeTalkTurn>[_endingTurn],
      ),
    );
    await settleTurn(tester);
    await speakAndConfirm(tester);
    expect(find.text('또 만나자!'), findsOneWidget);

    await tester.tap(find.text('홈으로'));
    await tester.pumpAndSettle();

    expect(find.text('홈 화면'), findsOneWidget);
  });
}
