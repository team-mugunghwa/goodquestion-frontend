// 완주한 이야기 → 친구들 → 대화 흐름 육안 확인용 프리뷰. 제품 코드가 아니다.
//
//   flutter run -d chrome -t tool/preview/story_detail_free_talk_preview.dart
//
// 제품 화면(StoryListView · StoryDetailView · FreeTalkCharactersPage ·
// FreeTalkPage)을 스텁 저장소로 띄운다. **눌러서 다닐 수 있다** - 목록에서
// 완주 도장을 보고, 상세에서 친구 얼굴을 누르면 그 친구와의 대화까지 간다.
//
// 자유 대화 엔드포인트가 아직 서버에 없어서(501) 실서버로는 이 흐름을 볼 수
// 없다. 헤드리스 캡처용으로 완주 전 상태는 `?completed=false` 로도 연다.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/router/app_routes.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/features/free_talk/domain/entities/free_talk.dart';
import 'package:goodquestion/features/free_talk/domain/repositories/free_talk_repository.dart';
import 'package:goodquestion/features/free_talk/presentation/views/free_talk_characters_view.dart';
import 'package:goodquestion/features/free_talk/presentation/views/free_talk_view.dart';
import 'package:goodquestion/features/home/domain/entities/home_summary.dart';
import 'package:goodquestion/features/home/domain/entities/planet_summary.dart';
import 'package:goodquestion/features/home/domain/entities/recommended_story.dart';
import 'package:goodquestion/features/home/domain/repositories/home_repository.dart';
import 'package:goodquestion/features/mypage/domain/entities/report_detail.dart';
import 'package:goodquestion/features/mypage/domain/entities/report_summary.dart';
import 'package:goodquestion/features/mypage/domain/repositories/my_page_repository.dart';
import 'package:goodquestion/features/play/domain/entities/play_session.dart';
import 'package:goodquestion/features/play/domain/repositories/play_repository.dart';
import 'package:goodquestion/features/story/domain/entities/story_catalog.dart';
import 'package:goodquestion/features/story/domain/entities/story_detail.dart';
import 'package:goodquestion/features/story/domain/entities/story_summary.dart';
import 'package:goodquestion/features/story/domain/entities/story_topic.dart';
import 'package:goodquestion/features/story/domain/repositories/story_repository.dart';
import 'package:goodquestion/features/story/domain/usecases/get_completed_stories_use_case.dart';
import 'package:goodquestion/features/story/domain/usecases/get_story_catalog_use_case.dart';
import 'package:goodquestion/features/story/domain/usecases/get_story_detail_use_case.dart';
import 'package:goodquestion/features/story/domain/usecases/start_story_session_use_case.dart';
import 'package:goodquestion/features/story/presentation/viewmodels/story_detail_view_model.dart';
import 'package:goodquestion/features/story/presentation/viewmodels/story_list_view_model.dart';
import 'package:goodquestion/features/story/presentation/views/story_detail_view.dart';
import 'package:goodquestion/features/story/presentation/views/story_list_view.dart';
import 'package:provider/provider.dart';

void main() => runApp(const PreviewApp());

/// 방귀 뀌는 며느리의 인물 셋.
///
/// `characterId` 는 **번들 매니페스트의 실제 값**이다
/// (`assets/images/dialogue/banggui/states.json`). 지어낸 id 를 쓰면 얼굴이
/// 로고 마크로 떨어져서 이 프리뷰가 보려는 것이 안 보인다.
const List<FreeTalkCharacter> _friends = <FreeTalkCharacter>[
  FreeTalkCharacter(
    characterId: '55555555-5555-5555-5555-000000000001',
    name: '며느리',
    characterKey: 'daughter_in_law',
  ),
  FreeTalkCharacter(
    characterId: '55555555-5555-5555-5555-000000000002',
    name: '시아버지',
    characterKey: 'father_in_law',
  ),
  FreeTalkCharacter(
    characterId: '55555555-5555-5555-5555-000000000003',
    name: '마을 이장',
    characterKey: 'village_chief',
  ),
];

const String _storyId = '11111111-1111-1111-1111-111111111111';
const String _completedTitle = '방귀 뀌는 며느리';

class PreviewApp extends StatefulWidget {
  const PreviewApp({super.key});

