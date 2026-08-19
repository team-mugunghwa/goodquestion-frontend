import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/router/app_routes.dart';
import 'package:goodquestion/features/play/data/stt_choice_catalog.dart';
import 'package:goodquestion/features/play/domain/entities/play_session.dart';
import 'package:goodquestion/features/play/domain/repositories/play_repository.dart';
import 'package:goodquestion/features/play/presentation/views/play_view.dart';
import 'package:goodquestion/features/play/presentation/voice/mission_voice_recorder.dart';
import 'package:goodquestion/features/play/presentation/voice/story_audio_player.dart';

void main() {
  Future<void> pumpPlay(
    WidgetTester tester, {
    PlayRepository? repository,
    StoryAudioPlayer audioPlayer = const _FakeAudioPlayer(),
    bool settle = true,
    int? totalScenes,
    String question = '친구가 속상해할 때는 어떻게 하면 좋을까?',
    Size size = const Size(1280, 720),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: PlayPage(
          sessionId: 'preview-session',
          characterName: '토리',
          question: question,
          totalScenes: totalScenes,
          repository: repository,
          voiceRecorder: const _FakeVoiceRecorder(),
          audioPlayer: audioPlayer,
        ),
      ),
    );
    // repository 가 있으면 resume() 이 끝날 때까지 한 프레임 더 필요합니다.
    // 데모 모드(테스트 대부분)는 동기 경로라 pump() 로 충분합니다.
    // STORY 내레이션처럼 스스로 다음 장면을 계속 부르는 반복 흐름은
    // settle: false 로 받아 호출부가 직접 pump 횟수를 제어합니다.
    if (repository != null && settle) await tester.pumpAndSettle();
  }

  /// 라우터 안에서 재생 화면을 띄웁니다.
  ///
  /// 나가기는 `context.go` 로 홈에 갑니다(이 화면은 go 로 들어와 스택에
  /// 되돌아갈 화면이 없습니다). 그래서 나가기 관련 테스트는 라우터가 있어야
  /// 합니다.
  Future<void> pumpPlayInRouter(
    WidgetTester tester, {
    required PlayRepository repository,
  }) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.playOf('preview-session'),
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.home,
          builder: (_, __) => const Scaffold(body: Text('홈 화면')),
        ),
        GoRoute(
          path: AppRoutes.playPath,
          builder: (_, GoRouterState state) => PlayPage(
            sessionId: state.pathParameters[AppRoutes.sessionIdParam]!,
            repository: repository,
            voiceRecorder: const _FakeVoiceRecorder(),
            audioPlayer: const _FakeAudioPlayer(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('좌측 캐릭터와 머리 우측의 한 문장 질문을 보여준다', (WidgetTester tester) async {
    await pumpPlay(tester);

    expect(find.text('토리'), findsOneWidget);
    expect(find.text('토리의 질문'), findsOneWidget);
    expect(find.text('친구가 속상해할 때는 어떻게 하면 좋을까?'), findsOneWidget);
    expect(find.text('질문을 듣고 있어요'), findsOneWidget);
    expect(find.text('질문이 끝나면 마이크가 켜져요.'), findsOneWidget);
  });

  testWidgets('질문이 끝나면 마이크가 자동으로 켜진다', (WidgetTester tester) async {
    await pumpPlay(tester);

    expect(find.bySemanticsLabel('마이크 준비 중'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.bySemanticsLabel('마이크 켜짐'), findsOneWidget);
    expect(find.textContaining('잘 듣고 있어요'), findsOneWidget);
    expect(find.text('나는 이렇게 생각해요…'), findsOneWidget);
  });

  testWidgets('다시 듣기와 일시정지 동작이 명확하다', (WidgetTester tester) async {
    await pumpPlay(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    await tester.tap(find.byTooltip('다시 듣기'));
    await tester.pump();
    expect(find.text('질문을 듣고 있어요'), findsOneWidget);

    await tester.tap(find.byTooltip('잠시 멈춤'));
    await tester.pump();
    expect(find.text('이야기를 잠시 멈췄어요'), findsOneWidget);

    await tester.tap(find.text('계속 듣기'));
    await tester.pump();
    expect(find.text('이야기를 잠시 멈췄어요'), findsNothing);
  });

  testWidgets('나가기는 멈춤 화면과 같은 카드로 묻는다 - 문구만 다르다', (WidgetTester tester) async {
    await pumpPlay(tester);

    await tester.tap(find.byTooltip('나가기'));
    await tester.pumpAndSettle();

    expect(find.text('이야기에서 나갈까요?'), findsOneWidget);
    // 나가도 듣던 자리는 남습니다 - 겁주는 문구로 나가기를 막으면 안 됩니다.
    expect(find.text('여기까지 들은 곳을 기억해 둘게요. 홈에서 이어 들을 수 있어요.'), findsOneWidget);
    expect(find.text('계속 듣기'), findsOneWidget);
    expect(find.text('나가기'), findsOneWidget);
    // 멈춤 문구가 아니라 나가기 문구입니다.
    expect(find.text('이야기를 잠시 멈췄어요'), findsNothing);
  });

  testWidgets('멈춤 버튼으로 뜬 카드는 멈춤 문구를 쓴다 - 나가기와 섞이지 않는다', (
    WidgetTester tester,
  ) async {
    await pumpPlay(tester);

    await tester.tap(find.byTooltip('잠시 멈춤'));
    await tester.pumpAndSettle();

    expect(find.text('이야기를 잠시 멈췄어요'), findsOneWidget);
    expect(find.text('이야기 나가기'), findsOneWidget);
    expect(find.text('이야기에서 나갈까요?'), findsNothing);
  });

  testWidgets('나가기로 뜬 카드에서 계속 듣기를 누르면 이야기로 돌아온다', (WidgetTester tester) async {
    await pumpPlay(tester);

    await tester.tap(find.byTooltip('나가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('계속 듣기'));
    await tester.pumpAndSettle();

    expect(find.text('이야기에서 나갈까요?'), findsNothing);
    expect(find.byType(PlayPage), findsOneWidget);
  });

  testWidgets('나가기는 세션을 끝내지 않는다 - 홈에서 이어 들을 수 있어야 한다', (
    WidgetTester tester,
  ) async {
    final _StopSpyRepository repository = _StopSpyRepository();
    await pumpPlayInRouter(tester, repository: repository);

    await tester.tap(find.byTooltip('나가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();

    expect(
      repository.stoppedSessionId,
      isNull,
      reason:
          'stop 은 세션을 STOPPED 로 바꿔 이어하기 목록에서 지웁니다 - 되돌릴 수 없어서 '
          '화면을 벗어나는 것만으로 부르면 안 됩니다',
    );
  });

  testWidgets('나가기를 확정하면 재생 화면에서 실제로 빠져나온다', (WidgetTester tester) async {
    // 이 화면은 홈·이야기 상세에서 go 로 들어와 스택에 되돌아갈 화면이
    // 없습니다. pop 계열로 나가려 하면 조용히 아무 일도 일어나지 않아,
    // 아이는 나가기를 눌러도 그대로 남습니다.
    await pumpPlayInRouter(tester, repository: _StopSpyRepository());
    expect(find.byType(PlayPage), findsOneWidget);

    await tester.tap(find.byTooltip('나가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();

    expect(find.byType(PlayPage), findsNothing);
    expect(find.text('홈 화면'), findsOneWidget);
  });

  testWidgets('무음(STT_EMPTY_TEXT)이면 화면을 안 바꾸고 마이크 옆에 안내만 하고, '
      '다시 말하면 재시도 횟수를 실어 보낸다', (WidgetTester tester) async {
    final _SttRetrySpyRepository repository = _SttRetrySpyRepository();
    await pumpPlay(tester, repository: repository);

    // 듣기 화면에 들어오면 마이크가 자동으로 녹음을 시작합니다.
    expect(find.byTooltip('말하기 완료'), findsOneWidget);

    // 첫 녹음은 무음으로 실패합니다.
    await tester.tap(find.byTooltip('말하기 완료'));
    await tester.pumpAndSettle();

    // 화면이 에러 화면으로 안 바뀌고, 마이크 옆에만 안내가 붙습니다.
    expect(find.text('잘 못 들었어요. 다시 말해 볼까?'), findsOneWidget);
    expect(find.byTooltip('나가기'), findsOneWidget); // 대화 화면 그대로

    // 다시 녹음합니다 - 이번에는 알아들어서 확인 화면이 뜨고, 아이가 맞다고
    // 해야 나갑니다.
    await tester.tap(find.byTooltip('눌러서 말하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('말하기 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('맞아요'));
    await tester.pumpAndSettle();

    expect(
      repository.lastSttRetryCount,
      1,
      reason: '무음으로 한 번 다시 말했으니 재시도 횟수 1이 실려 가야 합니다',
    );
  });

  testWidgets('녹음이 서버 한도를 넘어도 화면을 안 바꾸고 짧게 말하라고만 한다', (
    WidgetTester tester,
  ) async {
    // 실서버에서 확인된 자리입니다. 한도를 넘기면 413이 오는데 전면 에러
    // 화면을 띄우면 아이가 대화 중간에 통째로 튕깁니다 - 이야기가 깨진 게
    // 아니라 이번에 말한 게 길었을 뿐이라 그 자리를 지켜야 합니다.
    final _SttRetrySpyRepository repository = _SttRetrySpyRepository(
      firstFailureCode: 'AUDIO_TOO_LARGE',
    );
    await pumpPlay(tester, repository: repository);

    await tester.tap(find.byTooltip('말하기 완료'));
    await tester.pumpAndSettle();

    for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
      // ignore: avoid_print
      print('TEXT>> ${t.data}');
    }
    expect(find.text('조금만 짧게 말해 줄래?'), findsOneWidget);
    expect(find.byTooltip('나가기'), findsOneWidget); // 대화 화면 그대로
    expect(find.text('다시 불러오기'), findsNothing); // 전면 에러가 아니다

    // 다시 말하면 그대로 이어집니다.
    await tester.tap(find.byTooltip('눌러서 말하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('말하기 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('맞아요'));
    await tester.pumpAndSettle();

    expect(repository.lastSttRetryCount, 1);
  });

  testWidgets('저신뢰 인식은 바로 제출하지 않고 확인을 거친다', (WidgetTester tester) async {
    final _SttRetrySpyRepository repository = _SttRetrySpyRepository()
      ..lowConfidenceAlways = true;
    await pumpPlay(tester, repository: repository);

    await tester.tap(find.byTooltip('말하기 완료'));
    await tester.pumpAndSettle();

    expect(
      repository.submittedTexts,
      isEmpty,
      reason: '서버가 잘못 들었을 수 있다고 한 결과를 바로 제출하면 안 됩니다',
    );
    expect(find.text('이렇게 들었는데, 맞을까요?'), findsOneWidget);
    expect(find.text('방귀를 참으면 안 돼요'), findsOneWidget);
    expect(find.text('맞아요'), findsOneWidget);
    expect(find.text('다시 말할래요'), findsOneWidget);

    // "맞아요" - 교정본은 text로, 벤더 원문은 sttRawText로 제출된다.
    await tester.tap(find.text('맞아요'));
    await tester.pumpAndSettle();
    expect(repository.submittedTexts, <String>['방귀를 참으면 안 돼요']);
    expect(
      repository.submittedRawTexts,
      <String?>['방비를 참으면 안 돼요'],
      reason: 'sttRawText에는 교정 전 원문이 가야 합니다 - text를 되올리면 원문 유실',
    );
  });

  testWidgets('잘 알아들은 결과도 아이가 확인해야 나간다 - 시계는 걸지 않는다', (
    WidgetTester tester,
  ) async {
    // 서버 신뢰도는 아이가 실제로 무슨 말을 했는지 모릅니다. 자신 있게 다른
    // 말로 옮겨 놓은 턴이 확인 없이 저장되는 것을 막습니다.
    final _AutoStopSpyRepository repository = _AutoStopSpyRepository();
    await pumpPlay(tester, repository: repository);

    await tester.tap(find.byTooltip('말하기 완료'));
    await tester.pumpAndSettle();

    expect(find.text('이렇게 들었어요'), findsOneWidget, reason: '고신뢰는 단정해서 보여 줍니다');
    expect(find.text('맞아요'), findsOneWidget);
    expect(repository.submittedTexts, isEmpty, reason: '확인 전에는 나가면 안 됩니다');

    // 저신뢰와 달리 무반응 자동 제출이 없습니다 - 자동으로 넘어가면 확인
    // 화면이 스쳐 가는 자막이 되고, 아이는 고칠 기회를 못 받습니다.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(repository.submittedTexts, isEmpty, reason: '고신뢰에는 시계를 걸지 않습니다');

    await tester.tap(find.text('맞아요'));
    await tester.pumpAndSettle();
    expect(repository.submittedTexts, <String>['오래오래 말한 내 생각이에요']);
  });

  testWidgets('저신뢰 확인은 6초 무반응이면 그대로 제출한다', (WidgetTester tester) async {
    final _SttRetrySpyRepository repository = _SttRetrySpyRepository()
      ..lowConfidenceAlways = true;
    await pumpPlay(tester, repository: repository);

    await tester.tap(find.byTooltip('말하기 완료'));
    await tester.pumpAndSettle();
    expect(repository.submittedTexts, isEmpty);

    // 확인은 시험이 아니다 - 답을 못 고르는 아이도 이야기는 계속돼야 한다.
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(repository.submittedTexts, <String>['방귀를 참으면 안 돼요']);
  });

  testWidgets('저신뢰면 확인 화면이 맞을까요로 묻고, 다시 말하면 재시도 횟수가 오른다', (
    WidgetTester tester,
  ) async {
    final _AutoStopSpyRepository repository = _AutoStopSpyRepository(
      lowConfidence: true,
    );
    await pumpPlay(tester, repository: repository);

    await tester.tap(find.byTooltip('말하기 완료'));
    await tester.pumpAndSettle();

    // 저신뢰는 단정하지 않고 물어봅니다.
    expect(find.text('이렇게 들었는데, 맞을까요?'), findsOneWidget);
    expect(find.text('잘 못 알아들었을 수도 있어요.'), findsOneWidget);

    // 다시 말하면 앞의 결과는 버려지고 곧바로 재녹음됩니다.
    await tester.tap(find.text('다시 말할래요'));
    await tester.pumpAndSettle();
    expect(repository.submittedTexts, isEmpty);
    expect(find.byTooltip('말하기 완료'), findsOneWidget);

    await tester.tap(find.byTooltip('말하기 완료'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('맞아요'));
    await tester.pumpAndSettle();

    expect(repository.submittedTexts, hasLength(1));
    expect(
      repository.lastSttRetryCount,
      1,
      reason: '다시 말할래요 한 번이 재시도 횟수로 실려 가야 합니다',
    );
  });

  testWidgets('녹음이 상한에 닿으면 자동으로 멈추고 지금까지 말한 것을 보낸다', (
    WidgetTester tester,
  ) async {
    final _AutoStopSpyRepository repository = _AutoStopSpyRepository();
    await pumpPlay(tester, repository: repository);

    // 듣기 화면에 들어오면 마이크가 자동으로 녹음을 시작한 상태입니다.
    expect(find.byTooltip('말하기 완료'), findsOneWidget);

    // 아무도 누르지 않은 채 상한까지 시간이 흐릅니다. 상한을 넘기면 업로드가
    // 통째로 413이라(웹 48kHz, 10MB 한도) 그 전에 끊어 보내야 합니다.
    await tester.pump(const Duration(seconds: maxRecordingSeconds));
    await tester.pumpAndSettle();

    expect(repository.transcribeCalls, 1, reason: '상한에서 자동으로 멈추고 변환을 요청해야 합니다');

    // 상한에서 끊은 말도 확인을 거칩니다 - 여기까지 말한 것을 잃지 않는 게
    // 요점이지, 아이 몰래 보내는 게 요점이 아닙니다.
    await tester.tap(find.text('맞아요'));
    await tester.pumpAndSettle();
    expect(repository.submittedTexts, isNotEmpty);
  });
  testWidgets('STORY(전개) 장면은 문장마다 내레이션 음성을 실제로 요청한다', (
    WidgetTester tester,
  ) async {
    final _StoryNarrationSpyRepository repository =
        _StoryNarrationSpyRepository();
    // 이 가짜는 장면이 끝나면 같은 장면을 또 돌려줘서 계속 내레이션합니다
    // (진짜 서버라면 다음 장면으로 넘어가겠지만, 여기서는 TTS 호출 자체만
    // 확인하면 되므로) - pumpAndSettle 을 쓰면 끝없이 돕니다. 필요한
    // 만큼만 직접 pump 합니다.
    await pumpPlay(tester, repository: repository, settle: false);

    // 첫 문장의 합성이 끝날 때까지 - 진짜 타이머(700ms 장면 종료 대기)는
    // 건드리지 않을 만큼만 마이크로태스크를 흘려보냅니다.
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(
      repository.synthesizedTexts,
      contains('첫 문장이에요.'),
      reason: '전개 장면도 대사처럼 문장마다 TTS를 실제로 불러야 합니다',
    );
    expect(
      repository.synthesizedCharacterNames.first,
      isNull,
      reason: '내레이션은 characterName 없이 불러야 내레이션 보이스가 나옵니다',
    );
  });

  testWidgets('첫 전개 장면이 끝나고 다음 장면으로 넘어가도 내레이션이 계속 나온다', (
    WidgetTester tester,
  ) async {
    final _StoryNarrationSpyRepository repository =
        _StoryNarrationSpyRepository()
          ..nextSceneOnComplete = const PlaySessionSnapshot(
            phase: PlayPhase.story,
            currentScene: PlayScene(
              sceneId: 'scene-2',
              sceneOrder: 2,
              sceneType: PlaySceneType.story,
              narrationSentences: <String>['그래서 며느리는 이렇게 말했어요.'],
            ),
          );
    await pumpPlay(tester, repository: repository, settle: false);

    // 첫 장면(문장 2개)이 다 끝나고, 다음 장면으로 넘어가기 전 700ms 대기까지
    // 지나갈 시간을 줍니다.
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 750));
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(
      repository.synthesizedTexts,
      containsAll(<String>['첫 문장이에요.', '두 번째 문장이에요.']),
      reason: '첫 장면 문장은 둘 다 불렀어야 합니다',
    );
    expect(
      repository.synthesizedTexts,
      contains('그래서 며느리는 이렇게 말했어요.'),
      reason: '두 번째 장면으로 넘어간 뒤에도 내레이션 TTS 를 계속 불러야 합니다',
    );
  });

  testWidgets('소리 끄기는 아이콘만 바꾸지 않고 실제로 소리를 죽인다 - 재생은 끊지 않습니다', (
    WidgetTester tester,
  ) async {
    final _StoryNarrationSpyRepository repository =
        _StoryNarrationSpyRepository();
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      settle: false,
    );

    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(audioPlayer.playCount, 1, reason: '첫 문장이 재생 중이어야 합니다');

    await tester.tap(find.byTooltip('소리 끄기'));
    await tester.pump();

    expect(
      audioPlayer.muted,
      isTrue,
      reason: '아이콘만 바꾸면 안 됩니다 - 나오고 있던 음성이 실제로 안 들려야 합니다',
    );
    expect(
      audioPlayer.stopCount,
      0,
      reason: '끊으면 재생 위치를 잃습니다 - 볼륨만 0으로 내려야 다시 켤 때 그 지점부터 들립니다',
    );
    expect(find.byTooltip('소리 켜기'), findsOneWidget);

    // 소리를 꺼도 오디오는 그대로 흘러가고, 새로 틀지는 않습니다.
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 8));
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(audioPlayer.playCount, 1, reason: '소리를 끈다고 문장을 새로 틀면 안 됩니다');

    // 음소거 중에도 문장은 오디오 길이에 맞춰 평소대로 넘어갑니다.
    audioPlayer.finishPlayback();
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.text('두 번째 문장이에요.'), findsOneWidget);
    expect(
      repository.synthesizedTexts,
      containsAll(<String>['첫 문장이에요.', '두 번째 문장이에요.']),
      reason: '음소거 중에도 합성은 그대로 합니다 - 켜는 순간 바로 들려야 합니다',
    );
    expect(audioPlayer.muted, isTrue, reason: '새 문장을 틀어도 음소거 상태가 유지돼야 합니다');
  });

  testWidgets('사전 렌더 내레이션은 파일 하나로 재생하고 합성을 부르지 않는다', (
    WidgetTester tester,
  ) async {
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    final _StoryNarrationSpyRepository repository =
        _StoryNarrationSpyRepository()
          ..initialSnapshot = const PlaySessionSnapshot(
            phase: PlayPhase.story,
            currentScene: PlayScene(
              sceneId: 'scene-1',
              sceneOrder: 1,
              sceneType: PlaySceneType.story,
              narrationSentences: <String>['첫 문장이에요.', '두 번째 문장이에요.'],
              narrationAudioUrl: '/tts/banggui/sc_banggui_01.mp3',
              narrationTimings: <PlayAudioTiming>[
                PlayAudioTiming(index: 0, start: 0, end: 6.2),
                PlayAudioTiming(index: 1, start: 6.8, end: 13.2),
              ],
            ),
          );
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      settle: false,
    );
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(audioPlayer.playCount, 1, reason: '장면 전체가 파일 하나여야 합니다');
    expect(
      repository.synthesizedTexts,
      isEmpty,
      reason: '사전 렌더가 있는데 문장별 합성을 또 부르면 왕복 비용이 그대로 남습니다',
    );
    expect(find.text('첫 문장이에요.'), findsOneWidget);

    // 자막 시계는 벽시계가 아니라 **재생 위치**입니다 - 위치를 흘려야 넘어갑니다.
    audioPlayer.emitPosition(const Duration(seconds: 7));
    for (int i = 0; i < 3; i++) {
      await tester.pump();
    }
    expect(find.text('두 번째 문장이에요.'), findsOneWidget);

    // 파일이 끝나면 700ms 뒤 장면 완료로 넘어갑니다(기존 규칙 그대로).
    audioPlayer.finishPlayback();
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 750));
    expect(audioPlayer.playCount, greaterThanOrEqualTo(1));
  });

  testWidgets('다시 듣기로 다시 틀어도 자막이 재생 위치를 따라간다', (WidgetTester tester) async {
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    final _StoryNarrationSpyRepository repository =
        _StoryNarrationSpyRepository()
          ..initialSnapshot = const PlaySessionSnapshot(
            phase: PlayPhase.story,
            currentScene: PlayScene(
              sceneId: 'scene-1',
              sceneOrder: 1,
              sceneType: PlaySceneType.story,
              narrationSentences: <String>['첫 문장이에요.', '두 번째 문장이에요.'],
              narrationAudioUrl: '/tts/banggui/sc_banggui_01.mp3',
              narrationTimings: <PlayAudioTiming>[
                PlayAudioTiming(index: 0, start: 0, end: 6.2),
                PlayAudioTiming(index: 1, start: 6.8, end: 13.2),
              ],
            ),
          );
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      settle: false,
    );
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }

    // 첫 재생 - 위치를 흘리면 자막이 넘어갑니다.
    audioPlayer.emitPosition(const Duration(seconds: 7));
    for (int i = 0; i < 3; i++) {
      await tester.pump();
    }
    expect(find.text('두 번째 문장이에요.'), findsOneWidget);

    await tester.tap(find.byTooltip('다시 듣기'));
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.text('첫 문장이에요.'), findsOneWidget, reason: '다시 듣기는 장면 처음부터입니다');
    expect(audioPlayer.playCount, 2);

    // 다시 튼 재생에서도 위치를 따라가야 합니다. 앞 재생의 뒷정리가 새로 건
    // 위치 구독을 끊어 버리면, 소리는 끝까지 나오는데 자막만 첫 문장에 멈춥니다.
    audioPlayer.emitPosition(const Duration(seconds: 7));
    for (int i = 0; i < 3; i++) {
      await tester.pump();
    }
    expect(
      find.text('두 번째 문장이에요.'),
      findsOneWidget,
      reason: '다시 듣기에서도 첫 재생과 똑같이 음성 진행에 맞춰 문장이 넘어가야 합니다',
    );
  });

  testWidgets('사전 렌더 오프닝 대사는 문장이 여러 개여도 파일 하나로 재생한다', (
    WidgetTester tester,
  ) async {
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    final _StoryNarrationSpyRepository repository =
        _StoryNarrationSpyRepository()
          ..initialSnapshot = const PlaySessionSnapshot(
            phase: PlayPhase.dialogue,
            currentScene: PlayScene(
              sceneId: 'scene-5',
              sceneOrder: 5,
              sceneType: PlaySceneType.dialogue,
              narrationSentences: <String>[],
              characterName: '시아버지',
            ),
            openingText: '아이고 이게 무슨 일이냐! 우리 집안이 다 흔들리는구나!',
            openingAudioUrl: '/tts/banggui/sc_banggui_05_opening.mp3',
            openingAudioTimings: <PlayAudioTiming>[
              PlayAudioTiming(index: 0, start: 0, end: 3.1),
              PlayAudioTiming(index: 1, start: 3.7, end: 7.4),
            ],
          );
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      settle: false,
    );
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }

    // 예전에는 문장이 2개 이상이면 audioUrl 을 버리고 문장마다 재합성했습니다.
    expect(audioPlayer.playCount, 1, reason: '대사 전체가 파일 하나여야 합니다');
    expect(repository.synthesizedTexts, isEmpty);
    expect(find.textContaining('아이고 이게 무슨 일이냐!'), findsOneWidget);

    audioPlayer.emitPosition(const Duration(seconds: 4));
    for (int i = 0; i < 3; i++) {
      await tester.pump();
    }
    expect(find.textContaining('우리 집안이 다 흔들리는구나!'), findsOneWidget);

    // 파일이 끝나면 아이 차례(마이크)로 넘어갑니다.
    audioPlayer.finishPlayback();
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(find.bySemanticsLabel('마이크 켜짐'), findsOneWidget);
  });

  testWidgets('전개 화면에서 소리를 다시 켜면 되감지 않고 그 지점부터 들린다', (
    WidgetTester tester,
  ) async {
    final _StoryNarrationSpyRepository repository =
        _StoryNarrationSpyRepository();
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      settle: false,
    );

    // 첫 문장을 끝까지 듣고 두 번째 문장에서 소리를 껐다 켭니다.
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    audioPlayer.finishPlayback();
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.text('두 번째 문장이에요.'), findsOneWidget);
    await tester.tap(find.byTooltip('소리 끄기'));
    await tester.pump();
    final int playsWhileMuted = audioPlayer.playCount;

    repository.synthesizedTexts.clear();
    await tester.tap(find.byTooltip('소리 켜기'));
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(audioPlayer.muted, isFalse);
    expect(
      audioPlayer.playCount,
      playsWhileMuted,
      reason:
          '켤 때 다시 트는 것은 되감기입니다 - 지금 콘텐츠는 장면당 문장이 하나라 '
          '그 문장을 다시 트는 것이 곧 장면 처음으로 돌아가는 것입니다',
    );
    expect(
      repository.synthesizedTexts,
      isEmpty,
      reason: '흘러가던 오디오를 그대로 들려주면 됩니다 - 다시 합성할 이유가 없습니다',
    );
    expect(find.text('두 번째 문장이에요.'), findsOneWidget);
  });

  testWidgets('일시정지 중에 소리를 켜면 멈춘 상태를 그대로 둔다', (WidgetTester tester) async {
    final _StoryNarrationSpyRepository repository =
        _StoryNarrationSpyRepository();
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      settle: false,
    );

    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.tap(find.byTooltip('소리 끄기'));
    await tester.pump();
    await tester.tap(find.byTooltip('잠시 멈춤'));
    await tester.pump();

    final int playsWhilePaused = audioPlayer.playCount;
    repository.synthesizedTexts.clear();
    await tester.tap(find.byTooltip('소리 켜기'));
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(find.text('이야기를 잠시 멈췄어요'), findsOneWidget);
    expect(
      audioPlayer.playCount,
      playsWhilePaused,
      reason: '소리 켜기가 멈춰 둔 이야기를 다시 굴리면 안 됩니다 - 계속 듣기의 몫입니다',
    );
    expect(repository.synthesizedTexts, isEmpty);
  });

  testWidgets('대화 화면에서 소리를 다시 켜면 되감지 않고 그 지점부터 들린다', (
    WidgetTester tester,
  ) async {
    final _DialogueSpyRepository repository = _DialogueSpyRepository();
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      settle: false,
    );

    // 첫 문장을 끝까지 듣고 두 번째 문장에서 소리를 껐다 켭니다.
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
    audioPlayer.finishPlayback();
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(find.text('두 번째 문장이에요.'), findsOneWidget);
    final int stopsBeforeMute = audioPlayer.stopCount;

    await tester.tap(find.byTooltip('소리 끄기'));
    await tester.pump();
    expect(audioPlayer.muted, isTrue);
    expect(
      audioPlayer.stopCount,
      stopsBeforeMute,
      reason: '끊으면 재생 위치를 잃습니다 - 볼륨만 0으로 내려야 합니다',
    );
    final int playsWhileMuted = audioPlayer.playCount;

    repository.synthesizedTexts.clear();
    await tester.tap(find.byTooltip('소리 켜기'));
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }

    expect(audioPlayer.muted, isFalse);
    expect(
      audioPlayer.playCount,
      playsWhileMuted,
      reason: '켤 때 다시 트는 것은 되감기입니다 - 흘러가던 오디오를 그대로 들려주면 됩니다',
    );
    expect(repository.synthesizedTexts, isEmpty);
    expect(find.text('두 번째 문장이에요.'), findsOneWidget);

    // 음소거와 무관하게 대사는 오디오 길이에 맞춰 넘어갑니다.
    audioPlayer.finishPlayback();
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(find.text('세 번째 문장이에요.'), findsOneWidget);
  });

  testWidgets('대화 장면도 일시정지 후 다시 재생하면 멈춘 문장부터 이어 읽는다', (
    WidgetTester tester,
  ) async {
    final _DialogueSpyRepository repository = _DialogueSpyRepository();
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      settle: false,
    );

    // 첫 문장을 끝까지 듣고 두 번째 문장으로 넘어갑니다.
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
    audioPlayer.finishPlayback();
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(find.text('두 번째 문장이에요.'), findsOneWidget);

    await tester.tap(find.byTooltip('잠시 멈춤'));
    await tester.pump();
    expect(find.text('이야기를 잠시 멈췄어요'), findsOneWidget);

    repository.synthesizedTexts.clear();
    await tester.tap(find.text('계속 듣기'));
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }

    expect(
      find.text('두 번째 문장이에요.'),
      findsOneWidget,
      reason: '멈춘 문장부터 이어져야 합니다 - 대사를 처음부터 다시 읽으면 듣던 자리를 잃습니다',
    );
    expect(
      repository.synthesizedTexts,
      isNot(contains('첫 문장이에요.')),
      reason: '첫 문장 음성을 다시 부르면 대사를 처음부터 다시 읽는 것입니다',
    );
  });

  testWidgets('대화 장면의 일시정지도 재생 위치를 지켜서, 문장을 처음부터 다시 읽지 않는다', (
    WidgetTester tester,
  ) async {
    final _DialogueSpyRepository repository = _DialogueSpyRepository();
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      settle: false,
    );

    // 첫 문장을 끝까지 듣고, 두 번째 문장이 재생되는 도중에 멈춥니다.
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
    audioPlayer.finishPlayback();
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(find.text('두 번째 문장이에요.'), findsOneWidget);
    final int playsBeforePause = audioPlayer.playCount;
    // 대사를 시작할 때 _playCharacterMessage 가 앞선 소리를 끊습니다 - 그
    // 호출은 일시정지와 무관하니 여기서부터 세어야 합니다.
    final int stopsBeforePause = audioPlayer.stopCount;

    await tester.tap(find.byTooltip('잠시 멈춤'));
    await tester.pump();

    expect(
      audioPlayer.pauseCount,
      1,
      reason: 'stop() 은 재생 위치를 0으로 되돌립니다 - 일시정지는 pause() 여야 합니다',
    );
    expect(
      audioPlayer.stopCount,
      stopsBeforePause,
      reason: '멈출 때 stop() 을 부르면 되감겨서 이어 들을 지점이 사라집니다',
    );

    // 멈춘 채로 오래 두어도 제멋대로 다음 문장으로 넘어가면 안 됩니다.
    await tester.pump(const Duration(minutes: 2));
    expect(find.text('두 번째 문장이에요.'), findsOneWidget);

    repository.synthesizedTexts.clear();
    await tester.tap(find.text('계속 듣기'));
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }

    expect(audioPlayer.resumeCount, 1);
    expect(
      audioPlayer.playCount,
      playsBeforePause,
      reason: '멈춘 지점부터 이어져야 합니다 - 새로 틀면 그 문장을 처음부터 다시 읽는 것입니다',
    );
    expect(
      repository.synthesizedTexts,
      isEmpty,
      reason: '이어 재생은 이미 받아 둔 음성을 그대로 씁니다 - 다시 합성하면 문장을 되감은 것입니다',
    );
  });

  testWidgets('이어하기 복원은 이 장면의 발화만 되살린다 - 세션 전체 기록을 쓰지 않는다', (
    WidgetTester tester,
  ) async {
    // 이 가짜의 resume 은 세션 전체 기록(= 이전 장면 발화 포함)을 줍니다.
    // 화면이 그걸 그대로 쓰면 남의 장면 발화가 떠 버립니다.
    final _DialogueSpyRepository repository = _DialogueSpyRepository();
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      settle: false,
    );

    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }

    expect(
      repository.sceneMessageRequests,
      contains('scene-2'),
      reason: 'MessageResponse 에 장면 식별자가 없어 장면으로 걸러 주는 조회가 필요합니다',
    );
    expect(
      find.text('지난 장면에서 한 말이에요.'),
      findsNothing,
      reason: '이전 장면 발화가 새 장면에 떠 있으면 아이가 이번에 한 말로 오해합니다',
    );
  });

  testWidgets('장면이 넘어가면 이전 장면에서 한 발화는 새 장면 첫 대사 전에 사라진다', (
    WidgetTester tester,
  ) async {
    final _SceneFlowSpyRepository repository = _SceneFlowSpyRepository();
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      settle: false,
    );

    // 대화1: 첫 대사를 끝까지 듣고 아이 차례가 됩니다.
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
    audioPlayer.finishPlayback();
    await tester.pumpAndSettle();
    expect(find.byTooltip('말하기 완료'), findsOneWidget);

    // 대화1에서 답합니다. 확인 화면에서 맞다고 하면 턴이 나가고, 캐릭터가
    // 답하는 동안에도 아이 발화는 계속 보여야 합니다.
    await tester.tap(find.byTooltip('말하기 완료'));
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
    await tester.tap(find.text('맞아요'));
    for (int i = 0; i < 12; i++) {
      await tester.pump();
    }
    expect(
      find.text('나는 이렇게 생각해요'),
      findsOneWidget,
      reason: '같은 장면 안에서는 무엇에 대한 답인지 보이도록 남아 있어야 합니다',
    );

    // 캐릭터 답이 끝나면 장면이 넘어갑니다: 전개2 -> 대화2.
    audioPlayer.finishPlayback();
    for (int i = 0; i < 10; i++) {
      await tester.pump();
    }
    audioPlayer.finishPlayback(); // 전개2 내레이션
    for (int i = 0; i < 8; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 700));
    for (int i = 0; i < 10; i++) {
      await tester.pump();
    }

    expect(
      find.text('나는 두 번째 캐릭터야.'),
      findsOneWidget,
      reason: '대화2의 첫 대사까지 왔어야 합니다',
    );
    expect(
      find.text('나는 이렇게 생각해요'),
      findsNothing,
      reason: '새 캐릭터가 말을 거는데 아이가 하지도 않은 대답이 떠 있으면 안 됩니다',
    );
  });

  testWidgets('아이 차례가 시작되면 지난 턴의 아이 발화는 화면에서 지워진다', (
    WidgetTester tester,
  ) async {
    final _DialogueSpyRepository repository = _DialogueSpyRepository()
      ..restoredChildText = '어제 한 말이에요.';
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      settle: false,
    );

    // 캐릭터가 말하는 동안에는 무엇에 대한 답인지 보이도록 남아 있습니다.
    for (int i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(find.text('어제 한 말이에요.'), findsOneWidget);

    // 대사를 끝까지 듣고 아이 차례가 되면 지워집니다.
    for (int sentence = 0; sentence < 3; sentence++) {
      audioPlayer.finishPlayback();
      for (int i = 0; i < 6; i++) {
        await tester.pump();
      }
    }
    await tester.pumpAndSettle();
    expect(
      find.byTooltip('말하기 완료'),
      findsOneWidget,
      reason: '대사가 끝나면 마이크가 켜지며 아이 차례가 시작됩니다',
    );
    expect(
      find.text('어제 한 말이에요.'),
      findsNothing,
      reason: '새 차례에 남아 있으면 아이가 이번에 한 말로 오해합니다',
    );
  });

  testWidgets('일시정지 후 다시 재생하면 장면 처음이 아니라 멈춘 문장부터 이어진다', (
    WidgetTester tester,
  ) async {
    final _StoryNarrationSpyRepository repository =
        _StoryNarrationSpyRepository();
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      settle: false,
    );

    // 첫 문장을 끝까지 듣고 두 번째 문장으로 넘어갑니다.
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    audioPlayer.finishPlayback();
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.text('두 번째 문장이에요.'), findsOneWidget);

    await tester.tap(find.byTooltip('잠시 멈춤'));
    await tester.pump();
    expect(find.text('이야기를 잠시 멈췄어요'), findsOneWidget);

    repository.synthesizedTexts.clear();
    await tester.tap(find.text('계속 듣기'));
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(
      find.text('두 번째 문장이에요.'),
      findsOneWidget,
      reason: '다시 재생은 멈춘 문장에서 이어져야 합니다 - 장면 처음으로 돌아가면 안 됩니다',
    );
    expect(
      repository.synthesizedTexts,
      isNot(contains('첫 문장이에요.')),
      reason: '이어 재생이 첫 문장 음성을 다시 부르면 장면을 처음부터 다시 읽는 것입니다',
    );
  });

  testWidgets('일시정지는 재생 위치를 지켜서, 다시 재생하면 그 문장을 처음부터 다시 읽지 않는다', (
    WidgetTester tester,
  ) async {
    final _StoryNarrationSpyRepository repository =
        _StoryNarrationSpyRepository();
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      settle: false,
    );

    // 첫 문장을 끝까지 듣고, 두 번째 문장이 재생되는 도중에 멈춥니다.
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    audioPlayer.finishPlayback();
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.text('두 번째 문장이에요.'), findsOneWidget);
    final int playsBeforePause = audioPlayer.playCount;

    await tester.tap(find.byTooltip('잠시 멈춤'));
    await tester.pump();

    expect(
      audioPlayer.pauseCount,
      1,
      reason: 'stop() 은 재생 위치를 0으로 되돌립니다 - 일시정지는 pause() 여야 합니다',
    );
    expect(
      audioPlayer.stopCount,
      0,
      reason: '멈출 때 stop() 을 부르면 되감겨서 재개할 지점이 사라집니다',
    );

    // 멈춘 채로 오래 두어도 제멋대로 다음 문장으로 넘어가면 안 됩니다.
    await tester.pump(const Duration(minutes: 2));
    expect(find.text('두 번째 문장이에요.'), findsOneWidget);

    repository.synthesizedTexts.clear();
    await tester.tap(find.text('계속 듣기'));
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(audioPlayer.resumeCount, 1);
    expect(
      audioPlayer.playCount,
      playsBeforePause,
      reason: '멈춘 지점부터 이어져야 합니다 - 새로 틀면 그 문장을 처음부터 다시 읽는 것입니다',
    );
    expect(
      repository.synthesizedTexts,
      isEmpty,
      reason: '이어 재생은 이미 받아 둔 음성을 그대로 씁니다 - 다시 합성하면 문장을 되감은 것입니다',
    );

    // 이어 듣던 문장이 끝나면 평소대로 다음으로 넘어갑니다 - 일시정지가
    // 내레이션 루프를 끊어 놓지 않았다는 뜻입니다(이 장면은 문장이 둘이라
    // 다음은 장면 넘기기입니다).
    audioPlayer.finishPlayback();
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 700));
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(find.text('첫 문장이에요.'), findsOneWidget);
  });

  testWidgets('상단 진행바는 장면이 넘어갈 때마다 전체 장면 대비 위치를 그린다', (
    WidgetTester tester,
  ) async {
    final _StoryNarrationSpyRepository repository =
        _StoryNarrationSpyRepository()
          ..nextSceneOnComplete = const PlaySessionSnapshot(
            phase: PlayPhase.story,
            currentScene: PlayScene(
              sceneId: 'scene-2',
              sceneOrder: 2,
              sceneType: PlaySceneType.story,
              narrationSentences: <String>['그래서 며느리는 이렇게 말했어요.'],
            ),
          );
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      totalScenes: 5,
      settle: false,
    );

    double widthFactor() => tester
        .widget<AnimatedFractionallySizedBox>(
          find.byType(AnimatedFractionallySizedBox),
        )
        .widthFactor!;

    Future<void> settleFrames() async {
      for (int i = 0; i < 6; i++) {
        await tester.pump();
      }
    }

    // 1번째 장면 / 전체 5장면.
    await settleFrames();
    expect(widthFactor(), closeTo(0.2, 0.001));

    // 문장이 넘어가는 것만으로는 움직이지 않습니다 - 장면 단위입니다.
    audioPlayer.finishPlayback();
    await settleFrames();
    expect(find.text('두 번째 문장이에요.'), findsOneWidget);
    expect(widthFactor(), closeTo(0.2, 0.001));

    // 장면이 끝나 다음 장면으로 넘어가면 2/5 가 됩니다.
    audioPlayer.finishPlayback();
    await settleFrames();
    await tester.pump(const Duration(milliseconds: 750));
    await settleFrames();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      widthFactor(),
      closeTo(0.4, 0.001),
      reason: '장면이 넘어갔는데 진행바가 그대로면 아이는 얼마나 남았는지 알 수 없습니다',
    );
  });

  testWidgets('전체 장면 수를 모르면 진행바는 눈금 없이 비워 둔다', (WidgetTester tester) async {
    await pumpPlay(tester);

    final AnimatedFractionallySizedBox bar = tester
        .widget<AnimatedFractionallySizedBox>(
          find.byType(AnimatedFractionallySizedBox),
        );
    expect(bar.widthFactor, 0, reason: '모르는 값을 아는 척 그리는 것보다 비워 두는 편이 낫습니다');
  });

  testWidgets('좁은 폭에서도 캐릭터 대사는 잘리지 않는다', (WidgetTester tester) async {
    const String longQuestion =
        '친구가 갑자기 화를 내면서 네가 아끼는 물건을 던져 버렸을 때, '
        '너는 그 친구에게 어떤 말을 해 주고 싶은지 천천히 생각해서 이야기해 줄래?';
    await pumpPlay(tester, question: longQuestion, size: const Size(420, 720));

    final Text bubbleText = tester.widget<Text>(find.text(longQuestion));
    expect(
      bubbleText.overflow,
      isNot(TextOverflow.ellipsis),
      reason: '대사를 말줄임표로 끊으면 아이는 읽지 못한 채로 대답해야 합니다',
    );
    expect(bubbleText.maxLines, isNull);
    // 잘리는 대신 글자가 한 단계 줄어듭니다.
    expect(bubbleText.style?.fontSize, lessThan(27));
  });

  /// 선택지가 있는 장면(3·5·7·9)은 캐릭터 상태 머신이 붙어 대기 모션이 계속
  /// 돕니다 - `pumpAndSettle` 이 영영 안 끝나므로 프레임을 직접 흘려보냅니다.
  Future<void> settleFrames(WidgetTester tester, [int count = 12]) async {
    for (int i = 0; i < count; i++) {
      await tester.pump();
    }
  }

  /// 마이크를 켜고 끄면서 한 번 발화를 시도합니다. 가짜 STT 가 계속
  /// `STT_EMPTY_TEXT` 를 던지므로 시도할 때마다 실패합니다.
  Future<void> tryToSpeak(WidgetTester tester) async {
    if (find.byTooltip('말하기 완료').evaluate().isEmpty) {
      await tester.tap(find.byTooltip('눌러서 말하기'));
      await settleFrames(tester);
    }
    await tester.tap(find.byTooltip('말하기 완료'));
    await settleFrames(tester);
  }

  /// 선택지 흐름을 보는 대화 화면을 띄우고 아이 차례까지 진행합니다.
  Future<void> pumpChoiceScene(
    WidgetTester tester, {
    required _SttChoiceSpyRepository repository,
  }) async {
    await pumpPlay(tester, repository: repository, settle: false);
    await settleFrames(tester, 16);
  }

  testWidgets('세 번 이어서 못 알아들으면 문장 카드를 내려놓는다 - 1·2회에는 캐릭터가 다시 물어본다', (
    WidgetTester tester,
  ) async {
    final _SttChoiceSpyRepository repository = _SttChoiceSpyRepository();
    await pumpChoiceScene(tester, repository: repository);
    final String firstCard = SttChoiceCatalog.firstTurn[3]!.first.text;

    // 1회 - 캐릭터가 다시 물어보고, 선택지는 아직 없습니다.
    await tryToSpeak(tester);
    expect(find.text(SttChoiceCatalog.retryFirst[3]!.text), findsOneWidget);
    expect(find.text(firstCard), findsNothing);

    // 2회 - 조금 크게 말해 달라고 합니다. 여전히 선택지는 없습니다.
    await tryToSpeak(tester);
    expect(find.text(SttChoiceCatalog.retrySecond[3]!.text), findsOneWidget);
    expect(find.text(firstCard), findsNothing);

    // 3회 - 그제야 고를 수 있는 문장을 내려놓습니다.
    await tryToSpeak(tester);
    expect(find.text(SttChoiceCatalog.choiceIntro[3]!.text), findsOneWidget);
    for (final SttChoiceSentence sentence in SttChoiceCatalog.firstTurn[3]!) {
      expect(find.text(sentence.text), findsOneWidget);
    }
    expect(
      repository.submitCount,
      0,
      reason: '아직 아이가 고르지 않았으니 서버로 나간 발화는 없어야 합니다',
    );
  });

  testWidgets('고른 문장은 평소 발화와 같은 길로, sttRetryCount 3 · STT 값은 비운 채로 나간다', (
    WidgetTester tester,
  ) async {
    final _SttChoiceSpyRepository repository = _SttChoiceSpyRepository();
    await pumpChoiceScene(tester, repository: repository);

    for (int attempt = 0; attempt < 3; attempt++) {
      await tryToSpeak(tester);
    }
    final SttChoiceSentence chosen = SttChoiceCatalog.firstTurn[3]!.first;
    await tester.tap(find.text(chosen.text));
    await settleFrames(tester);

    expect(repository.submitCount, 1);
    expect(repository.lastText, chosen.text);
    expect(
      repository.lastSttRetryCount,
      3,
      reason: '카운터가 4든 5든 선택지 제출은 "세 번 만에 고르기로 내려왔다"는 뜻의 3 입니다',
    );
    expect(
      repository.lastSttRawText,
      isNull,
      reason: 'STT 를 안 탄 말이라 원문이 없습니다 - 가짜 값을 넣으면 보호자 리포트의 저신뢰 판정이 오염됩니다',
    );
    expect(repository.lastSttConfidence, isNull);
  });

  testWidgets('고른 문장을 보내고 나면 선택지는 접히고, 다음 차례는 평소대로 마이크로 시작한다', (
    WidgetTester tester,
  ) async {
    final _SttChoiceSpyRepository repository = _SttChoiceSpyRepository();
    await pumpChoiceScene(tester, repository: repository);

    for (int attempt = 0; attempt < 3; attempt++) {
      await tryToSpeak(tester);
    }
    final SttChoiceSentence chosen = SttChoiceCatalog.firstTurn[3]!.first;
    await tester.tap(find.text(chosen.text));
    await settleFrames(tester);

    for (final SttChoiceSentence sentence in SttChoiceCatalog.firstTurn[3]!) {
      expect(find.text(sentence.text), findsNothing);
    }
    expect(find.byTooltip('말하기 완료'), findsOneWidget);
  });

  testWidgets('선택지가 떠 있어도 마이크는 그대로 남는다 - 고르기로 내려온 것이지 마이크가 막힌 게 아니다', (
    WidgetTester tester,
  ) async {
    final _SttChoiceSpyRepository repository = _SttChoiceSpyRepository();
    await pumpChoiceScene(tester, repository: repository);

    for (int attempt = 0; attempt < 3; attempt++) {
      await tryToSpeak(tester);
    }

    expect(
      find.text(SttChoiceCatalog.firstTurn[3]!.first.text),
      findsOneWidget,
    );
    expect(find.byTooltip('눌러서 말하기'), findsOneWidget);
  });

  testWidgets('다시 말하는 자리에서는 "자동으로 켜졌다"고 하지 않는다 - 눌러야 켜지기 때문', (
    WidgetTester tester,
  ) async {
    final _SttChoiceSpyRepository repository = _SttChoiceSpyRepository();
    await pumpChoiceScene(tester, repository: repository);

    // 턴을 새로 시작할 때는 화면이 알아서 녹음을 켭니다 - 녹음 중 문구입니다.
    expect(find.text('나는 이렇게 생각해요…'), findsOneWidget);

    // 한 번 못 알아들은 뒤로는 녹음이 꺼진 채로 기다립니다. 이때 "자동으로
    // 켜졌다"고 하면 아이가 누르지 않고 기다립니다.
    await tryToSpeak(tester);
    expect(find.text('마이크가 자동으로 켜졌어요.'), findsNothing);
    expect(find.text('마이크를 누르고 말해 주세요.'), findsOneWidget);

    // 선택지가 떠 있을 때도 마찬가지입니다.
    await tryToSpeak(tester);
    await tryToSpeak(tester);
    expect(
      find.text(SttChoiceCatalog.firstTurn[3]!.first.text),
      findsOneWidget,
    );
    expect(find.text('마이크가 자동으로 켜졌어요.'), findsNothing);
    expect(find.text('마이크를 누르고 말해 주세요.'), findsOneWidget);
  });

  testWidgets('음성이 없는 장면에서는 세 번 실패해도 선택지를 띄우지 않는다', (
    WidgetTester tester,
  ) async {
    // 4장면에는 안내 음성도 문장도 없습니다. 빈 판을 내리는 대신 예전처럼
    // 짧은 안내만 답니다.
    final _SttChoiceSpyRepository repository = _SttChoiceSpyRepository(
      sceneOrder: 4,
    );
    await pumpChoiceScene(tester, repository: repository);

    for (int attempt = 0; attempt < 3; attempt++) {
      await tryToSpeak(tester);
    }

    expect(find.text('잘 못 들었어요. 다시 말해 볼까?'), findsOneWidget);
    expect(find.text(SttChoiceCatalog.firstTurn[3]!.first.text), findsNothing);
    expect(find.byTooltip('나가기'), findsOneWidget); // 대화 화면 그대로
  });

  testWidgets('안내 음성이 나오는 동안에는 마이크를 누를 수 없다', (WidgetTester tester) async {
    final _SttChoiceSpyRepository repository = _SttChoiceSpyRepository();
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      settle: false,
    );

    // 첫 대사를 끝까지 듣고 아이 차례가 됩니다.
    await settleFrames(tester);
    audioPlayer.finishPlayback();
    await settleFrames(tester);
    await tester.tap(find.byTooltip('말하기 완료'));
    await settleFrames(tester);

    // 안내 음성이 아직 재생 중입니다 - 이때 녹음을 시작하면 캐릭터 목소리가
    // 그대로 녹음됩니다.
    expect(find.byTooltip('눌러서 말하기'), findsNothing);
    expect(find.text('이야기 친구가 다시 물어보고 있어요'), findsOneWidget);

    audioPlayer.finishPlayback();
    await settleFrames(tester);
    expect(find.byTooltip('눌러서 말하기'), findsOneWidget);
  });

  testWidgets('다시 듣기는 사전 렌더 음성을 그대로 다시 튼다 - 다시 합성하지 않는다', (
    WidgetTester tester,
  ) async {
    // 사전 렌더는 Gemini, 실시간 합성은 그때 설정된 벤더라 재합성하면 같은
    // 인물이 다른 사람 목소리로 들립니다. 다시 듣기는 듣던 그 파일이어야
    // 합니다. → 백엔드 application.yml external.tts 주석
    final _VoiceSpyRepository repository = _VoiceSpyRepository();
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      settle: false,
    );
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(audioPlayer.playedUrls, hasLength(1));
    expect(audioPlayer.playedUrls.single, endsWith('/tts/opening.mp3'));
    expect(
      repository.synthesizedTexts,
      isEmpty,
      reason: '사전 렌더가 있으면 합성하지 않습니다',
    );

    await tester.tap(find.byTooltip('다시 듣기'));
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(
      repository.synthesizedTexts,
      isEmpty,
      reason: '다시 들을 때 재합성하면 사전 렌더와 다른 목소리가 납니다',
    );
    expect(audioPlayer.playedUrls, hasLength(2));
    expect(audioPlayer.playedUrls.last, endsWith('/tts/opening.mp3'));
  });

  testWidgets('다시 듣기는 지금 대사를 다시 튼다 - 장면 오프닝 음성으로 되돌아가지 않는다', (
    WidgetTester tester,
  ) async {
    // 예전에는 글자만 지금 대사를 쓰고 소리는 늘 오프닝 파일을 가리켜서,
    // 한 문장짜리 대답을 다시 들으면 화면엔 새 대사, 스피커에선 오프닝
    // 대사가 나왔습니다.
    final _VoiceSpyRepository repository = _VoiceSpyRepository();
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      settle: false,
    );
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    // 오프닝이 끝나야 마이크가 열립니다.
    audioPlayer.finishPlayback();
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }

    await tester.tap(find.byTooltip('말하기 완료'));
    for (int i = 0; i < 8; i++) {
      await tester.pump();
    }
    await tester.tap(find.text('맞아요'));
    for (int i = 0; i < 8; i++) {
      await tester.pump();
    }

    expect(
      audioPlayer.playedUrls.last,
      'tts://그렇게 생각했구나.',
      reason: '아이 말에 대한 대답이 나와야 합니다',
    );

    await tester.tap(find.byTooltip('다시 듣기'));
    for (int i = 0; i < 8; i++) {
      await tester.pump();
    }

    expect(
      audioPlayer.playedUrls.last,
      'tts://그렇게 생각했구나.',
      reason: '방금 들은 대답을 다시 들어야 합니다 - 오프닝 파일로 돌아가면 딴 말·딴 목소리입니다',
    );
    expect(
      repository.synthesizedTexts.where((String t) => t == '그렇게 생각했구나.'),
      hasLength(1),
      reason: '같은 문장을 다시 합성하면 미세하게 다른 소리가 납니다 - 캐시에서 꺼내야 합니다',
    );
  });

  testWidgets('전개 화면 다시 듣기도 같은 문장을 다시 합성하지 않는다', (WidgetTester tester) async {
    final _StoryNarrationSpyRepository repository =
        _StoryNarrationSpyRepository();
    final _SpyAudioPlayer audioPlayer = _SpyAudioPlayer();
    await pumpPlay(
      tester,
      repository: repository,
      audioPlayer: audioPlayer,
      settle: false,
    );
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(repository.synthesizedTexts, <String>['첫 문장이에요.']);

    await tester.tap(find.byTooltip('다시 듣기'));
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }

    expect(
      repository.synthesizedTexts,
      <String>['첫 문장이에요.'],
      reason: '되감아 들을 때마다 새로 합성하면 같은 문장이 조금씩 다른 소리로 들립니다',
    );
    expect(audioPlayer.playedUrls, hasLength(2), reason: '소리는 두 번 나야 합니다');
  });

  testWidgets('1280x720 범용 대화 템플릿 골든', (WidgetTester tester) async {
    await pumpPlay(tester);
    await tester.pump();

    await expectLater(
      find.byType(PlayPage),
      matchesGoldenFile('goldens/play_dialogue_template.png'),
    );
  });
}

