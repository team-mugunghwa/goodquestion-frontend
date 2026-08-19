import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/play/domain/entities/play_session.dart';
import 'features/play/domain/repositories/play_repository.dart';
import 'features/play/presentation/views/play_view.dart';
import 'features/play/presentation/voice/mission_voice_recorder.dart';
import 'features/play/presentation/voice/story_audio_player.dart';
import 'features/story/domain/entities/story_catalog.dart';
import 'features/story/domain/entities/story_detail.dart';
import 'features/story/domain/repositories/story_repository.dart';

/// 백엔드·로그인 없이 **전개(내레이션) 화면의 멈춤 카드**를 확인하는 개발용
/// 진입점입니다. 멈춤 → 처음부터 다시하기 → 확인까지 실제로 눌러 볼 수
/// 있습니다.
///
/// 실행:
/// flutter run -d chrome -t lib/main_story_pause_preview.dart --web-port 7361
///
/// **라우터를 세워 둡니다.** 처음부터 다시하기는 새 세션 주소로 `go` 하므로,
/// `home:` 한 장짜리 앱에서는 확인을 눌러도 아무 일도 일어나지 않습니다.
void main() => runApp(_StoryPausePreviewApp());

class _StoryPausePreviewApp extends StatelessWidget {
  _StoryPausePreviewApp();

  final _PreviewPlayRepository _play = _PreviewPlayRepository();
  final _PreviewStoryRepository _stories = _PreviewStoryRepository();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'GoodQuestion 전개 멈춤 화면 미리보기',
      theme: AppTheme.light,
      routerConfig: GoRouter(
        initialLocation: AppRoutes.playOf('preview-session-1', totalScenes: 2),
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.home,
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('홈 화면 자리입니다(미리보기)'))),
          ),
          GoRoute(
            path: AppRoutes.playPath,
            builder: (_, GoRouterState state) {
              final String sessionId =
                  state.pathParameters[AppRoutes.sessionIdParam]!;
              // 진짜 라우터와 같은 모양입니다 - 세션 id 를 키로 달아야
              // 처음부터 다시하기로 새 세션에 들어올 때 화면이 새로 섭니다.
              return PlayPage(
                key: ValueKey<String>(sessionId),
                sessionId: sessionId,
                totalScenes: 2,
                repository: _play,
                storyRepository: _stories,
                voiceRecorder: const _PreviewVoiceRecorder(),
                audioPlayer: _PreviewAudioPlayer(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 전개 장면 둘을 차례로 들려주고, 다 끝나면 대화로 넘어갑니다. 세션마다
/// 진행 자리를 따로 들고 있어서, 처음부터 다시하기로 새 세션에 들어오면
/// **첫 문장부터** 다시 시작하는 것을 눈으로 볼 수 있습니다.
class _PreviewPlayRepository implements PlayRepository {
  final Map<String, int> _sceneIndex = <String, int>{};

  /// 끝난(STOPPED) 세션들. 처음부터 다시하기가 듣던 세션을 실제로 끝내는지
  /// 콘솔로 확인하는 용도입니다.
  final Set<String> stopped = <String>{};

  static const List<List<String>> _scenes = <List<String>>[
    <String>[
      '옛날 옛적에, 방귀를 아주 잘 뀌는 며느리가 살았어요.',
      '어느 날 아침, 며느리가 참고 참다가 그만 방귀를 뀌었어요.',
      '집이 흔들리고 마당의 항아리가 데굴데굴 굴렀어요.',
    ],
    <String>['놀란 식구들이 모두 마당으로 뛰어나왔어요.', '며느리는 얼굴이 새빨개졌어요.'],
  ];

  PlaySessionSnapshot _snapshotFor(String sessionId) {
    final int index = _sceneIndex[sessionId] ?? 0;
    if (index >= _scenes.length) {
      return const PlaySessionSnapshot(
        phase: PlayPhase.dialogue,
        storyId: 'preview-story',
        currentScene: PlayScene(
          sceneId: 'preview-dialogue',
          sceneOrder: 3,
          sceneType: PlaySceneType.dialogue,
          narrationSentences: <String>[],
          imageUrl: 'assets/images/dialogue/banggui_dialogue_1.png',
          characterName: '방귀쟁이 며느리',
          maxTurns: 4,
        ),
        openingText: '내 방귀 때문에 모두가 놀랐어. 나는 어떻게 하면 좋을까?',
      );
    }
    return PlaySessionSnapshot(
      phase: PlayPhase.story,
      storyId: 'preview-story',
      currentScene: PlayScene(
        sceneId: 'preview-scene-${index + 1}',
        sceneOrder: index + 1,
        sceneType: PlaySceneType.story,
        narrationSentences: _scenes[index],
        imageUrl: 'assets/images/dialogue/banggui_dialogue_1.png',
      ),
    );
  }

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async {
    _sceneIndex.putIfAbsent(sessionId, () => 0);
    return _snapshotFor(sessionId);
  }

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) async {
    _sceneIndex[sessionId] = (_sceneIndex[sessionId] ?? 0) + 1;
    return _snapshotFor(sessionId);
  }

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(
        text: '내 방귀 때문에 모두가 놀랐어. 나는 어떻게 하면 좋을까?',
        audioUrl: null,
        alreadyOpened: true,
      );

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async => const PlaySpeechAudio(audioUrl: 'preview://speech');

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async =>
      const PlayTranscription(
        text: '며느리를 도와주고 싶어요.',
        confidence: .94,
        lowConfidence: false,
      );

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
    characterText: '그렇게 말해 줘서 고마워.',
    characterAudioUrl: null,
    mission: null,
    sceneTransition: null,
  );

  @override
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) async => const <PlayMessage>[];

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

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
    stopped.add(sessionId);
    debugPrint('[preview] 세션 끝냄: $sessionId');
  }
}

/// 처음부터 다시하기가 부르는 새 세션 발급기. 서버 왕복을 흉내 내려고 조금
/// 기다립니다 - 그동안 확인 카드가 잠기는 모습을 볼 수 있습니다.
class _PreviewStoryRepository implements StoryRepository {
  int _issued = 1;

  @override
  Future<StoryCatalog> getCatalog() => throw UnimplementedError();

  @override
  Future<StoryDetail?> getStoryDetail(String storyId) =>
      throw UnimplementedError();

  @override
  Future<String> startSession(String storyId) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _issued++;
    debugPrint('[preview] 새 세션 만듦: preview-session-$_issued');
    return 'preview-session-$_issued';
  }
}

class _PreviewVoiceRecorder implements MissionVoiceRecorder {
  const _PreviewVoiceRecorder();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> start() async => true;

  @override
  Future<Uint8List?> stop() async => Uint8List.fromList(<int>[1, 2, 3]);
}

/// 문장 하나를 2.2초쯤 읽는 시늉만 합니다. 멈춤/이어 듣기가 실제 재생기처럼
/// 굴러야 해서 [canResume] 도 흉내 냅니다.
class _PreviewAudioPlayer implements StoryAudioPlayer {
  bool _paused = false;
  bool _playing = false;

  @override
  Stream<Duration> get onPosition => const Stream<Duration>.empty();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playUrl(String url) async {
    _playing = true;
    _paused = false;
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    while (_paused) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    _playing = false;
  }

  @override
  bool get canResume => _paused && _playing;

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<void> pause() async {
    if (_playing) _paused = true;
  }

  @override
  Future<void> resume() async {
    _paused = false;
  }

  @override
  Future<void> stop() async {
    _paused = false;
    _playing = false;
  }
}
