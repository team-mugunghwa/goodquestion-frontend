import '../entities/story_catalog.dart';
import '../repositories/story_repository.dart';

/// 이야기 목록 진입·재시도에서 부릅니다.
class GetStoryCatalogUseCase {
  const GetStoryCatalogUseCase(this._repository);

  final StoryRepository _repository;

  Future<StoryCatalog> call() => _repository.getCatalog();
}