  @override
  State<PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends State<PreviewApp> {
  /// 완주한 이야기로 볼지. 끄면 완주 전(서버 404) 이다.
  ///
  /// 헤드리스 캡처에서는 스위치를 누를 수 없어서 주소로도 받는다.
  ///   `?completed=false`
  bool _completed = Uri.base.queryParameters['completed'] != 'false';

  @override
  Widget build(BuildContext context) {
    final _Stubs stubs = _Stubs(completed: _completed);
    return MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Column(
          children: <Widget>[
            SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Text('완주한 이야기'),
                  Switch(
                    value: _completed,
                    onChanged: (bool next) => setState(() => _completed = next),
                  ),
                ],
              ),
            ),
            // 라우터를 통째로 새로 만든다 - 스위치를 넘기면 처음 화면부터
            // 다시 세워야 스텁이 새 값으로 답한다.
            Expanded(
              key: ValueKey<bool>(_completed),
              child: _Frame(
                child: Router<Object>.withConfig(config: _routerOf(stubs)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  GoRouter _routerOf(_Stubs stubs) => GoRouter(
    // 헤드리스 캡처는 눌러 들어갈 수 없어서 시작 화면을 주소로도 받는다.
    //   `?at=/stories/1111...`
    initialLocation: Uri.base.queryParameters['at'] ?? AppRoutes.stories,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.stories,
        builder: (_, _) => ChangeNotifierProvider<StoryListViewModel>(
          create: (_) => StoryListViewModel(
            GetStoryCatalogUseCase(stubs.stories),
            completedStories: GetCompletedStoriesUseCase(
              stubs.stories,
              stubs.reports,
            ),
          )..load(),
          child: const StoryListView(),
        ),
        routes: <RouteBase>[
          GoRoute(
            path: ':${AppRoutes.storyIdParam}',
            builder: (_, GoRouterState state) =>
                ChangeNotifierProvider<StoryDetailViewModel>(
                  create: (_) => StoryDetailViewModel(
                    GetStoryDetailUseCase(stubs.stories),
                    StartStorySessionUseCase(stubs.stories, stubs.home),
                    storyId: state.pathParameters[AppRoutes.storyIdParam]!,
                    freeTalk: stubs.freeTalk,
                  )..load(),
                  child: const StoryDetailView(),
                ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.freeTalkPath,
        builder: (_, GoRouterState state) => FreeTalkCharactersPage(
          storyId: state.pathParameters[AppRoutes.storyIdParam]!,
          repository: stubs.freeTalk,
        ),
        routes: <RouteBase>[
          GoRoute(
            path: ':${AppRoutes.characterIdParam}',
            builder: (_, GoRouterState state) {
              final Object? extra = state.extra;
              return FreeTalkPage(
                storyId: state.pathParameters[AppRoutes.storyIdParam]!,
                characterId: state.pathParameters[AppRoutes.characterIdParam]!,
                repository: stubs.freeTalk,
                voiceRepository: stubs.play,
                initialCharacter: extra is FreeTalkCharacter ? extra : null,
              );
            },
          ),
        ],
      ),
      // 시작하기를 눌러도 프리뷰가 죽지 않게 자리만 만들어 둔다.
      GoRoute(
        path: '/play/:sessionId',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('(재생 화면은 이 프리뷰 밖)'))),
      ),
    ],
  );
}

/// 폰 폭으로 가두는 액자.
///
/// 헤드리스 크롬은 창을 **512dp 아래로 못 줄인다**(윈도우 최소 창 폭).
/// 그냥 찍으면 512 로 그린 화면을 430 으로 잘라낸 그림이 나와서, 글이
/// 오른쪽으로 넘친 것처럼 보인다 - 진짜 줄바꿈 문제와 구분이 안 된다.
/// `?w=430` 처럼 폭을 주면 그 폭으로 가둔다.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double? width = double.tryParse(Uri.base.queryParameters['w'] ?? '');
    if (width == null) return child;
    return ColoredBox(
      color: const Color(0xFF1B2436),
      child: Center(
        child: SizedBox(width: width, child: child),
      ),
    );
  }
}

/// 이 프리뷰가 쓰는 저장소 묶음.
class _Stubs {
  _Stubs({required this.completed})
    : stories = _StubStories(completed: completed),
      home = const _StubHome(),
      reports = _StubReports(completed: completed),
      freeTalk = _StubFreeTalk(completed: completed),
      play = _StubPlay();

  final bool completed;
  final StoryRepository stories;
  final HomeRepository home;
  final ReportRepository reports;
  final FreeTalkRepository freeTalk;
  final PlayRepository play;
}

/// 인물이 없으면 완주 전(404) 인 척한다.
class _StubFreeTalk implements FreeTalkRepository {
  const _StubFreeTalk({required this.completed});

  final bool completed;

