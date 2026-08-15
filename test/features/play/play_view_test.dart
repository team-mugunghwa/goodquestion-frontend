import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/router/app_routes.dart';
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

  testWidgets('나가기는 실수 방지를 위해 확인하고, 되돌릴 수 없다고 알려준다', (
    WidgetTester tester,
  ) async {
    await pumpPlay(tester);

    await tester.tap(find.byTooltip('나가기'));
    await tester.pumpAndSettle();
    expect(find.text('이야기를 그만할까요?'), findsOneWidget);
    // stop 은 되돌릴 수 없습니다 - "저장해 둘게요" 처럼 다시 들을 수 있는
    // 것으로 오해하게 하면 안 됩니다.
    expect(find.text('그만하면 다시 이어서 들을 수 없어요. 처음부터 다시 시작해야 해요.'), findsOneWidget);
  });

  testWidgets('그만하기를 확정하면 서버에도 stop 을 알린다', (WidgetTester tester) async {
    final _StopSpyRepository repository = _StopSpyRepository();
    await pumpPlayInRouter(tester, repository: repository);

    await tester.tap(find.byTooltip('나가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('그만하기'));
    await tester.pumpAndSettle();

    expect(repository.stoppedSessionId, 'preview-session');
  });

  testWidgets('그만하기를 확정하면 재생 화면에서 실제로 빠져나온다', (WidgetTester tester) async {
    // 이 화면은 홈·이야기 상세에서 go 로 들어와 스택에 되돌아갈 화면이
    // 없습니다. pop 계열로 나가려 하면 조용히 아무 일도 일어나지 않아,
    // 아이는 나가기를 눌러도 그대로 남습니다.
    await pumpPlayInRouter(tester, repository: _StopSpyRepository());
    expect(find.byType(PlayPage), findsOneWidget);

    await tester.tap(find.byTooltip('나가기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('그만하기'));
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

    // 다시 녹음합니다 - 이번에는 성공합니다.
    await tester.tap(find.byTooltip('눌러서 말하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('말하기 완료'));
    await tester.pumpAndSettle();

    expect(
      repository.lastSttRetryCount,
      1,
      reason: '무음으로 한 번 다시 말했으니 재시도 횟수 1이 실려 가야 합니다',
    );
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

  testWidgets('소리 끄기를 누르면 아이콘만이 아니라 나오던 소리도 실제로 멈춘다', (
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
      audioPlayer.stopCount,
      greaterThan(0),
      reason: '아이콘만 바꾸면 안 됩니다 - 나오고 있던 음성을 실제로 끊어야 합니다',
    );
    expect(find.byTooltip('소리 켜기'), findsOneWidget);

    // 소리를 끈 뒤에도 이야기는 무음으로 계속 흐르고, 새로 재생하지는 않습니다.
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 8));
    for (int i = 0; i < 5; i++) {
      await tester.pump();
    }
    expect(audioPlayer.playCount, 1, reason: '소리를 끈 뒤에는 다음 문장도 재생하지 않아야 합니다');
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

  /// 이어하기로 복원됐을 때 스냅샷에 들어 있는 지난 턴의 아이 발화.
  String? restoredChildText;

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
          if (restoredChildText != null)
            PlayMessage(
              messageId: 'm1',
              speaker: PlaySpeaker.child,
              turnOrder: 1,
              text: restoredChildText!,
            ),
        ],
      );

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
  int playCount = 0;
  int stopCount = 0;
  Completer<void>? _playing;

  @override
  Future<void> playUrl(String url) {
    playCount++;
    final Completer<void> completer = Completer<void>();
    _playing = completer;
    return completer.future;
  }

  @override
  Future<void> stop() async {
    stopCount++;
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
  const _FakeAudioPlayer();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playUrl(String url) async {}

  @override
  Future<void> stop() async {}
}

/// "그만하기"가 실제로 `POST /sessions/{id}/stop`(→ [stop])을 부르는지만
/// 확인하는 최소 가짜입니다. 그 외 메서드는 대화 화면이 뜨는 데 필요한
/// 만큼만 값을 돌려줍니다.
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
  Future<void> stop(String sessionId) async {
    stoppedSessionId = sessionId;
  }
}

/// 첫 녹음은 422 `STT_EMPTY_TEXT`로 실패시키고, 그다음부터는 성공시킵니다.
/// 결국 제출되는 `sttRetryCount`를 [lastSttRetryCount]에 기록합니다.
class _SttRetrySpyRepository implements PlayRepository {
  int _transcribeCalls = 0;
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
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async {
    _transcribeCalls++;
    if (_transcribeCalls == 1) {
      throw const ServerFailure(message: '무음이거나 인식 실패', code: 'STT_EMPTY_TEXT');
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
    return const PlayTurnResult(
      characterText: null,
      characterAudioUrl: null,
      mission: null,
      sceneTransition: null,
    );
  }

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

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
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
  Future<void> stop(String sessionId) async {}
}
