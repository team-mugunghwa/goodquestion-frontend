import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/story_catalog.dart';
import '../../domain/entities/story_detail.dart';
import '../../domain/repositories/story_repository.dart';
import '../datasources/story_local_data_source.dart';
import '../dtos/story_dto.dart';

/// 서버가 준비되기 전까지 이야기 데이터를 번들 더미에서 읽는 구현.
class StoryRepositoryMock implements StoryRepository {
  const StoryRepositoryMock(
    this._localDataSource, {
    this.latency = const Duration(milliseconds: 500),
  });

  final StoryLocalDataSource _localDataSource;

  /// 스켈레톤이 실제로 보이도록 일부러 지연을 줍니다.
  final Duration latency;

  @override
  Future<StoryCatalog> getCatalog() =>
      _guard(() async => (await _localDataSource.fetchCatalog()).toEntity());

  @override
  Future<StoryDetail?> getStoryDetail(String storyId) => _guard(() async {
    final StoryDetailDto? dto = await _localDataSource.fetchStoryDetail(
      storyId,
    );
    return dto?.toEntity();
  });

  /// 목업이라 세션을 만들지 않고 **이야기 id 에서 유도한 가짜 sessionId** 를
  /// 돌려줍니다. 매번 다른 값을 주면 새로고침마다 세션이 늘어나 보여서,
  /// 재현 가능하게 고정했습니다. 서버가 붙으면 `POST /sessions` 응답으로 바뀝니다.
  @override
  Future<String> startSession(String storyId) async {
    await Future<void>.delayed(latency);
    return 'mock-session-$storyId';
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    await Future<void>.delayed(latency);
    try {
      return await action();
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } on Object catch (e) {
      // 더미 파일 누락(에셋 미등록)·필드 타입 불일치가 여기로 옵니다.
      throw Failure.fromException(ParseException('$e'));
    }
  }
}
