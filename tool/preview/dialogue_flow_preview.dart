// 이야기 전개 -> 대화 -> 전개 -> 대화 흐름 확인용 프리뷰. 제품 코드가 아니다.
//
//   flutter run -d chrome -t tool/preview/dialogue_flow_preview.dart
//
// 서버가 내려주는 장면 시퀀스(방귀 뀌는 며느리 9장면)를 그대로 흉내내는 스텁으로 실제 PlayPage 를
// 돌린다. 화면 전환 로직만 보는 자리라 STT/TTS 는 타지 않는다 - 실서버 /api/stt 가 500이라
// 실기기로는 대화 턴을 넘길 수 없어서 흐름의 뒷부분을 확인할 방법이 이것뿐이다.
//
// 스텁이므로 API 스키마 불일치는 잡지 못한다. 그건 실서버 연결로 따로 확인해야 한다.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:goodquestion/core/router/app_routes.dart';
import 'package:goodquestion/features/play/domain/entities/play_session.dart';
import 'package:goodquestion/features/play/domain/repositories/play_repository.dart';
import 'package:goodquestion/features/play/presentation/views/play_view.dart';
import 'package:goodquestion/features/play/presentation/voice/mission_voice_recorder.dart';
import 'package:goodquestion/features/play/presentation/voice/story_audio_player.dart';

void main() => runApp(const FlowPreviewApp());

String _sceneId(int order) =>
    '33333333-3333-3333-3333-${order.toString().padLeft(12, '0')}';

/// 시드의 9장면. 내레이션은 흐름만 보는 자리라 한 문장으로 줄였다 - 문장마다 최소 2.4초를
/// 기다리므로 원문을 그대로 넣으면 한 바퀴 도는 데 몇 분이 걸린다.
class _Scene {
  const _Scene(
    this.order,
    this.type,
    this.narration, {
    this.character,
    this.opening,
    this.elements = const <String>[],
    this.resultImage,
  });

  final int order;
  final PlaySceneType type;
  final String narration;
  final String? character;
  final String? opening;
  final List<String> elements;
  final String? resultImage;

  PlayScene toEntity() => PlayScene(
    sceneId: _sceneId(order),
    sceneOrder: order,
    sceneType: type,
    narrationSentences: type == PlaySceneType.story
        ? <String>[narration]
        : const <String>[],
    characterName: character,
    maxTurns: type == PlaySceneType.dialogue ? 4 : null,
  );
}

const List<_Scene> _script = <_Scene>[
  _Scene(1, PlaySceneType.story, '옛날 어느 마을에 방귀를 아주 크게 뀌는 며느리가 살았습니다.'),
  _Scene(2, PlaySceneType.story, '며느리는 방귀가 나올 때마다 꾹꾹 참았고, 배는 점점 빵빵해졌습니다.'),
  _Scene(
    3,
    PlaySceneType.dialogue,
    '',
    character: '방귀쟁이 며느리',
    opening: 'ㅇㅇ아, 내 방귀가 너무 크다는 걸 알면 가족들이 나를 이상하게 생각하지 않을까?',
    elements: <String>['EMOTION', 'PERSPECTIVE', 'SOLUTION'],
  ),
  _Scene(4, PlaySceneType.story, '며느리가 참던 방귀를 뀌자 시아버지의 갓이 휙 날아가 버렸습니다.'),
  _Scene(
    5,
    PlaySceneType.dialogue,
    '',
    character: '시아버지',
    opening: '아이고, 이게 무슨 일이냐! 이렇게 창피한 며느리와 함께 못 살겠다! 그렇지 않니?',
    elements: <String>['PERSPECTIVE', 'EMPATHY', 'REASON', 'REQUEST'],
  ),
  _Scene(6, PlaySceneType.story, '길가에 아주 높은 배나무가 서 있었지만 아무도 배를 딸 수 없었습니다.'),
  _Scene(
    7,
    PlaySceneType.dialogue,
    '',
    character: '마을 이장',
    opening: '이 배나무는 너무 높아서 아무도 딸 수가 없었단다. 무슨 뾰족한 방법이 없겠는가?',
    elements: <String>['SOLUTION', 'REASON', 'REQUEST', 'RESULT'],
    resultImage:
        'assets/images/dialogue/banggui/scene_07/scene_background_blurred.webp',
  ),
  _Scene(8, PlaySceneType.story, '시아버지는 며느리의 방귀가 특별한 힘이라는 것을 깨닫고 사과했습니다.'),
  _Scene(
    9,
    PlaySceneType.dialogue,
    '',
    character: '방귀쟁이 며느리',
    opening: '내 방귀가 누군가에게 도움이 될 수 있다는 걸 처음 알았어. 부끄러워하지 않아도 될까?',
    elements: <String>['EMOTION', 'PERSPECTIVE', 'RESULT', 'SOLUTION'],
  ),
];

/// 서버 장면 진행을 흉내낸다. 상태는 "지금 몇 번째 장면인지"와 "이 장면에서 몇 턴 했는지"뿐이다.
class _FlowRepository implements PlayRepository {
  _FlowRepository(this.onLog);

  final void Function(String) onLog;

  int _index = 0;
  int _turn = 0;
  final Set<String> _accumulated = <String>{};

  _Scene get _scene => _script[_index];

  PlaySessionSnapshot _snapshot() {
    onLog(
      '장면 ${_scene.order} '
      '${_scene.type == PlaySceneType.story ? "전개" : "대화"}'
      '${_scene.character != null ? "(${_scene.character})" : ""}',
    );
    return PlaySessionSnapshot(
      phase: _scene.type == PlaySceneType.story
          ? PlayPhase.story
          : PlayPhase.dialogue,
      currentScene: _scene.toEntity(),
      openingText: _scene.opening,
    );
  }

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async {
    if (_postActivity) {
      onLog('후속 활동으로 이동');
      return const PlaySessionSnapshot(
        phase: PlayPhase.postActivity,
        currentScene: null,
      );
    }
    return _snapshot();
  }

