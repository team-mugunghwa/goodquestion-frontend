import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/state/view_state.dart';
import 'package:goodquestion/features/free_talk/domain/entities/free_talk.dart';
import 'package:goodquestion/features/free_talk/domain/repositories/free_talk_repository.dart';
import 'package:goodquestion/features/home/domain/entities/home_summary.dart';
import 'package:goodquestion/features/home/domain/entities/in_progress_session.dart';
import 'package:goodquestion/features/home/domain/entities/planet_summary.dart';
import 'package:goodquestion/features/home/domain/entities/recommended_story.dart';
import 'package:goodquestion/features/home/domain/repositories/home_repository.dart';
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
  Future<StoryDetail?> getStoryDetail(String storyId) async {
    if (error != null) throw error!;
    return detail;
  }

  /// 새 세션을 몇 번 만들었는지. "이어받아야 할 때 새로 만들지 않는지"를
  /// 보려면 호출 여부 자체를 세야 합니다.
  int startCalls = 0;

  @override
  /// 이 테스트는 완주 도장을 보지 않습니다. → story_views_test.dart
  Future<Set<String>> getCompletedStoryIds() async => const <String>{};

  @override
  Future<String> startSession(String storyId) async {
    startCalls++;
    return '9000-$storyId';
  }
}

/// 홈이 돌려주는 "진행 중 세션" 만 흉내 냅니다.
/// 자유 대화 저장소 스텁 — 상세 화면은 **인물 목록만** 씁니다.
/// 나머지 메서드는 불리면 테스트가 틀린 것이므로 곧장 터뜨립니다.
class _StubFreeTalkRepository implements FreeTalkRepository {
  _StubFreeTalkRepository({
    this.result = const <FreeTalkCharacter>[],
    this.error,
  });

  final List<FreeTalkCharacter> result;
  final Object? error;

  /// 인물 목록을 몇 번 물었는지. "저장소를 안 주면 아예 안 묻는지"를 보려면
  /// 호출 여부 자체를 세야 합니다.
  int characterCalls = 0;

