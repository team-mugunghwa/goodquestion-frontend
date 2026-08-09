import '../repositories/story_repository.dart';

/// 이야기를 시작해 세션을 만듭니다.
///
/// **서비스 전체에서 세션이 생성되는 유일한 지점**이라 UseCase 로 따로
/// 세워 뒀습니다. 나중에 "진행 중 세션이 이미 있으면?" 같은 규칙이 붙는다면
/// 그 자리가 여기입니다. 화면에 흩뿌리면 반드시 한 군데를 빠뜨립니다.
class StartStorySessionUseCase {
  const StartStorySessionUseCase(this._repository);

  final StoryRepository _repository;

  Future<int> call(int storyId) => _repository.startSession(storyId);
}
