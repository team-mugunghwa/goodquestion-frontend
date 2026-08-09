import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/state/view_state.dart';
import 'package:goodquestion/features/story/domain/entities/story_catalog.dart';
import 'package:goodquestion/features/story/domain/entities/story_detail.dart';
import 'package:goodquestion/features/story/domain/entities/story_summary.dart';
import 'package:goodquestion/features/story/domain/entities/story_topic.dart';
import 'package:goodquestion/features/story/domain/repositories/story_repository.dart';
import 'package:goodquestion/features/story/domain/usecases/get_story_catalog_use_case.dart';
import 'package:goodquestion/features/story/domain/usecases/get_story_detail_use_case.dart';
import 'package:goodquestion/features/story/domain/usecases/start_story_session_use_case.dart';
import 'package:goodquestion/features/story/presentation/viewmodels/story_detail_view_model.dart';
import 'package:goodquestion/features/story/presentation/viewmodels/story_list_view_model.dart';

class _StubRepository implements StoryRepository {
  _StubRepository({this.catalog, this.detail, this.error});

  final StoryCatalog? catalog;
  final StoryDetail? detail;
  final Object? error;

  @override
  Future<StoryCatalog> getCatalog() async {
    if (error != null) throw error!;
    return catalog!;
  }

  @override
  Future<StoryDetail?> getStoryDetail(int storyId) async {
    if (error != null) throw error!;
    return detail;
  }

  @override
  Future<int> startSession(int storyId) async => 9000 + storyId;
}

const StoryCatalog _catalog = StoryCatalog(
  topics: <StoryTopic>[
    StoryTopic(id: 'all', label: '전체', icon: TopicIcon.all),
    StoryTopic(id: 'folk', label: '옛이야기', icon: TopicIcon.folk),
    StoryTopic(id: 'adventure', label: '모험', icon: TopicIcon.adventure),
  ],
  stories: <StorySummary>[
    StorySummary(
      storyId: 11,
      title: '방귀 뀌는 며느리',
      estimatedMinutes: 20,
      topicIds: <String>['folk'],
    ),
    StorySummary(
      storyId: 21,
      title: '해와 달이 된 오누이',
      estimatedMinutes: 15,
      topicIds: <String>['folk'],
    ),
  ],
);

const StoryDetail _detail = StoryDetail(
  storyId: 11,
  title: '방귀 뀌는 며느리',
  estimatedMinutes: 20,
  difficulty: '쉬움',
  topics: <String>['가족'],
  introText: '옛날 어느 마을에…',
  situationText: '오늘은 말해 줄 참이에요.',
  role: StoryRole(name: '며느리의 친구', description: '고민을 들어주게 될 거야.'),
);

void main() {
  group('StoryListViewModel', () {
    test('load 하면 loading 을 거쳐 success 가 된다', () async {
      final vm = StoryListViewModel(
        GetStoryCatalogUseCase(_StubRepository(catalog: _catalog)),
      );
      final states = <ViewState>[];
      vm.addListener(() => states.add(vm.state));

      await vm.load();

      expect(states.first, ViewState.loading);
      expect(vm.state, ViewState.success);
      expect(vm.visibleStories, hasLength(2));
    });

    test('처음에는 전체가 선택돼 있다', () async {
      final vm = StoryListViewModel(
        GetStoryCatalogUseCase(_StubRepository(catalog: _catalog)),
      );
      await vm.load();

      expect(vm.selectedTopicId, StoryTopic.allId);
      expect(vm.isEmptyByFilter, isFalse);
    });

    test('주제를 고르면 목록이 좁혀진다', () async {
      final vm = StoryListViewModel(
        GetStoryCatalogUseCase(_StubRepository(catalog: _catalog)),
      );
      await vm.load();

      vm.selectTopic('folk');
      expect(vm.visibleStories, hasLength(2));

      vm.selectTopic('adventure');
      // 이야기가 없는 주제 — 에러가 아니라 빈 상태입니다.
      expect(vm.visibleStories, isEmpty);
      expect(vm.isEmptyByFilter, isTrue);
      expect(vm.state, ViewState.success);
    });

    test('전체 보기로 되돌아온다', () async {
      final vm = StoryListViewModel(
        GetStoryCatalogUseCase(_StubRepository(catalog: _catalog)),
      );
      await vm.load();
      vm.selectTopic('adventure');

      vm.resetTopic();

      expect(vm.selectedTopicId, StoryTopic.allId);
      expect(vm.isEmptyByFilter, isFalse);
    });

    test('실패하면 error 와 메시지가 남는다', () async {
      final vm = StoryListViewModel(
        GetStoryCatalogUseCase(
          _StubRepository(error: const NetworkFailure('연결이 끊겼습니다.')),
        ),
      );

      await vm.load();

      expect(vm.state, ViewState.error);
      expect(vm.errorMessage, '연결이 끊겼습니다.');
    });
  });

  group('StoryDetailViewModel', () {
    StoryDetailViewModel viewModelOf(StoryRepository repository, int id) =>
        StoryDetailViewModel(
          GetStoryDetailUseCase(repository),
          StartStorySessionUseCase(repository),
          storyId: id,
        );

    test('있는 이야기는 success 이고 notFound 가 아니다', () async {
      final vm = viewModelOf(_StubRepository(detail: _detail), 11);

      await vm.load();

      expect(vm.state, ViewState.success);
      expect(vm.isNotFound, isFalse);
      expect(vm.story?.role.name, '며느리의 친구');
    });

    test('없는 이야기는 error 가 아니라 notFound 다', () async {
      final vm = viewModelOf(_StubRepository(), 999);

      await vm.load();

      // 여기서 error 로 떨어지면 화면이 "다시 불러오기"를 권하게 되는데,
      // 눌러도 영원히 안 나옵니다.
      expect(vm.state, ViewState.success);
      expect(vm.isNotFound, isTrue);
    });

    test('시작하기는 sessionId 를 돌려주고 화면을 옮기지 않는다', () async {
      final vm = viewModelOf(_StubRepository(detail: _detail), 11);
      await vm.load();

      final int? sessionId = await vm.start();

      expect(sessionId, 9011);
      expect(vm.isStarting, isFalse);
    });

    test('로드 전에는 시작할 수 없다', () async {
      final vm = viewModelOf(_StubRepository(detail: _detail), 11);

      expect(await vm.start(), isNull);
    });
  });
}
