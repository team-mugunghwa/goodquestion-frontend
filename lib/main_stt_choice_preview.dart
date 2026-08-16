import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'core/error/failure.dart';
import 'core/theme/app_theme.dart';
import 'features/play/domain/entities/play_session.dart';
import 'features/play/domain/repositories/play_repository.dart';
import 'features/play/presentation/views/play_view.dart';
import 'features/play/presentation/voice/mission_voice_recorder.dart';
import 'features/play/presentation/voice/story_audio_player.dart';

/// 백엔드·로그인 없이 **STT 예외처리(재시도 안내 → 3회 실패 선택지)** 만 확인하는
/// 개발용 진입점입니다. 실기기/브라우저에서 진짜 글꼴로 줄바꿈과 터치 크기를
/// 보려고 만들었습니다 - 테스트 골든은 글꼴이 두부로 그려져서 판단할 수 없습니다.
///
/// 실행:
/// ```
/// flutter run -d web-server --web-port=7361 -t lib/main_stt_choice_preview.dart
/// ```
/// 띄운 뒤 브라우저로 `http://localhost:7361` 을 엽니다.
///
/// **보는 법**: 마이크를 누르고(권한 필요 없음 - 녹음기도 가짜입니다) 곧바로
/// 다시 눌러 "말하기 완료"를 하면 한 번 못 알아들은 것으로 칩니다.
/// 1회 → 캐릭터가 다시 물어봄 / 2회 → 조금 크게 / 3회 → 문장 카드.
/// 카드를 하나 고르면 발화가 나가고, **그 다음 턴부터는** 첫 턴 3문장이 아니라
/// `missingElements` 로 고른 요소별 문장이 뜹니다(둘 다 한 번에 확인 가능).
///
/// 안내 음성과 카드의 "듣기"는 **진짜 mp3** 를 재생합니다
/// (`assets/audio/choices/`). 캐릭터 대사만 재생하는 시늉을 합니다.
///
/// 장면을 바꿔 보려면 [_sceneOrder] 만 3·5·7·9 중에서 고쳐 다시 띄웁니다.
/// 3·5·7·9 밖(예: 4)으로 두면 선택지가 뜨지 않고 예전처럼 짧은 글 안내만
/// 남는 것도 확인할 수 있습니다.
const int _sceneOrder = 3;

void main() => runApp(const _SttChoicePreviewApp());

class _SttChoicePreviewApp extends StatelessWidget {
  const _SttChoicePreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GoodQuestion 못 알아들었을 때 미리보기',
      theme: AppTheme.light,
      home: PlayPage(
        sessionId: 'stt-choice-preview',
        repository: _SttChoicePreviewRepository(),
        voiceRecorder: const _PreviewVoiceRecorder(),
        audioPlayer: _PreviewAudioPlayer(),
      ),
    );
  }
}

/// 무엇을 말해도 **항상 못 알아듣는** 서버. 그래야 세 번째에 카드가 내려옵니다.
class _SttChoicePreviewRepository implements PlayRepository {
  _SttChoicePreviewRepository();

  /// 이 장면에서 발화가 몇 번 나갔는지. 첫 턴은 정해진 3문장, 그 뒤로는
  /// `missingElements` 로 고르는 길을 한 번에 보여주려고 셉니다.
  int _turnCount = 0;

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      const PlaySessionSnapshot(
        phase: PlayPhase.dialogue,
        currentScene: PlayScene(
          sceneId: 'stt-choice-preview',
          sceneOrder: _sceneOrder,
          sceneType: PlaySceneType.dialogue,
          narrationSentences: <String>[],
          imageUrl: 'assets/images/dialogue/banggui_dialogue_1.png',
          characterName: '방귀쟁이 며느리',
          maxTurns: 4,
        ),
        openingText: '내 방귀 때문에 모두가 놀랐어. 나는 어떻게 하면 좋을까?',
        messages: <PlayMessage>[],
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

  /// 무음으로 판정된 것처럼 굴어서 재시도 흐름을 탑니다.
  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    throw const ServerFailure(
      message: '음성에서 텍스트를 만들지 못했습니다.',
      code: 'STT_EMPTY_TEXT',
    );
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
  }) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    _turnCount++;
    debugPrint(
      '[preview] 발화 나감 - text="$text" '
      'sttRetryCount=$sttRetryCount '
      'sttRawText=$sttRawText sttConfidence=$sttConfidence',
    );
    return PlayTurnResult(
      characterText: '그렇게 말해 줘서 고마워. 왜 그렇게 생각했는지도 알려 줄래?',
      characterAudioUrl: null,
      mission: null,
      sceneTransition: null,
      // 다음 턴의 카드는 여기서 정해집니다. 아직 못 채운 요소만 남겨 두면
      // 화면이 그 요소의 문장만 골라 최대 3장을 내려놓습니다.
      progress: PlayProgress(
        mode: PlayResponseMode.normal,
        accumulatedElements: const <String>['EMOTION'],
        missingElements: const <String>['REASON', 'SOLUTION', 'PERSPECTIVE'],
        turnCount: _turnCount,
        maxTurns: 4,
      ),
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

  /// 마이크 권한을 묻지 않습니다 - 어차피 서버가 항상 못 알아듣습니다.
  @override
  Future<bool> start() async => true;

  @override
  Future<Uint8List?> stop() async => Uint8List.fromList(<int>[1, 2, 3]);
}

/// 에셋(`assets/...`)은 **진짜로** 재생하고, 캐릭터 대사(`preview://`)만
/// 재생하는 시늉을 하는 재생기. 안내 음성과 카드 "듣기"가 실제로 들려야
/// 마이크 잠김 시간이 몸에 맞는지 판단할 수 있습니다.
class _PreviewAudioPlayer implements StoryAudioPlayer {
  _PreviewAudioPlayer();

  final DeviceStoryAudioPlayer _device = DeviceStoryAudioPlayer();

  bool _isAsset(String url) => url.startsWith('assets/');

  @override
  Future<void> playUrl(String url) {
    if (_isAsset(url)) return _device.playUrl(url);
    return Future<void>.delayed(const Duration(milliseconds: 1700));
  }

  @override
  Stream<Duration> get onPosition => _device.onPosition;

  @override
  bool get canResume => _device.canResume;

  @override
  Future<void> setMuted(bool muted) => _device.setMuted(muted);

  @override
  Future<void> pause() => _device.pause();

  @override
  Future<void> resume() => _device.resume();

  @override
  Future<void> stop() => _device.stop();

  @override
  Future<void> dispose() => _device.dispose();
}
