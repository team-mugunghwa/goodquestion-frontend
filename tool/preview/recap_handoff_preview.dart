import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:goodquestion/core/router/app_routes.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/features/play/domain/entities/play_session.dart';
import 'package:goodquestion/features/play/domain/repositories/play_repository.dart';
import 'package:goodquestion/features/play/presentation/views/play_view.dart';
import 'package:goodquestion/features/play/presentation/voice/mission_voice_recorder.dart';

/// 말하기 후 활동으로 넘어가는 **전환 한마디만** 눈으로 보는 프리뷰입니다.
///
/// `dialogue_flow_preview.dart` 는 9번 장면까지 진행해야 이 화면이 나옵니다.
/// 여기서는 세션이 이미 끝난 척하는 저장소를 물려서 **뜨자마자** 전환이 뜹니다.
///
/// 전환은 `시작` 을 누르거나 4.5초가 지나면 다음으로 넘어가므로, 넘어간 자리에
/// "다시 보기"를 두어 몇 번이고 되돌려 볼 수 있게 했습니다.
///
/// ```
/// flutter run -d chrome -t tool/preview/recap_handoff_preview.dart
/// ```
void main() => runApp(const _HandoffPreviewApp());

class _HandoffPreviewApp extends StatelessWidget {
  const _HandoffPreviewApp();

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.playOf('handoff-preview'),
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.playPath,
          builder: (_, GoRouterState state) => PlayPage(
            sessionId: state.pathParameters[AppRoutes.sessionIdParam]!,
            repository: _EndedSessionRepository(),
            voiceRecorder: const _SilentRecorder(),
            // 진짜 흐름에서는 마지막 대화 장면의 표정 상태머신이 그대로
            // 전환 화면으로 넘어옵니다. 이 프리뷰는 세션이 이미 끝난 자리에서
            // 시작해 그 상태머신이 없으므로, 같은 장면의 마지막 표정을 한 장으로
            // 물려 줍니다 - 캐릭터 자리가 비면 스케치대로인지 볼 수 없습니다.
            characterAsset:
                'assets/images/dialogue/banggui/scene_09/character_closing.webp',
            characterName: '방귀쟁이 며느리',
          ),
        ),
        // 진짜 후속 활동 화면 대신 되돌아오는 문만 둡니다 - 이 프리뷰가 보려는
        // 것은 전환 그 자체이지 그다음 화면이 아닙니다.
        GoRoute(
          path: AppRoutes.playRecapPath,
          builder: (BuildContext context, __) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () =>
                    context.go(AppRoutes.playOf('handoff-preview')),
                child: const Text('전환 다시 보기'),
              ),
            ),
          ),
        ),
      ],
    );
    return MaterialApp.router(theme: AppTheme.light, routerConfig: router);
  }
}

/// 말하기가 끝난 세션. `resume` 이 곧바로 후속 활동 단계를 돌려줍니다.
class _EndedSessionRepository implements PlayRepository {
  @override
  Future<PlaySessionSnapshot> resume(String sessionId) async =>
      const PlaySessionSnapshot(phase: PlayPhase.postActivity, currentScene: null);

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) async =>
      const PlaySessionSnapshot(phase: PlayPhase.postActivity, currentScene: null);

  @override
  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) async => const <PlayMessage>[];

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) async =>
      const PlayOpeningMessage(text: '', audioUrl: null, alreadyOpened: true);

  @override
  Future<PlayMission?> currentMission(String sessionId) async => null;

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async =>
      const PlayTranscription(text: '', confidence: .9, lowConfidence: false);

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
  }) async => const PlayTurnResult(
    characterText: '',
    characterAudioUrl: null,
    mission: null,
    sceneTransition: PlaySceneTransition(
      next: PlayTransitionTarget.postActivity,
      closingReason: 'GOAL_MET',
    ),
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

class _SilentRecorder implements MissionVoiceRecorder {
  const _SilentRecorder();

  @override
  Future<bool> start() async => false;

  @override
  Future<Uint8List?> stop() async => null;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}