/// 여러 문장짜리 캐릭터 대사로 시작하는 DIALOGUE 세션. 이어 재생·이전 발화
/// 잔상처럼 "대사가 흘러가는 중"을 봐야 하는 테스트가 씁니다.
class _DialogueSpyRepository implements PlayRepository {
  final List<String> synthesizedTexts = <String>[];

  /// 이 장면(scene-2)에서 아이가 마지막으로 한 발화. 이어하기로 들어오면
  /// 화면에 되살아나야 합니다.
  String? restoredChildText;

  /// `sceneMessages` 가 어떤 장면으로 불렸는지.
  final List<String> sceneMessageRequests = <String>[];

  /// 세션 전체 기록입니다 - 이전 장면(scene-1) 발화가 섞여 있습니다. 화면이
  /// 이걸 그대로 쓰면 남의 장면 발화를 띄우게 됩니다.
  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      PlaySessionSnapshot(
        phase: PlayPhase.dialogue,
        currentScene: const PlayScene(
          sceneId: 'scene-2',
          sceneOrder: 2,
          sceneType: PlaySceneType.dialogue,
          narrationSentences: <String>[],
          characterName: '토리',
          maxTurns: 4,
        ),
        openingText: '첫 문장이에요. 두 번째 문장이에요. 세 번째 문장이에요.',
        messages: <PlayMessage>[
          const PlayMessage(
            messageId: 'm0',
            speaker: PlaySpeaker.child,
            turnOrder: 1,
            text: '지난 장면에서 한 말이에요.',
          ),
          if (restoredChildText != null)
            PlayMessage(
              messageId: 'm1',
              speaker: PlaySpeaker.child,
              turnOrder: 3,
              text: restoredChildText!,
            ),
        ],
      );

