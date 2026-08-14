import '../entities/play_session.dart';

abstract interface class PlayRepository {
  Future<PlaySessionSnapshot> resume(String sessionId);

  Future<PlaySessionSnapshot> completeStoryScene(String sessionId);
}
