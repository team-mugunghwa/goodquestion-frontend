import '../../../../core/presentation/base_view_model.dart';
import '../../domain/entities/story_catalog.dart';
import '../../domain/entities/story_summary.dart';
import '../../domain/entities/story_topic.dart';
import '../../domain/usecases/get_story_catalog_use_case.dart';

/// 이야기 목록의 상태. 데이터 하나 + 선택된 주제 하나가 전부입니다.
///
/// 필터는 **서버가 아니라 여기서** 겁니다. 칩을 누를 때마다 요청을 보내면
/// 스켈레톤이 번쩍이고, MVP 콘텐츠 수로는 얻는 게 없습니다.
class StoryListViewModel extends BaseViewModel {
  StoryListViewModel(this._getCatalog);

  final GetStoryCatalogUseCase _getCatalog;

  StoryCatalog? _catalog;
  String _selectedTopicId = StoryTopic.allId;

  StoryCatalog? get catalog => _catalog;

  /// 현재 선택된 주제. 상세에 갔다 돌아와도 유지됩니다 —
  /// 목록 화면이 `push` 로 스택에 남아 있기 때문입니다.
  String get selectedTopicId => _selectedTopicId;

  List<StoryTopic> get topics => _catalog?.topics ?? const <StoryTopic>[];

  /// 화면에 그릴 카드들. 주제로 이미 걸러져 있습니다.
  List<StorySummary> get visibleStories =>
      _catalog?.filtered(_selectedTopicId) ?? const <StorySummary>[];

  /// 고른 주제에 이야기가 하나도 없는가. (에러가 아니라 빈 상태)
  bool get isEmptyByFilter =>
      state.isSuccess && _catalog != null && visibleStories.isEmpty;

  Future<void> load() => guard(() async {
    _catalog = await _getCatalog();
  });

  /// 칩 선택. 같은 칩을 다시 눌러도 "전체"로 풀리지 않습니다 —
  /// 저학년에게 토글은 예측이 어렵습니다. 되돌리려면 "전체"를 누릅니다.
  void selectTopic(String topicId) {
    if (_selectedTopicId == topicId) return;
    _selectedTopicId = topicId;
    safeNotify();
  }

  /// 빈 상태에서 "전체 보기" 로 빠져나올 때.
  void resetTopic() => selectTopic(StoryTopic.allId);
}
