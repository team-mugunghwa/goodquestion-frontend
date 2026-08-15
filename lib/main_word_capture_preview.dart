import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'features/play/data/dialogue_word_capture.dart';
import 'features/play/domain/entities/play_session.dart';
import 'features/play/domain/repositories/play_repository.dart';
import 'features/play/presentation/views/play_view.dart';
import 'features/play/presentation/voice/mission_voice_recorder.dart';
import 'features/play/presentation/voice/story_audio_player.dart';

/// 백엔드/로그인 없이 **고정 대사 단어 담기**만 확인하는 개발용 진입점입니다.
///
/// 실행:
/// ```
/// flutter run -d web-server --web-port=7362 -t lib/main_word_capture_preview.dart
/// ```
///
/// **보는 법**:
/// 1) 첫 대사(고정)가 단어 단위로 떠 있다 - 아무 단어나 누르면 "담을까요?"
/// 2) 담기를 누르면 "담았어요", 같은 단어를 또 담으면 "이미 담아 둔 단어예요"
/// 3) 마이크(말하기 완료)를 누르면 동적 답변으로 바뀌고, 단어가 눌리지 않는다
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      title: 'GoodQuestion 단어 담기 미리보기',
      debugShowCheckedModeBanner: false,
      home: PlayPage(
        sessionId: 'preview-session',
        characterName: '방귀쟁이 며느리',
        repository: _PreviewRepository(),
        voiceRecorder: const _PreviewRecorder(),
        audioPlayer: _PreviewAudioPlayer(),
        wordCapture: _PreviewWordCapture(),
      ),
    ),
  );
}

/// 담긴 단어를 메모리에 들고 중복을 흉내 낸다.
class _PreviewWordCapture implements DialogueWordCapture {
  final Set<String> _saved = <String>{};

  @override
  Future<WordCaptureResult> save({
    required String word,
    String? sourceSceneId,
    String? exampleSentence,
  }) async {
    // 실서버 왕복 체감을 위한 지연.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    debugPrint('담기: $word / 장면 $sourceSceneId / 예문 "$exampleSentence"');
    if (!_saved.add(word)) return WordCaptureResult.duplicate;
    return WordCaptureResult.saved;
  }
}

class _PreviewRepository implements PlayRepository {
  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      const PlaySessionSnapshot(
        phase: PlayPhase.dialogue,
        currentScene: PlayScene(
          sceneId: 'preview-scene-9',
          sceneOrder: 9,
          sceneType: PlaySceneType.dialogue,
          narrationSentences: <String>[],
          characterName: '방귀쟁이 며느리',
          maxTurns: 4,
        ),
        openingText: '내 방귀에 기왓장이 들썩이고 장대가 부러졌는데 어떻게 하면 좋을까?',
      );

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) =>
      resume(sessionId);

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(
        text: '내 방귀에 기왓장이 들썩이고 장대가 부러졌는데 어떻게 하면 좋을까?',
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
      const PlayTranscription(
        text: '참지 말고 시원하게 뀌어요',
        confidence: .9,
        lowConfidence: false,
      );

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async => const PlaySpeechAudio(audioUrl: 'stub://preview');

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
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return const PlayTurnResult(
      characterText: '고마워! 참지 않고 말하니까 마음이 후련하다.',
      characterAudioUrl: null,
      mission: null,
      sceneTransition: null,
    );
  }

  @override
  Future<void> stop(String sessionId) async {}
}

class _PreviewRecorder implements MissionVoiceRecorder {
  const _PreviewRecorder();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> start() async => true;

  @override
  Future<Uint8List?> stop() async => Uint8List.fromList(<int>[1, 2, 3]);
}

/// 재생하는 시늉만 한다 - 문장당 1.2초쯤 흘려보내 자막 넘어가는 속도를 흉내.
class _PreviewAudioPlayer implements StoryAudioPlayer {
  @override
  Future<void> playUrl(String url) =>
      Future<void>.delayed(const Duration(milliseconds: 1200));

  @override
  Stream<Duration> get onPosition => const Stream<Duration>.empty();

  @override
  bool get canResume => false;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
