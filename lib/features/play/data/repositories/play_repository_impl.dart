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
