import 'dart:typed_data';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/play_session.dart';
import '../../domain/repositories/play_repository.dart';
import '../datasources/play_remote_data_source.dart';

class PlayRepositoryImpl implements PlayRepository {
  const PlayRepositoryImpl(this._remote);

  final PlayRemoteDataSource _remote;

  @override
  Future<PlaySessionSnapshot> resume(String sessionId) =>
      _guard(() => _remote.resume(sessionId));

  @override
  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) =>
      _guard(() => _remote.completeStoryScene(sessionId));

  @override
  Future<PlayOpeningMessage> openCurrentScene(String sessionId) =>
      _guard(() => _remote.openCurrentScene(sessionId));

  @override
  Future<PlayMission?> currentMission(String sessionId) =>
      _guard(() => _remote.currentMission(sessionId));

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) =>
      _guard(() => _remote.transcribeAudio(wavBytes));

  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) => _guard(
    () => _remote.synthesizeSpeech(text: text, characterName: characterName),
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
  }) => _guard(
    () => _remote.submitUtterance(
      sessionId,
      text: text,
      missionId: missionId,
      sttRawText: sttRawText,
      sttConfidence: sttConfidence,
      sttRetryCount: sttRetryCount,
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<void> stop(String sessionId) => _guard(() => _remote.stop(sessionId));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } on AppException catch (error) {
      throw Failure.fromException(error);
    } on Object catch (error) {
      throw Failure.fromException(ParseException('$error'));
    }
  }
}