  @override
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) async {
    sceneMessageRequests.add(sceneId);
    if (sceneId != 'scene-2' || restoredChildText == null) {
      return const <PlayMessage>[];
    }
    return <PlayMessage>[
      PlayMessage(
        messageId: 'm1',
        speaker: PlaySpeaker.child,
        turnOrder: 3,
        text: restoredChildText!,
      ),
    ];
  }

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) =>
      resume(sessionId);

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(text: '', audioUrl: null, alreadyOpened: true);

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async =>
      const PlayTranscription(text: '', confidence: null, lowConfidence: false);

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async {
    synthesizedTexts.add(text);
    return const PlaySpeechAudio(audioUrl: 'stub://dialogue');
  }

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
    characterText: null,
    characterAudioUrl: null,
    mission: null,
    sceneTransition: null,
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

/// 대화1 -> (전환) -> 전개2 -> 대화2 흐름을 그대로 태워 보는 가짜입니다.
/// 장면이 바뀔 때 이전 장면의 아이 발화가 남는지 보려면 실제로 장면을
/// 넘겨 봐야 합니다.
class _SceneFlowSpyRepository implements PlayRepository {
  bool _transitioned = false;

  /// 진짜 서버처럼 `messages` 는 **세션 전체** 기록입니다 - 장면이 넘어가도
  /// 대화1에서 한 발화가 그대로 들어 있습니다.
  static const List<PlayMessage> _sessionMessages = <PlayMessage>[
    PlayMessage(
      messageId: 'm1',
      speaker: PlaySpeaker.child,
      turnOrder: 2,
      text: '나는 이렇게 생각해요',
    ),
  ];

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async => _transitioned
      ? const PlaySessionSnapshot(
          phase: PlayPhase.story,
          currentScene: PlayScene(
            sceneId: 'scene-2',
            sceneOrder: 2,
            sceneType: PlaySceneType.story,
            narrationSentences: <String>['그래서 둘은 길을 떠났어요.'],
          ),
          messages: _sessionMessages,
        )
      : const PlaySessionSnapshot(
          phase: PlayPhase.dialogue,
          currentScene: PlayScene(
            sceneId: 'scene-1',
            sceneOrder: 1,
            sceneType: PlaySceneType.dialogue,
            narrationSentences: <String>[],
            characterName: '토리',
            maxTurns: 4,
          ),
          openingText: '무슨 생각이 들었어?',
        );

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) async =>
      const PlaySessionSnapshot(
        phase: PlayPhase.dialogue,
        currentScene: PlayScene(
          sceneId: 'scene-3',
          sceneOrder: 3,
          sceneType: PlaySceneType.dialogue,
          narrationSentences: <String>[],
          characterName: '모리',
          maxTurns: 4,
        ),
        openingText: '나는 두 번째 캐릭터야.',
      );

  /// 장면으로 걸러 주는 조회 - 대화1의 발화는 대화1에서만 나옵니다.
  @override
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) async => sceneId == 'scene-1'
      ? const <PlayMessage>[
          PlayMessage(
            messageId: 'm1',
            speaker: PlaySpeaker.child,
            turnOrder: 2,
            text: '나는 이렇게 생각해요',
          ),
        ]
      : const <PlayMessage>[];

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(text: '', audioUrl: null, alreadyOpened: true);

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async =>
      const PlayTranscription(
        text: '나는 이렇게 생각해요',
        confidence: .9,
        lowConfidence: false,
      );

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async => const PlaySpeechAudio(audioUrl: 'stub://flow');

  @override
  Future<PlayTurnResult> submitUtterance(
    String sessionId, {
    required String text,
    String? missionId,
    String? sttRawText,
    double? sttConfidence,
    int sttRetryCount = 0,
    String? idempotencyKey,
  }) async {
    _transitioned = true;
    return const PlayTurnResult(
      characterText: '좋은 생각이야!',
      characterAudioUrl: null,
      mission: null,
      sceneTransition: PlaySceneTransition(
        next: PlayTransitionTarget.scene,
        nextSceneId: 'scene-2',
        nextSceneOrder: 2,
        nextSceneType: PlaySceneType.story,
      ),
    );
  }

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