  @override
  Future<List<FreeTalkCharacter>> characters(String storyId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!completed) {
      throw const ServerFailure(message: '완주 전', code: 'NOT_FOUND');
    }
    return _friends;
  }

  @override
  Future<FreeTalkSession> start({
    required String storyId,
    required String characterId,
  }) async {
    final FreeTalkCharacter character = _friends.firstWhere(
      (FreeTalkCharacter c) => c.characterId == characterId,
      orElse: () => _friends.first,
    );
    return FreeTalkSession(
      freeTalkId: 'ft-1',
      character: character,
      opening: FreeTalkSpeech(text: '어? 또 와 줬구나. ${character.name}야, 반가워!'),
      maxTurns: 8,
    );
  }

  @override
  Future<FreeTalkTurn> sendMessage(
    String freeTalkId, {
    required String text,
    String? idempotencyKey,
  }) async => const FreeTalkTurn(
    characterMessage: FreeTalkSpeech(text: '그렇구나. 더 얘기해 줄래?'),
    turnCount: 1,
    ended: false,
  );

  @override
  Future<void> leave(String freeTalkId) async {}

  @override
  Future<FreeTalkSpeech> end(String freeTalkId) async =>
      const FreeTalkSpeech(text: '오늘도 고마워. 다음에 또 보자!');
}

/// 완주 기록. 서버가 완주 목록에 storyId 를 안 줘서 **제목만** 돌려준다.
class _StubReports implements ReportRepository {
  const _StubReports({required this.completed});

  final bool completed;

  @override
  Future<ReportList> getReportList() async => ReportList(
    childName: '지우',
    totalCount: completed ? 1 : 0,
    reports: <ReportSummary>[
      if (completed)
        ReportSummary(
          sessionId: 's1',
          storyTitle: _completedTitle,
          completedAt: DateTime(2026, 8, 18),
          playCount: 1,
          highlightUtterance: '',
        ),
    ],
  );

  @override
  Future<ReportDetail?> getReportDetail(String sessionId) =>
      throw UnimplementedError();
}

class _StubStories implements StoryRepository {
  const _StubStories({required this.completed});

  final bool completed;

  /// 서버가 내려주는 완주한 이야기 id 들.
  @override
  Future<Set<String>> getCompletedStoryIds() async =>
      completed ? const <String>{_storyId} : const <String>{};

  @override
  Future<StoryCatalog> getCatalog() async => const StoryCatalog(
    topics: <StoryTopic>[
      StoryTopic(id: 'all', label: '전체', icon: TopicIcon.all),
      StoryTopic(id: 'folk', label: '옛이야기', icon: TopicIcon.folk),
    ],
    stories: <StorySummary>[
      StorySummary(
        storyId: _storyId,
        title: _completedTitle,
        estimatedMinutes: 10,
        topicIds: <String>['folk'],
      ),
      StorySummary(
        storyId: '22',
        title: '작은 씨앗',
        estimatedMinutes: 8,
        topicIds: <String>['folk'],
      ),
    ],
  );

  @override
  Future<StoryDetail?> getStoryDetail(String storyId) async =>
      const StoryDetail(
        storyId: _storyId,
        title: _completedTitle,
        estimatedMinutes: 10,
        difficulty: '보통',
        topics: <String>['옛이야기'],
        summary: '방귀를 참던 며느리가 마음을 여는 이야기.',
        introText:
            '옛날 어느 마을에, 방귀를 아주 크게 뀌는 며느리가 살았어요.\n'
            '이상하게 볼까 봐 걱정이 되어서, 며느리는 방귀를 꾹꾹 참고 있어요.',
        role: StoryRole(name: '마을 사람들의 고민을 들어주는 아이'),
        sceneCount: 9,
      );

  @override
  Future<String> startSession(String storyId) async => 's1';
}

class _StubHome implements HomeRepository {
  const _StubHome();

  @override
  Future<HomeSummary> getHomeSummary() async => const HomeSummary(
    recommendedStories: <RecommendedStory>[],
    planet: PlanetSummary(stardustBalance: 0),
  );
}

/// 자유 대화가 쓰는 것은 STT·TTS 둘뿐이다. 나머지는 불리면 안 되는 자리라
/// [noSuchMethod] 로 곧장 터뜨린다.
class _StubPlay implements PlayRepository {
  @override
  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) async => const PlaySpeechAudio(audioUrl: '');

  @override
  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) async =>
      const PlayTranscription(
        text: '나도 반가워!',
        confidence: 0.9,
        lowConfidence: false,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