  @override
  Future<List<FreeTalkCharacter>> characters(String storyId) async {
    characterCalls++;
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<FreeTalkSession> start({
    required String storyId,
    required String characterId,
  }) => throw UnimplementedError();

  @override
  Future<FreeTalkTurn> sendMessage(
    String freeTalkId, {
    required String text,
    String? idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<FreeTalkSpeech> end(String freeTalkId) => throw UnimplementedError();
}

class _StubHomeRepository implements HomeRepository {
  _StubHomeRepository({this.inProgressSession, this.error});

  final InProgressSession? inProgressSession;
  final Object? error;

  @override
  Future<HomeSummary> getHomeSummary() async {
    if (error != null) throw error!;
    return HomeSummary(
      inProgressSession: inProgressSession,
      recommendedStories: const <RecommendedStory>[],
      planet: const PlanetSummary(stardustBalance: 0),
    );
  }
}

const StoryCatalog _catalog = StoryCatalog(
  topics: <StoryTopic>[
    StoryTopic(id: 'all', label: '전체', icon: TopicIcon.all),
    StoryTopic(id: 'folk', label: '옛이야기', icon: TopicIcon.folk),
    StoryTopic(id: 'adventure', label: '모험', icon: TopicIcon.adventure),
  ],
  stories: <StorySummary>[
    StorySummary(
      storyId: '11',
      title: '방귀 뀌는 며느리',
      estimatedMinutes: 20,
      topicIds: <String>['folk'],
    ),
    StorySummary(
      storyId: '21',
      title: '해와 달이 된 오누이',
      estimatedMinutes: 15,
      topicIds: <String>['folk'],
    ),
  ],
);

const StoryDetail _detail = StoryDetail(
  storyId: '11',
  title: '방귀 뀌는 며느리',
  estimatedMinutes: 20,
  difficulty: '쉬움',
  topics: <String>['가족'],
  introText: '옛날 어느 마을에…',
  summary: '방귀를 참던 며느리가 마음을 털어놓는 이야기.',
  role: StoryRole(name: '며느리의 친구'),
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
    StoryDetailViewModel viewModelOf(
      StoryRepository repository,
      String id, {
      FreeTalkRepository? freeTalk,
    }) => StoryDetailViewModel(
      GetStoryDetailUseCase(repository),
      StartStorySessionUseCase(repository, _StubHomeRepository()),
      storyId: id,
      freeTalk: freeTalk,
    );

    test('있는 이야기는 success 이고 notFound 가 아니다', () async {
      final vm = viewModelOf(_StubRepository(detail: _detail), '11');

      await vm.load();

      expect(vm.state, ViewState.success);
      expect(vm.isNotFound, isFalse);
      expect(vm.story?.role.name, '며느리의 친구');
    });

    // ── 후속 자유 대화 진입점 ──
    //
    // 완주 여부를 알려 주는 서버 필드가 없어서, 인물 목록이 돌아오는지로
    // 판정합니다. → `docs/BACKEND_REQUESTS_FREE_TALK_ENTRY.md`

    test('인물이 돌아오면 완주로 보고 친구들을 그대로 넘긴다', () async {
      final freeTalk = _StubFreeTalkRepository(
        result: <FreeTalkCharacter>[
          FreeTalkCharacter(
            characterId: 'c1',
            name: '며느리',
            characterKey: 'daughter_in_law',
            lastTalkedAt: DateTime(2026, 8, 17),
          ),
          FreeTalkCharacter(
            characterId: 'c2',
            name: '시아버지',
            characterKey: 'father_in_law',
            lastTalkedAt: DateTime(2026, 8, 18),
          ),
        ],
      );
      final vm = viewModelOf(
        _StubRepository(detail: _detail),
        '11',
        freeTalk: freeTalk,
      );

      await vm.load();

      expect(vm.canFreeTalk, isTrue);
      expect(vm.isCompleted, isTrue);
      // 순서를 뒤섞지 않습니다 — 서버 순서가 이야기에 나온 차례입니다.
      expect(
        vm.freeTalkCharacters.map((FreeTalkCharacter c) => c.name),
        <String>['며느리', '시아버지'],
      );
    });

    test('완주 전(404)이면 도장도 친구도 없고 화면은 멀쩡하다', () async {
      final vm = viewModelOf(
        _StubRepository(detail: _detail),
        '11',
        freeTalk: _StubFreeTalkRepository(
          error: const ServerFailure(message: '완주 전', code: 'NOT_FOUND'),
        ),
      );

      await vm.load();

      // 여기서 error 로 떨어지면 자유 대화와 아무 상관 없는 "시작하기"까지
      // 함께 못 쓰게 됩니다. 이야기를 여는 일과 분리돼 있어야 합니다.
      expect(vm.state, ViewState.success);
      expect(vm.story, isNotNull);
      expect(vm.canFreeTalk, isFalse);
      expect(vm.isCompleted, isFalse);
      expect(vm.freeTalkCharacters, isEmpty);
    });

    test('저장소를 안 주면 아예 묻지 않는다', () async {
      final vm = viewModelOf(_StubRepository(detail: _detail), '11');

      await vm.load();

      expect(vm.canFreeTalk, isFalse);
    });

    test('없는 이야기는 인물도 묻지 않는다', () async {
      final freeTalk = _StubFreeTalkRepository();
      final vm = viewModelOf(_StubRepository(), '999', freeTalk: freeTalk);

      await vm.load();

      // 이야기 자체가 없는데 그 이야기의 인물을 묻는 건 낭비입니다.
      expect(freeTalk.characterCalls, 0);
      expect(vm.canFreeTalk, isFalse);
    });

    test('없는 이야기는 error 가 아니라 notFound 다', () async {
      final vm = viewModelOf(_StubRepository(), '999');

      await vm.load();

      // 여기서 error 로 떨어지면 화면이 "다시 불러오기"를 권하게 되는데,
      // 눌러도 영원히 안 나옵니다.
      expect(vm.state, ViewState.success);
      expect(vm.isNotFound, isTrue);
    });

    test('시작하기는 sessionId 를 돌려주고 화면을 옮기지 않는다', () async {
      final vm = viewModelOf(_StubRepository(detail: _detail), '11');
      await vm.load();

      final String? sessionId = await vm.start();

      expect(sessionId, '9000-11');
      expect(vm.isStarting, isFalse);
    });

    test('로드 전에는 시작할 수 없다', () async {
      final vm = viewModelOf(_StubRepository(detail: _detail), '11');

      expect(await vm.start(), isNull);
    });
  });

  group('StartStorySessionUseCase', () {
    InProgressSession sessionOf(String storyId) => InProgressSession(
      sessionId: 'session-$storyId',
      storyId: storyId,
      storyTitle: '방귀 뀌는 며느리',
      lastCompletedScene: 2,
      totalScenes: 6,
    );

    test('같은 이야기를 진행 중이면 새로 만들지 않고 그 세션으로 이어간다', () async {
      final _StubRepository repository = _StubRepository();
      final useCase = StartStorySessionUseCase(
        repository,
        _StubHomeRepository(inProgressSession: sessionOf('11')),
      );

      expect(await useCase('11'), 'session-11');
      expect(
        repository.startCalls,
        0,
        reason: 'startSession 은 부를 때마다 새 세션을 만듭니다 - 이어할 때는 부르면 안 됩니다',
      );
    });

    test('다른 이야기를 진행 중이면 새로 시작한다', () async {
      final _StubRepository repository = _StubRepository();
      final useCase = StartStorySessionUseCase(
        repository,
        _StubHomeRepository(inProgressSession: sessionOf('21')),
      );

      expect(await useCase('11'), '9000-11');
      expect(repository.startCalls, 1);
    });

    test('진행 중 세션이 없으면 새로 시작한다', () async {
      final _StubRepository repository = _StubRepository();
      final useCase = StartStorySessionUseCase(
        repository,
        _StubHomeRepository(),
      );

      expect(await useCase('11'), '9000-11');
      expect(repository.startCalls, 1);
    });

    test('진행 중 세션 확인이 실패해도 시작하기를 막지 않는다', () async {
      final _StubRepository repository = _StubRepository();
      final useCase = StartStorySessionUseCase(
        repository,
        _StubHomeRepository(error: const NetworkFailure('연결이 끊겼습니다.')),
      );

      expect(await useCase('11'), '9000-11');
      expect(repository.startCalls, 1);
    });
  });
}