/// 목소리가 바뀌는 자리를 보는 가짜입니다. 실서버와 같은 모양으로:
///
/// - **오프닝 고정 대사**에는 사전 렌더 음성(파일 + 문장별 실측 구간)이 옵니다.
/// - **LLM 대답**에는 audioUrl 이 없습니다 → 화면이 /api/tts 로 합성합니다.
/// - 합성은 `tts://<문장>` 을 돌려주고 어떤 문장을 몇 번 불렀는지 기록합니다.
class _VoiceSpyRepository implements PlayRepository {
  final List<String> synthesizedTexts = <String>[];

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      const PlaySessionSnapshot(
        phase: PlayPhase.dialogue,
        storyId: 'story-1',
        currentScene: PlayScene(
          sceneId: 'scene-1',
          sceneOrder: 1,
          sceneType: PlaySceneType.dialogue,
          narrationSentences: <String>[],
          characterName: '마을 이장',
          maxTurns: 4,
        ),
        openingText: '큰일이 났네. 무슨 뾰족한 방법이 없겠는가?',
        openingAudioUrl: '/tts/opening.mp3',
        openingAudioTimings: <PlayAudioTiming>[
          PlayAudioTiming(index: 0, start: 0, end: 3),
          PlayAudioTiming(index: 1, start: 3, end: 6),
        ],
      );

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) =>
      resume(sessionId);

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(
        text: '큰일이 났네. 무슨 뾰족한 방법이 없겠는가?',
        audioUrl: '/tts/opening.mp3',
        alreadyOpened: true,
      );

  @override
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) async => const <PlayMessage>[];

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async =>
      const PlayTranscription(
        text: '같이 방법을 찾아봐요.',
        confidence: .94,
        lowConfidence: false,
      );

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async {
    synthesizedTexts.add(text);
    return PlaySpeechAudio(audioUrl: 'tts://$text');
  }

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
    // 실서버와 같습니다 - LLM 대답에는 사전 렌더 음성이 없습니다.
    characterText: '그렇게 생각했구나.',
    characterAudioUrl: null,
    mission: null,
    sceneTransition: null,
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

