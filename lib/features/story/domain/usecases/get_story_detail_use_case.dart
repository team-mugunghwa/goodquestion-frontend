import '../entities/story_detail.dart';
import '../repositories/story_repository.dart';

/// 이야기 상세 진입·재시도에서 부릅니다.
///
/// 없는 이야기면 `null` 입니다 — 화면은 이걸 "찾을 수 없어요"로 그립니다.
class GetStoryDetailUseCase {
  const GetStoryDetailUseCase(this._repository);

  final StoryRepository _repository;

  Future<StoryDetail?> call(int storyId) => _repository.getStoryDetail(storyId);
}
