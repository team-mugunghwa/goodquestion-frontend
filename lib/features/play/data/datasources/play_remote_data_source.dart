import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/play_session.dart';
import '../dtos/play_session_dto.dart';

class PlayRemoteDataSource {
  const PlayRemoteDataSource(this._client);

  final DioClient _client;

  Future<PlaySessionSnapshot> resume(String sessionId) =>
      _client.get<PlaySessionSnapshot>(
        '/sessions/$sessionId/resume',
        parse: (Object? data) {
          if (data is Map<String, dynamic>) {
            return PlaySessionDto.fromResumeJson(data);
          }
          throw const ParseException('이어하기 응답 형식이 올바르지 않습니다.');
        },
      );

  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) =>
      _client.post<PlaySessionSnapshot>(
        '/sessions/$sessionId/scenes/current/story-complete',
        parse: (Object? data) {
          if (data is Map<String, dynamic>) {
            return PlaySessionDto.fromAdvanceJson(data);
          }
          throw const ParseException('장면 전환 응답 형식이 올바르지 않습니다.');
        },
      );
}