class _FakeVoiceRecorder implements MissionVoiceRecorder {
  const _FakeVoiceRecorder();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> start() async => true;

  @override
  Future<Uint8List?> stop() async => Uint8List.fromList(<int>[1, 2, 3]);
}

/// 진짜 재생기처럼 [playUrl]이 "재생이 끝날 때까지" 안 끝나고, [stop]이 그
/// 기다림을 풀어 줍니다. 소리 끄기가 실제로 소리를 끊는지 보려면 이 동작이
/// 있어야 합니다 - 곧바로 끝나 버리는 가짜로는 아무것도 확인되지 않습니다.
class _SpyAudioPlayer implements StoryAudioPlayer {
  /// 테스트가 재생 위치를 직접 흘려 자막 넘김(timings)을 검증한다.
  final StreamController<Duration> positions =
      StreamController<Duration>.broadcast();

  @override
  Stream<Duration> get onPosition => positions.stream;

  void emitPosition(Duration position) => positions.add(position);

  int playCount = 0;
  int stopCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  bool muted = false;
  Completer<void>? _playing;
  bool _paused = false;

  /// 실제로 튼 주소들. **무엇을 틀었는지**까지 봐야 다시 듣기가 같은 소리를
  /// 내는지 알 수 있습니다(횟수만으로는 다른 음성을 틀어도 통과합니다).
  final List<String> playedUrls = <String>[];

