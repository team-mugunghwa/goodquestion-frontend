// 대화 장면 캐릭터 표정·모션 육안 확인용 프리뷰. 제품 코드가 아니다.
//
//   flutter run -d chrome -t tool/preview/dialogue_character_preview.dart
//
// 실제 PlayPage 를 스텁 리포지토리로 띄운다. 백엔드도 마이크도 없이 턴 응답만 주입해서
// 표정 전환을 눈으로 확인하려는 목적이다 - 위젯 트리는 제품과 같은 것을 쓴다.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:goodquestion/features/play/domain/entities/play_session.dart';
import 'package:goodquestion/features/play/domain/repositories/play_repository.dart';
import 'package:goodquestion/features/play/presentation/views/play_view.dart';
import 'package:goodquestion/features/play/presentation/voice/mission_voice_recorder.dart';
import 'package:goodquestion/features/play/presentation/voice/story_audio_player.dart';

void main() => runApp(const PreviewApp());

/// 마이크를 잡지 않는다. 프리뷰는 표정만 보는 자리고, 실제 장치 권한을 물으면 헤드리스에서
/// 곧바로 오류 화면으로 떨어진다.
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

/// 프리뷰에서 고를 수 있는 장면. 시드 UUID 를 그대로 쓴다.
class _SceneSpec {
  const _SceneSpec(
    this.label,
    this.sceneId,
    this.order,
    this.character,
    this.opening,
    this.elements,
    this.maxTurns,
  );

  final String label;
  final String sceneId;
  final int order;
  final String character;
  final String opening;
  final List<String> elements;
  final int maxTurns;
}

const List<_SceneSpec> _scenes = <_SceneSpec>[
  _SceneSpec(
    '대화1',
    '33333333-3333-3333-3333-000000000003',
    3,
    '방귀쟁이 며느리',
    'ㅇㅇ아, 내 방귀가 너무 크다는 걸 알면 가족들이 나를 이상하게 생각하지 않을까?',
    <String>['EMOTION', 'PERSPECTIVE', 'SOLUTION'],
    4,
  ),
  _SceneSpec(
    '대화2',
    '33333333-3333-3333-3333-000000000005',
    5,
    '시아버지',
    '아이고, 이게 무슨 일이냐! 이렇게 창피한 며느리와 함께 못 살겠다! 그렇지 않니?',
    <String>['PERSPECTIVE', 'EMPATHY', 'REASON', 'REQUEST'],
    5,
  ),
  _SceneSpec(
    '대화3',
    '33333333-3333-3333-3333-000000000007',
    7,
    '마을 이장',
    '이 배나무는 너무 높아서 아무도 딸 수가 없었단다. 무슨 뾰족한 방법이 없겠는가?',
    <String>['SOLUTION', 'REASON', 'REQUEST', 'RESULT'],
    5,
  ),
  _SceneSpec(
    '대화4',
    '33333333-3333-3333-3333-000000000009',
    9,
    '방귀쟁이 며느리',
    '내 방귀가 누군가에게 도움이 될 수 있다는 걸 처음 알았어. 부끄러워하지 않아도 될까?',
    <String>['EMOTION', 'PERSPECTIVE', 'RESULT', 'SOLUTION'],
    4,
  ),
];

/// 다음 발화가 어떤 응답으로 돌아올지. 프리뷰가 버튼으로 정한다.
class _NextTurn {
  _NextTurn(this.spec);

  final _SceneSpec spec;
  final Set<String> accumulated = <String>{};
  String validity = 'VALID';
  bool closing = false;

  PlayTurnResult build() {
    final bool isClosing =
        closing || accumulated.length >= spec.elements.length;
    return PlayTurnResult(
      characterText: isClosing ? '그래, 잘 알겠구나. 고맙다.' : '음, 그렇구나. 조금 더 말해 볼래?',
      characterAudioUrl: null,
      mission: null,
      sceneTransition: null,
      analysis: PlayAnalysis(
        detectedElements: accumulated.toList(),
        utteranceValidity: validity,
      ),
      progress: PlayProgress(
        mode: isClosing ? PlayResponseMode.closing : PlayResponseMode.normal,
        accumulatedElements: accumulated.toList(),
        turnCount: 2,
        maxTurns: spec.maxTurns,
      ),
    );
  }
}

class _StubRepository implements PlayRepository {
  _StubRepository(this.next);

  final _NextTurn next;

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      PlaySessionSnapshot(
        phase: PlayPhase.dialogue,
        currentScene: PlayScene(
          sceneId: next.spec.sceneId,
          sceneOrder: next.spec.order,
          sceneType: PlaySceneType.dialogue,
          narrationSentences: const <String>[],
          characterName: next.spec.character,
          maxTurns: next.spec.maxTurns,
        ),
        openingText: next.spec.opening,
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
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return next.build();
  }

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
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) =>
      resume(sessionId);

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      PlayOpeningMessage(
        text: next.spec.opening,
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
  }) async => throw UnimplementedError('프리뷰에서는 음성을 쓰지 않는다');
}

class PreviewApp extends StatefulWidget {
  const PreviewApp({super.key});

  @override
  State<PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<PreviewApp> {
  int _sceneIndex = 0;
  int _rebuild = 0;
  late _NextTurn _next = _NextTurn(_scenes[0]);

  _SceneSpec get _spec => _scenes[_sceneIndex];

  void _reload() => setState(() {
    _next = _NextTurn(_spec);
    _rebuild++;
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Column(
          children: <Widget>[
            Material(
              color: const Color(0xFF11213A),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    for (int i = 0; i < _scenes.length; i++)
                      ChoiceChip(
                        label: Text(_scenes[i].label),
                        selected: i == _sceneIndex,
                        onSelected: (_) {
                          _sceneIndex = i;
                          _reload();
                        },
                      ),
                    const SizedBox(width: 16),
                    const Text(
                      '요소 충족 →',
                      style: TextStyle(color: Colors.white70),
                    ),
                    for (final String element in _spec.elements)
                      FilterChip(
                        label: Text(element),
                        selected: _next.accumulated.contains(element),
                        onSelected: (bool on) => setState(() {
                          on
                              ? _next.accumulated.add(element)
                              : _next.accumulated.remove(element);
                          _next.validity = 'VALID';
                        }),
                      ),
                    ActionChip(
                      label: const Text('놀림(PLAYFUL)'),
                      onPressed: () =>
                          setState(() => _next.validity = 'PLAYFUL'),
                    ),
                    ActionChip(
                      label: const Text('종료(CLOSING)'),
                      onPressed: () => setState(() => _next.closing = true),
                    ),
                    ActionChip(label: const Text('장면 다시'), onPressed: _reload),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PlayPage(
                key: ValueKey<String>('${_spec.sceneId}-$_rebuild'),
                sessionId: 'preview',
                repository: _StubRepository(_next),
                voiceRecorder: _SilentRecorder(),
                audioPlayer: _SilentPlayer(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