  /// 서버 story-complete. 다음 장면으로 옮기고 그 장면을 돌려준다.
  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) async {
    if (_index < _script.length - 1) _index++;
    _turn = 0;
    _accumulated.clear();
    return _snapshot();
  }

  /// 두 턴이면 요소를 다 채우고 장면을 닫는다. 서버의 최소 2턴 게이트와 같은 모양이다.
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
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _turn++;
    final List<String> elements = _scene.elements;
    // 1턴에 절반, 2턴에 나머지를 채운다.
    _accumulated.addAll(
      _turn == 1 ? elements.take((elements.length / 2).ceil()) : elements,
    );
    final bool closing = _turn >= 2;
    onLog(
      '  턴 $_turn · 누적 ${_accumulated.join(",")}${closing ? " · 장면 종료" : ""}',
    );

    if (!closing) {
      return PlayTurnResult(
        characterText: '그렇구나. 조금 더 말해 줄래?',
        characterAudioUrl: null,
        mission: null,
        sceneTransition: null,
        analysis: PlayAnalysis(
          detectedElements: _accumulated.toList(),
          utteranceValidity: 'VALID',
        ),
        progress: PlayProgress(
          mode: PlayResponseMode.normal,
          accumulatedElements: _accumulated.toList(),
          turnCount: _turn,
          maxTurns: 4,
        ),
      );
    }

    final bool isLast = _index >= _script.length - 1;
    final String? resultImage = _scene.resultImage;
    if (!isLast) _index++;
    final PlayTurnResult result = PlayTurnResult(
      characterText: '고맙다. 잘 알겠구나.',
      characterAudioUrl: null,
      mission: null,
      sceneTransition: PlaySceneTransition(
        next: isLast
            ? PlayTransitionTarget.postActivity
            : PlayTransitionTarget.scene,
        nextSceneId: isLast ? null : _sceneId(_script[_index].order),
        nextSceneOrder: isLast ? null : _script[_index].order,
        nextSceneType: isLast ? null : _script[_index].type,
        closingReason: 'GOAL_MET',
        resultImageUrl: resultImage,
      ),
      analysis: PlayAnalysis(
        detectedElements: _accumulated.toList(),
        utteranceValidity: 'VALID',
      ),
      progress: PlayProgress(
        mode: PlayResponseMode.closing,
        accumulatedElements: _accumulated.toList(),
        turnCount: _turn,
        maxTurns: 4,
      ),
    );
    _turn = 0;
    _accumulated.clear();
    if (isLast) _postActivity = true;
    return result;
  }

  /// 마지막 장면이 닫히면 세션이 후속 활동으로 넘어간다. PlayPage 가 recap 으로 라우팅한다.
  bool _postActivity = false;

  @override
  Future<void> stop(String sessionId) async {}

  @override
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) async => const <PlayMessage>[];

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      PlayOpeningMessage(
        text: _scene.opening ?? '',
        audioUrl: null,
        alreadyOpened: true,
      );

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async =>
      const PlayTranscription(
        text: '이렇게 해 보면 좋겠어요',
        confidence: .9,
        lowConfidence: false,
      );

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async => throw UnimplementedError('프리뷰는 음성을 쓰지 않는다');
}

class _SilentRecorder implements MissionVoiceRecorder {
  @override
  Future<bool> start() async => true;
  @override
  Future<Uint8List?> stop() async => Uint8List.fromList(<int>[0, 0]);
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async {}
}

class _SilentPlayer implements StoryAudioPlayer {
  @override
  Stream<Duration> get onPosition => const Stream<Duration>.empty();
  @override
  Future<void> playUrl(String url) async {}
  @override
  bool get canResume => false;
  @override
  Future<void> setMuted(bool muted) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class FlowPreviewApp extends StatefulWidget {
  const FlowPreviewApp({super.key});

  @override
  State<FlowPreviewApp> createState() => _FlowPreviewAppState();
}

class _FlowPreviewAppState extends State<FlowPreviewApp> {
  final List<String> _log = <String>[];
  late final _FlowRepository _repo = _FlowRepository(_append);
  late final GoRouter _router = GoRouter(
    initialLocation: AppRoutes.playOf('flow-preview'),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.playPath,
        builder: (_, GoRouterState state) => PlayPage(
          sessionId: state.pathParameters['sessionId'] ?? 'flow-preview',
          repository: _repo,
          voiceRecorder: _SilentRecorder(),
          audioPlayer: _SilentPlayer(),
        ),
      ),
      GoRoute(
        path: AppRoutes.playRecapPath,
        builder: (_, _) => const _EndPage('후속 활동'),
      ),
      GoRoute(path: AppRoutes.home, builder: (_, _) => const _EndPage('홈')),
    ],
  );

  void _append(String line) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _log.add(line));
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Row(
          children: <Widget>[
            Expanded(
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                routerConfig: _router,
              ),
            ),
            Container(
              width: 240,
              color: const Color(0xFF11213A),
              padding: const EdgeInsets.all(12),
              child: ListView(
                children: <Widget>[
                  const Text(
                    '진행 로그',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final String line in _log)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        line,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EndPage extends StatelessWidget {
  const _EndPage(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF183455),
    body: Center(
      child: Text(
        '$label 화면으로 이동했습니다',
        style: const TextStyle(color: Colors.white, fontSize: 28),
      ),
    ),
  );
}