  @override
  Future<void> playUrl(String url) {
    playedUrls.add(url);
    playCount++;
    _paused = false;
    final Completer<void> completer = Completer<void>();
    _playing = completer;
    return completer.future;
  }

  /// 진짜 재생기처럼 기다림을 **풀지 않습니다** - 멈춘 문장을 아직 다 듣지
  /// 않았으니, 여기서 풀어 주면 부르는 쪽이 다음 문장으로 넘어가 버립니다.
  @override
  Future<void> pause() async {
    if (_playing == null || _paused) return;
    pauseCount++;
    _paused = true;
  }

  @override
  Future<void> resume() async {
    if (!_paused) return;
    resumeCount++;
    _paused = false;
  }

  /// 진짜 재생기처럼 소리만 죽입니다 - 재생은 그대로 흘러갑니다.
  @override
  Future<void> setMuted(bool value) async {
    muted = value;
  }

  @override
  bool get canResume => _paused && _playing != null;

  @override
  Future<void> stop() async {
    stopCount++;
    _paused = false;
    _finish();
  }

  @override
  Future<void> dispose() async {
    await stop();
  }

  /// 문장이 끝까지 재생돼 저절로 끝난 상황. [stop] 과 달리 끊은 것이 아니라서
  /// [stopCount] 를 올리지 않습니다.
  void finishPlayback() => _finish();

