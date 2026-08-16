import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/play/domain/entities/play_session.dart';
import 'features/play/domain/repositories/play_repository.dart';
import 'features/play/presentation/views/play_view.dart';
import 'features/play/presentation/voice/mission_voice_recorder.dart';
import 'features/play/presentation/voice/story_audio_player.dart';

/// 백엔드·로그인 없이 범용 음성 대화 화면을 확인하는 개발용 진입점입니다.
///
/// 실행:
/// flutter run -d chrome -t lib/main_play_preview.dart --web-port 7359
void main() => runApp(const _PlayPreviewApp());

class _PlayPreviewApp extends StatelessWidget {
  const _PlayPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GoodQuestion 대화 화면 미리보기',
      theme: AppTheme.light,
      home: const PlayPage(
        sessionId: 'dialogue-ui-preview',
        repository: _DialoguePreviewRepository(),
        voiceRecorder: _PreviewVoiceRecorder(),
        audioPlayer: _PreviewAudioPlayer(),
      ),
    );
  }
}

class _DialoguePreviewRepository implements PlayRepository {
  const _DialoguePreviewRepository();

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      const PlaySessionSnapshot(
        phase: PlayPhase.dialogue,
        currentScene: PlayScene(
          sceneId: 'dialogue-preview',
          sceneOrder: 3,
          sceneType: PlaySceneType.dialogue,
          narrationSentences: <String>[],
          imageUrl: 'assets/images/dialogue/banggui_dialogue_1.png',
          characterName: '방귀쟁이 며느리',
          maxTurns: 4,
        ),
        openingText: '내 방귀 때문에 모두가 놀랐어. 나는 어떻게 하면 좋을까?',
        messages: <PlayMessage>[
          PlayMessage(
            messageId: 'preview-child-1',
            speaker: PlaySpeaker.child,
            turnOrder: 1,
            text: '방귀는 나쁜 점만 있는 게 아니라고 생각해요.',
          ),
        ],
      );

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
        text: '방귀는 나쁜 점만 있는 게 아니라고 생각해요.',
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
  }) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    return const PlayTurnResult(
      characterText: '그렇게 생각해 줘서 고마워. 왜 나쁜 점만 있는 게 아니라고 생각했니?',
      characterAudioUrl: null,
      mission: null,
      sceneTransition: null,
    );
  }

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

class _PreviewAudioPlayer implements StoryAudioPlayer {
  @override
  Stream<Duration> get onPosition => const Stream<Duration>.empty();

  const _PreviewAudioPlayer();

  @override
  Future<void> dispose() async {}

  @override
  Future<void> playUrl(String url) =>
      Future<void>.delayed(const Duration(milliseconds: 1700));

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
