import '../../../../core/presentation/base_view_model.dart';
import '../../domain/entities/completed_stories.dart';
import '../../domain/entities/story_catalog.dart';
import '../../domain/entities/story_summary.dart';
import '../../domain/entities/story_topic.dart';

import '../../domain/usecases/get_completed_stories_use_case.dart';
import '../../domain/usecases/get_story_catalog_use_case.dart';

/// 이야기 목록의 상태. 데이터 하나 + 선택된 주제 하나가 전부입니다.
///
/// 필터는 **서버가 아니라 여기서** 겁니다. 칩을 누를 때마다 요청을 보내면
/// 스켈레톤이 번쩍이고, MVP 콘텐츠 수로는 얻는 게 없습니다.
class StoryListViewModel extends BaseViewModel {
  StoryListViewModel(this._getCatalog, {this.completedStories});

  final GetStoryCatalogUseCase _getCatalog;

  /// 완주 표시를 채우는 쪽. `null` 이면 표시를 아예 찾지 않습니다
  /// (미리보기·위젯 테스트).
  ///
  /// 이름에 밑줄이 없는 건 `this.completedStories` 로 받기 위해서일 뿐입니다
  /// (Dart 는 밑줄로 시작하는 이름 있는 매개변수를 금지합니다).
  /// **화면에서 직접 부르지 마세요** — 판정은 [isCompleted] 하나로 합니다.
  final GetCompletedStoriesUseCase? completedStories;

  StoryCatalog? _catalog;
  String _selectedTopicId = StoryTopic.allId;
  CompletedStories _completed = CompletedStories.none;

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

  /// 이 이야기를 이미 끝까지 들었는지. → [GetCompletedStoriesUseCase]
  bool isCompleted(StorySummary story) => _completed.contains(story);

  Future<void> load() async {
    await guard(() async {
      _catalog = await _getCatalog();
    });
    // 목록이 그려진 **뒤에** 이어서 채웁니다. 위의 guard 가 이미 success 로
    // 알렸기 때문에, 여기서 기다려도 카드가 늦게 뜨지는 않습니다 — 완주
    // 도장만 한 박자 뒤에 찍힙니다.
    await _loadCompleted();
  }

  /// **실패는 use case 안에서 삼킵니다.** 완주 도장은 있으면 좋은 정보고,
  /// 못 불렀다고 이야기 목록을 에러로 만들 이유가 없습니다.
  Future<void> _loadCompleted() async {
    final GetCompletedStoriesUseCase? use = completedStories;
    if (use == null || _catalog == null) return;
    _completed = await use();
    safeNotify();
  }

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