  void _finish() {
    final Completer<void>? playing = _playing;
    _playing = null;
    if (playing != null && !playing.isCompleted) playing.complete();
  }
}

class _FakeAudioPlayer implements StoryAudioPlayer {
  @override
  Stream<Duration> get onPosition => const Stream<Duration>.empty();

  const _FakeAudioPlayer();

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playUrl(String url) async {}

  @override
  bool get canResume => false;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}
}

/// `POST /sessions/{id}/stop`(→ [stop])이 불렸는지만 기록하는 최소 가짜입니다.
/// 나가기가 세션을 끝내지 않는지 보는 데 씁니다. 그 외 메서드는 대화 화면이
/// 뜨는 데 필요한 만큼만 값을 돌려줍니다.
class _StopSpyRepository implements PlayRepository {
  String? stoppedSessionId;

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      const PlaySessionSnapshot(
        phase: PlayPhase.dialogue,
        currentScene: PlayScene(
          sceneId: 'scene-1',
          sceneOrder: 1,
          sceneType: PlaySceneType.dialogue,
          narrationSentences: <String>[],
          characterName: '토리',
          maxTurns: 4,
        ),
        openingText: '이럴 때는 어떻게 하면 좋을까?',
      );

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) =>
      resume(sessionId);

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(
        text: '이럴 때는 어떻게 하면 좋을까?',
        audioUrl: null,
        alreadyOpened: true,
      );

  @override
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) async => const <PlayMessage>[];

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async =>
      const PlayTranscription(text: '', confidence: null, lowConfidence: false);

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async => const PlaySpeechAudio(audioUrl: 'stub://audio');

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
    characterText: null,
    characterAudioUrl: null,
    mission: null,
    sceneTransition: null,
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
  Future<void> stop(String sessionId) async {
    stoppedSessionId = sessionId;
  }
}

