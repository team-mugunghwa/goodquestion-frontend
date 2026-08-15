import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/play/domain/entities/play_session.dart';
import 'features/play/domain/repositories/play_repository.dart';
import 'features/play/presentation/views/play_view.dart';
import 'features/play/presentation/voice/story_audio_player.dart';

/// 백엔드와 로그인 없이 미션 등장 → 완료 → 이야기 재개 흐름을 확인하는 프리뷰입니다.
///
/// 실행:
/// flutter run -d chrome -t lib/main_mission_preview.dart --web-port 7358
void main() {
  runApp(const _MissionPreviewApp());
}

class _MissionPreviewApp extends StatelessWidget {
  const _MissionPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GoodQuestion 미션 화면 미리보기',
      theme: AppTheme.light,
      home: PlayPage(
        sessionId: 'mission-ui-preview',
        repository: _MissionPreviewRepository(
          showSecondMission: Uri.base.queryParameters['mission'] == '2',
          directShowMission: Uri.base.queryParameters['direct'] == 'true',
        ),
        audioPlayer: const _PreviewAudioPlayer(),
      ),
    );
  }
}

class _MissionPreviewRepository implements PlayRepository {
  _MissionPreviewRepository({
    required this.showSecondMission,
    required this.directShowMission,
  });

  final bool showSecondMission;
  final bool directShowMission;
  int _resumeCount = 0;
  int _transcriptionCount = 0;

  static const PlayMission _mission1 = PlayMission(
    missionId: 'mission_1',
    missionType: PlayMissionType.problemSolving,
    title: '배를 안전하게 받아라!',
    description: '배가 떨어져도 다치지 않도록 네 가지 생각을 모아 보세요.',
    questions: <PlayMissionQuestion>[
      PlayMissionQuestion(key: 'tool', label: '어떤 도구를 사용하면 좋을까요?'),
      PlayMissionQuestion(key: 'safety', label: '어떻게 해야 안전할까요?'),
      PlayMissionQuestion(key: 'request', label: '누구에게 무엇을 부탁할까요?'),
      PlayMissionQuestion(key: 'expectedResult', label: '그러면 어떤 결과가 생길까요?'),
    ],
    cards: <PlayMissionCard>[],
  );

  static const PlayMission _mission2 = PlayMission(
    missionId: 'mission_2',
    missionType: PlayMissionType.perspectiveShift,
    title: '친구의 숨은 힘을 찾아라!',
    description: '단점처럼 보이는 특징을 멋진 가능성으로 바꾸어 말해 보세요.',
    questions: <PlayMissionQuestion>[],
    cards: <PlayMissionCard>[
      PlayMissionCard(
        key: 'loud_voice',
        label: '목소리가 큰 친구',
        template: '목소리가 큰 친구는 ___ 할 수 있어요.',
      ),
      PlayMissionCard(
        key: 'talkative',
        label: '말이 많은 친구',
        template: '말이 많은 친구는 ___ 할 수 있어요.',
      ),
      PlayMissionCard(
        key: 'fearful',
        label: '겁이 많은 친구',
        template: '겁이 많은 친구는 ___ 할 수 있어요.',
      ),
      PlayMissionCard(
        key: 'playful',
        label: '장난을 많이 치는 친구',
        template: '장난을 많이 치는 친구는 ___ 할 수 있어요.',
      ),
    ],
  );

  PlayMission get _mission => showSecondMission ? _mission2 : _mission1;

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async {
    if (_resumeCount++ == 0) {
      return PlaySessionSnapshot(
        phase: PlayPhase.dialogue,
        currentScene: const PlayScene(
          sceneId: 'preview-dialogue-3',
          sceneOrder: 3,
          sceneType: PlaySceneType.dialogue,
          narrationSentences: <String>[],
          characterName: '방귀쟁이 며느리',
          maxTurns: 5,
        ),
        openingText: showSecondMission
            ? '내 특징을 부끄러워하지 않아도 된다고 했지? 다른 친구의 특징도 새롭게 볼 수 있을까?'
            : '우리가 배를 안전하게 받을 방법을 함께 생각해 볼까?',
        mission: directShowMission ? _mission : null,
      );
    }
    return const PlaySessionSnapshot(
      phase: PlayPhase.story,
      currentScene: PlayScene(
        sceneId: 'preview-story-4',
        sceneOrder: 4,
        sceneType: PlaySceneType.story,
        narrationSentences: <String>[
          '아이가 생각한 방법대로 모두 힘을 합쳤어요.',
          '커다란 보자기를 넓게 펼치자 배가 포근하게 내려앉았어요.',
          '마을 사람들은 멋진 생각이라며 손뼉을 쳤답니다!',
        ],
      ),
    );
  }

  @override
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) async => const <PlayMessage>[];

  @override
  Future<PlayMission?> currentMission(String sessionId) async =>
      directShowMission ? _mission : null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async {
    await Future<void>.delayed(const Duration(milliseconds: 550));
    final List<String> answers = showSecondMission
        ? <String>[
            '멀리 있는 친구를 큰 소리로 부를 수 있어요.',
            '재미있는 이야기를 많이 들려줄 수 있어요.',
            '위험한 일을 먼저 알아차릴 수 있어요.',
            '친구들을 웃게 하고 즐겁게 해 줄 수 있어요.',
          ]
        : <String>[
            '커다란 보자기를 사용할래요.',
            '보자기를 넓게 펴면 배가 다치지 않아요.',
            '며느리에게 나무 쪽으로 방귀를 뀌어 달라고 부탁해요.',
            '배가 보자기 위로 안전하게 떨어져요.',
          ];
    return PlayTranscription(
      text: answers[_transcriptionCount++ % answers.length],
      confidence: .96,
      lowConfidence: false,
    );
  }

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      PlayOpeningMessage(
        text: showSecondMission
            ? '다른 친구의 특징도 새롭게 볼 수 있을까?'
            : '배를 안전하게 받을 방법을 함께 생각해 볼까?',
        audioUrl: null,
        alreadyOpened: true,
      );

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async => const PlaySpeechAudio(audioUrl: 'preview://speech');

  @override
  Future<void> stop(String sessionId) async {}

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
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (missionId == null) {
      return PlayTurnResult(
        characterText: showSecondMission
            ? '좋은 생각이야. 이제 다른 친구들의 숨은 힘도 찾아보자!'
            : '방향이 보이기 시작했구나. 이제 안전한 방법을 구체적으로 만들어 보자!',
        characterAudioUrl: null,
        mission: _mission,
        sceneTransition: null,
      );
    }
    return const PlayTurnResult(
      characterText: '정말 멋진 생각이야! 네 생각으로 다음 이야기를 이어 가 보자.',
      characterAudioUrl: null,
      mission: null,
      sceneTransition: PlaySceneTransition(
        next: PlayTransitionTarget.scene,
        nextSceneType: PlaySceneType.story,
      ),
    );
  }

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) async {
    return const PlaySessionSnapshot(
      phase: PlayPhase.dialogue,
      currentScene: PlayScene(
        sceneId: 'preview-dialogue-next',
        sceneOrder: 5,
        sceneType: PlaySceneType.dialogue,
        narrationSentences: <String>[],
        characterName: '마을 이장',
      ),
      openingText: '덕분에 배를 안전하게 받았구나! 어떤 점이 가장 좋았니?',
    );
  }
}

class _PreviewAudioPlayer implements StoryAudioPlayer {
  @override
  Stream<Duration> get onPosition => const Stream<Duration>.empty();

  const _PreviewAudioPlayer();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playUrl(String url) =>
      Future<void>.delayed(const Duration(milliseconds: 1100));

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
}
