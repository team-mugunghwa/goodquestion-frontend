import '../entities/story_catalog.dart';
import '../entities/story_detail.dart';

/// 이야기 목록·상세의 출처.
abstract class StoryRepository {
  /// 주제 필터 + 이야기 전부.
  Future<StoryCatalog> getCatalog();

  /// 이야기 하나. **없는 id 면 `null`** 을 돌려줍니다 — 예외가 아닙니다.
  ///
  /// 잘못된 주소로 들어온 것과 서버가 죽은 것은 아이에게 다른 화면을
  /// 보여 줘야 합니다. ("찾을 수 없어" vs "다시 해볼까?")
  Future<StoryDetail?> getStoryDetail(int storyId);

  /// 이야기를 시작해 세션을 만듭니다. 서비스 전체에서 세션이 생기는
  /// **유일한 지점**입니다. 만들어진 sessionId 를 돌려줍니다.
  Future<int> startSession(int storyId);
}