/// 첫 녹음은 422 `STT_EMPTY_TEXT`로 실패시키고, 그다음부터는 성공시킵니다.
/// 결국 제출되는 `sttRetryCount`를 [lastSttRetryCount]에 기록합니다.
class _SttRetrySpyRepository implements PlayRepository {
  _SttRetrySpyRepository({this.firstFailureCode = 'STT_EMPTY_TEXT'});

  /// 첫 변환에서 서버가 돌려줄 실패 코드. 무음(`STT_EMPTY_TEXT`)과 녹음 초과
  /// (`AUDIO_TOO_LARGE`)는 아이 입장에서 같은 자리라 같은 흐름을 타야 합니다.
  final String firstFailureCode;

  int _transcribeCalls = 0;
  int? lastSttRetryCount;

  /// true면 모든 인식 결과를 저신뢰로 돌려준다 - 확인 단계 테스트용.
  bool lowConfidenceAlways = false;

  /// 제출된 발화들. 확인 단계가 "제출을 잡아 두는지"를 이걸로 판정한다.
  final List<String> submittedTexts = <String>[];
  final List<String?> submittedRawTexts = <String?>[];

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      const PlaySessionSnapshot(
        phase: PlayPhase.dialogue,
        currentScene: PlayScene(
          sceneId: 'scene-1',
          sceneOrder: 1,
          sceneType: PlaySceneType.dialogue,
          narrationSentences: <String>[],
          characterName: '토리',
          maxTurns: 4,
        ),
        openingText: '이럴 때는 어떻게 하면 좋을까?',
      );

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) =>
      resume(sessionId);

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(
        text: '이럴 때는 어떻게 하면 좋을까?',
        audioUrl: null,
        alreadyOpened: true,
      );

  @override
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) async => const <PlayMessage>[];

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async {
    _transcribeCalls++;
    if (lowConfidenceAlways) {
      return const PlayTranscription(
        text: '방귀를 참으면 안 돼요',
        rawText: '방비를 참으면 안 돼요',
        confidence: .3,
        lowConfidence: true,
      );
    }
    if (_transcribeCalls == 1) {
      throw ServerFailure(message: '변환 실패', code: firstFailureCode);
    }
    return const PlayTranscription(
      text: '나는 이렇게 생각해요',
      confidence: .9,
      lowConfidence: false,
    );
  }

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async => const PlaySpeechAudio(audioUrl: 'stub://audio');

  @override
  Future<PlayTurnResult> submitUtterance(
    String sessionId, {
    required String text,
    String? missionId,
    String? sttRawText,
    double? sttConfidence,
    int sttRetryCount = 0,
    String? idempotencyKey,
  }) async {
    lastSttRetryCount = sttRetryCount;
    submittedTexts.add(text);
    submittedRawTexts.add(sttRawText);
    return const PlayTurnResult(
      characterText: null,
      characterAudioUrl: null,
      mission: null,
      sceneTransition: null,
    );
  }

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

/// 무엇을 말해도 422 `STT_EMPTY_TEXT` 로 실패시키는 가짜입니다. 세 번 이어서
/// 실패했을 때 문장 카드가 내려오는지, 고른 문장이 어떤 값으로 나가는지를
/// 보는 데 씁니다. [sceneOrder] 를 3·5·7·9 밖으로 두면 선택지 음성이 없는
/// 장면이 됩니다.
/// 음성 흐름(상한 자동 종료, 확인 단계) 검증용.
/// 변환 호출 수, 제출된 텍스트, 마지막 재시도 횟수를 기록합니다.
class _AutoStopSpyRepository implements PlayRepository {
  _AutoStopSpyRepository({this.lowConfidence = false});

  final bool lowConfidence;
  int transcribeCalls = 0;
  final List<String> submittedTexts = <String>[];
  int? lastSttRetryCount;

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      const PlaySessionSnapshot(
        phase: PlayPhase.dialogue,
        currentScene: PlayScene(
          sceneId: 'scene-1',
          sceneOrder: 1,
          sceneType: PlaySceneType.dialogue,
          narrationSentences: <String>[],
          characterName: '토리',
          maxTurns: 4,
        ),
        openingText: '이럴 때는 어떻게 하면 좋을까?',
      );

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) =>
      resume(sessionId);

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(
        text: '이럴 때는 어떻게 하면 좋을까?',
        audioUrl: null,
        alreadyOpened: true,
      );

  @override
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) async => const <PlayMessage>[];

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async {
    transcribeCalls++;
    return PlayTranscription(
      text: '오래오래 말한 내 생각이에요',
      confidence: lowConfidence ? .41 : .9,
      lowConfidence: lowConfidence,
    );
  }

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async => const PlaySpeechAudio(audioUrl: 'stub://audio');

  @override
  Future<PlayTurnResult> submitUtterance(
    String sessionId, {
    required String text,
    String? missionId,
    String? sttRawText,
    double? sttConfidence,
    int sttRetryCount = 0,
    String? idempotencyKey,
  }) async {
    submittedTexts.add(text);
    lastSttRetryCount = sttRetryCount;
    return const PlayTurnResult(
      characterText: null,
      characterAudioUrl: null,
      mission: null,
      sceneTransition: null,
    );
  }

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

class _SttChoiceSpyRepository implements PlayRepository {
  _SttChoiceSpyRepository({this.sceneOrder = 3});

  final int sceneOrder;

  int submitCount = 0;
  String? lastText;
  int? lastSttRetryCount;
  String? lastSttRawText;
  double? lastSttConfidence;

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      PlaySessionSnapshot(
        phase: PlayPhase.dialogue,
        currentScene: PlayScene(
          sceneId: 'scene-$sceneOrder',
          sceneOrder: sceneOrder,
          sceneType: PlaySceneType.dialogue,
          narrationSentences: const <String>[],
          characterName: '토리',
          maxTurns: 4,
        ),
        openingText: '이럴 때는 어떻게 하면 좋을까?',
      );

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) =>
      resume(sessionId);

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(
        text: '이럴 때는 어떻게 하면 좋을까?',
        audioUrl: null,
        alreadyOpened: true,
      );

  @override
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) async => const <PlayMessage>[];

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async {
    throw const ServerFailure(message: '무음이거나 인식 실패', code: 'STT_EMPTY_TEXT');
  }

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async => const PlaySpeechAudio(audioUrl: 'stub://audio');

  @override
  Future<PlayTurnResult> submitUtterance(
    String sessionId, {
    required String text,
    String? missionId,
    String? sttRawText,
    double? sttConfidence,
    int sttRetryCount = 0,
    String? idempotencyKey,
  }) async {
    submitCount++;
    lastText = text;
    lastSttRetryCount = sttRetryCount;
    lastSttRawText = sttRawText;
    lastSttConfidence = sttConfidence;
    return const PlayTurnResult(
      characterText: '그렇게 생각했구나.',
      characterAudioUrl: null,
      mission: null,
      sceneTransition: null,
    );
  }

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

/// STORY(전개) 장면으로 들어가서 문장별 `synthesizeSpeech` 호출을 기록합니다.
class _StoryNarrationSpyRepository implements PlayRepository {
  final List<String> synthesizedTexts = <String>[];
  final List<String?> synthesizedCharacterNames = <String?>[];

  /// 장면 하나가 끝났을 때(=completeStoryScene 호출) 다음으로 돌려줄 장면.
  /// null 이면 같은 장면을 반복합니다(무한 루프 방지는 호출부의 pump 횟수가
  /// 책임짐). 두 번째 장면부터 내레이션이 안 나온다는 버그를 재현하려면
  /// 이걸 채워서 서로 다른 장면으로 실제로 넘어가게 합니다.
  PlaySessionSnapshot? nextSceneOnComplete;

  /// 첫 스냅숏 교체용 - 사전 렌더 내레이션(narrationAudioUrl) 시나리오처럼
  /// 기본 장면과 다른 모양이 필요할 때 채웁니다.
  PlaySessionSnapshot? initialSnapshot;

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      initialSnapshot ??
      const PlaySessionSnapshot(
        phase: PlayPhase.story,
        currentScene: PlayScene(
          sceneId: 'scene-1',
          sceneOrder: 1,
          sceneType: PlaySceneType.story,
          narrationSentences: <String>['첫 문장이에요.', '두 번째 문장이에요.'],
        ),
      );

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) async =>
      nextSceneOnComplete ?? await resume(sessionId);

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(text: '', audioUrl: null, alreadyOpened: true);

  @override
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) async => const <PlayMessage>[];

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async =>
      const PlayTranscription(text: '', confidence: null, lowConfidence: false);

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async {
    synthesizedTexts.add(text);
    synthesizedCharacterNames.add(characterName);
    return const PlaySpeechAudio(audioUrl: 'stub://narration');
  }

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
    characterText: null,
    characterAudioUrl: null,
    mission: null,
    sceneTransition: null,
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
