import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_assets.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/text/korean_wrap.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/core/widgets/app_bottom_nav.dart';
import 'package:goodquestion/core/widgets/completed_badge.dart';
import 'package:goodquestion/core/widgets/speaker_button.dart';
import 'package:goodquestion/core/widgets/story_card.dart';
import 'package:goodquestion/core/widgets/story_thumbnail.dart';
import 'package:goodquestion/features/free_talk/domain/entities/free_talk.dart';
import 'package:goodquestion/features/free_talk/domain/repositories/free_talk_repository.dart';
import 'package:goodquestion/features/home/domain/entities/home_summary.dart';
import 'package:goodquestion/features/home/domain/entities/planet_summary.dart';
import 'package:goodquestion/features/home/domain/entities/recommended_story.dart';
import 'package:goodquestion/features/home/domain/repositories/home_repository.dart';
import 'package:goodquestion/features/mypage/domain/entities/report_detail.dart';
import 'package:goodquestion/features/mypage/domain/entities/report_summary.dart';
import 'package:goodquestion/features/mypage/domain/repositories/my_page_repository.dart';
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
import 'package:goodquestion/features/story/presentation/widgets/role_card.dart';
import 'package:provider/provider.dart';
import '../../support/kid_text.dart';

/// 진행 중 세션이 없는 홈. 상세 화면 테스트는 "시작하기 → 새 세션" 만
/// 보면 되므로 홈은 빈 값으로 둡니다.
/// 방귀 뀌는 며느리의 인물 셋. 순서는 이야기에 나온 차례입니다.
const List<FreeTalkCharacter> _threeFriends = <FreeTalkCharacter>[
  FreeTalkCharacter(
    characterId: 'c1',
    name: '며느리',
    characterKey: 'daughter_in_law',
  ),
  FreeTalkCharacter(
    characterId: 'c2',
    name: '시아버지',
    characterKey: 'father_in_law',
  ),
  FreeTalkCharacter(
    characterId: 'c3',
    name: '마을 이장',
    characterKey: 'village_chief',
  ),
];

/// 완주 기록. 서버가 완주 목록에 storyId 를 안 줘서 **제목만** 돌려줍니다.
class _StubReports implements ReportRepository {
  const _StubReports(this.titles, {this.error});

  final List<String> titles;
  final Object? error;

  @override
  Future<ReportList> getReportList() async {
    if (error != null) throw error!;
    return ReportList(
      childName: '지우',
      totalCount: titles.length,
      reports: <ReportSummary>[
        for (final String title in titles)
          ReportSummary(
            sessionId: 's-$title',
            storyTitle: title,
            completedAt: DateTime(2026, 8, 18),
            playCount: 1,
            highlightUtterance: '',
          ),
      ],
    );
  }

  @override
  Future<ReportDetail?> getReportDetail(String sessionId) =>
      throw UnimplementedError();
}

class _StubFreeTalkRepository implements FreeTalkRepository {
  const _StubFreeTalkRepository({
    this.result = const <FreeTalkCharacter>[],
    this.error,
  });

  final List<FreeTalkCharacter> result;
  final Object? error;

  @override
  Future<List<FreeTalkCharacter>> characters(String storyId) async {
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
  @override
  Future<HomeSummary> getHomeSummary() async => const HomeSummary(
    recommendedStories: <RecommendedStory>[],
    planet: PlanetSummary(stardustBalance: 0),
  );
}

class _StubRepository implements StoryRepository {
  _StubRepository({
    this.catalog,
    this.detail,
    this.error,
    this.completedStoryIds = const <String>{},
  });

  final StoryCatalog? catalog;
  final StoryDetail? detail;
  final Object? error;

  /// 완주한 이야기. 서버가 id 로 내려줍니다.
  final Set<String> completedStoryIds;

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

  @override
  Future<Set<String>> getCompletedStoryIds() async {
    if (error != null) throw error!;
    return completedStoryIds;
  }

  @override
  Future<String> startSession(String storyId) async => '9000-$storyId';
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
  summary: '방귀를 참던 며느리가 마음을 털어놓는 이야기.',
  introText: '옛날 어느 마을에 방귀를 참는 며느리가 살았어요.',
  introAudio: 'assets/sounds/story_11_intro.mp3',
  role: StoryRole(name: '며느리의 친구'),
);

/// 대화 화면 캐릭터 에셋이 있는 유일한 이야기. 역할 카드가 로고 마크
/// 대신 그 캐릭터를 씁니다. → `role_card.dart`
const StoryDetail _withCharacter = StoryDetail(
  storyId: '11111111-1111-1111-1111-111111111111',
  title: '방귀 뀌는 며느리',
  estimatedMinutes: 20,
  difficulty: '쉬움',
  topics: <String>['가족'],
  summary: '방귀를 참던 며느리가 마음을 털어놓는 이야기.',
  introText: '옛날 어느 마을에 방귀를 참는 며느리가 살았어요.',
  role: StoryRole(name: '며느리의 친구'),
);

/// 서버 시드가 아직 안 채워진 이야기. 8편 중 7편이 이 모양입니다 —
/// `childRole` · `intro` 가 빈 문자열이고 도입 음성도 없습니다.
const StoryDetail _seedless = StoryDetail(
  storyId: '11',
  title: '방귀 뀌는 며느리',
  estimatedMinutes: 20,
  difficulty: '쉬움',
  topics: <String>['가족'],
  summary: '방귀를 참던 며느리가 마음을 털어놓는 이야기.',
  introText: '',
  role: StoryRole(name: ''),
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(1280, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: child));
    await tester.pumpAndSettle();
  }

  Widget listUnder(
    StoryRepository repository, {
    GetCompletedStoriesUseCase? completed,
  }) => ChangeNotifierProvider<StoryListViewModel>(
    create: (_) => StoryListViewModel(
      GetStoryCatalogUseCase(repository),
      completedStories: completed,
    )..load(),
    child: const StoryListView(),
  );

  Widget detailUnder(
    StoryRepository repository, {
    String storyId = '11',
    FreeTalkRepository? freeTalk,
  }) => ChangeNotifierProvider<StoryDetailViewModel>(
    create: (_) => StoryDetailViewModel(
      GetStoryDetailUseCase(repository),
      StartStorySessionUseCase(repository, _StubHomeRepository()),
      storyId: storyId,
      freeTalk: freeTalk,
    )..load(),
    child: const StoryDetailView(),
  );

  group('이야기 목록', () {
    testWidgets('헤더·칩·카드·하단 내비가 함께 보인다', (WidgetTester tester) async {
      await pump(tester, listUnder(_StubRepository(catalog: _catalog)));

      expect(find.text(StoryListStrings.title), findsOneWidget);
      expect(find.text('옛이야기'), findsWidgets);
      expect(find.byType(StoryCard), findsNWidgets(2));
      expect(find.byType(AppBottomNav), findsOneWidget);
    });

    testWidgets('주제를 누르면 그리드가 좁혀진다', (WidgetTester tester) async {
      await pump(tester, listUnder(_StubRepository(catalog: _catalog)));

      await tester.tap(find.text('모험'));
      await tester.pumpAndSettle();

      expect(find.byType(StoryCard), findsNothing);
      expect(find.text(StoryListStrings.showAll), findsOneWidget);
    });

    testWidgets('빈 상태에서 전체 보기로 빠져나온다', (WidgetTester tester) async {
      await pump(tester, listUnder(_StubRepository(catalog: _catalog)));
      await tester.tap(find.text('모험'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(StoryListStrings.showAll));
      await tester.pumpAndSettle();

      expect(find.byType(StoryCard), findsNWidgets(2));
    });

    testWidgets('실패하면 다시 불러오기 버튼이 뜨고 내비는 남는다', (WidgetTester tester) async {
      await pump(
        tester,
        listUnder(_StubRepository(error: const NetworkFailure())),
      );

      expect(find.text(AppStrings.retryKid), findsOneWidget);
      expect(find.byType(AppBottomNav), findsOneWidget);
    });

    testWidgets('폰 폭에서도 레이아웃이 무너지지 않는다', (WidgetTester tester) async {
      await pump(
        tester,
        listUnder(_StubRepository(catalog: _catalog)),
        size: const Size(390, 844),
      );

      expect(find.byType(StoryCard), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('완주한 이야기 카드에만 도장이 찍힌다', (WidgetTester tester) async {
      await pump(
        tester,
        listUnder(
          _StubRepository(catalog: _catalog),
          // 서버가 완주한 이야기 id 를 내려주는 정식 경로.
          completed: GetCompletedStoriesUseCase(
            _StubRepository(
              catalog: _catalog,
              completedStoryIds: <String>{'11'},
            ),
            const _StubReports(<String>[]),
          ),
        ),
      );

      // 목록에 두 편이 있고, 그중 한 편만 끝냈습니다.
      expect(find.byType(CompletedBadge), findsOneWidget);
    });

    testWidgets('완주 목록을 못 불러도 목록은 멀쩡하다', (WidgetTester tester) async {
      await pump(
        tester,
        listUnder(
          _StubRepository(catalog: _catalog),
          // 정식 경로도 폴백(리포트)도 실패한 상황.
          completed: GetCompletedStoriesUseCase(
            _StubRepository(error: const UnknownFailure()),
            const _StubReports(<String>[], error: UnknownFailure()),
          ),
        ),
      );

      // 도장은 있으면 좋은 정보입니다. 못 불렀다고 목록을 에러로 만들지
      // 않습니다.
      expect(find.byType(StoryCard), findsNWidgets(2));
      expect(find.byType(CompletedBadge), findsNothing);
    });
  });

  group('이야기 상세', () {
    testWidgets('제목·소개·도입문·역할·시작하기가 보인다', (WidgetTester tester) async {
      await pump(tester, detailUnder(_StubRepository(detail: _detail)));

      expect(find.text('방귀 뀌는 며느리'), findsOneWidget);
      // 소개(3인칭)와 도입문(아이에게 하는 말)은 다른 자리의 다른 글입니다.
      expect(find.textContaining('마음을 털어놓는'.keepWords), findsOneWidget);
      expect(find.textContaining('옛날 어느 마을에'.keepWords), findsOneWidget);
      expect(find.text(StoryDetailStrings.roleIntro), findsOneWidget);
      expect(find.textContaining('며느리의 친구'.keepWords), findsOneWidget);
      expect(find.text(StoryDetailStrings.listen), findsOneWidget);
      expect(find.text(StoryDetailStrings.start), findsOneWidget);
    });

    testWidgets('태블릿은 표지 | 글 2단으로 갈라진다', (WidgetTester tester) async {
      // 아이패드 가로. 표지는 **폭이 아니라 높이**에 맞춰 서야 합니다 —
      // 2:3 을 폭 기준으로 깔면 768 높이에서 세로가 넘칩니다.
      await pump(
        tester,
        detailUnder(_StubRepository(detail: _detail)),
        size: const Size(1024, 768),
      );

      final Rect cover = tester.getRect(find.byType(StoryThumbnail));
      final Rect chip = tester.getRect(find.text('쉬움'));
      // 표지가 왼쪽, 글이 오른쪽.
      expect(cover.right, lessThanOrEqualTo(chip.left));
      // 세로 2:3 그림책 판형 전체가, 잘리지 않고, 한 화면에.
      expect(
        cover.height / cover.width,
        closeTo(1 / StoryThumbnail.portrait, 0.01),
      );
      expect(cover.bottom, lessThanOrEqualTo(768));
    });

    testWidgets('넘치는 것은 오른쪽 글이고 표지는 제자리에 남는다', (WidgetTester tester) async {
      // 화면 전체를 스크롤시키면 표지가 위로 잘려 올라갑니다. 이 화면에서
      // 아이가 "무슨 이야기인지" 판단하는 유일한 그림이라 표지는 고정입니다.
      await pump(
        tester,
        detailUnder(_StubRepository(detail: _detail)),
        size: const Size(1024, 768),
      );

      final Rect before = tester.getRect(find.byType(StoryThumbnail));
      await tester.ensureVisible(find.byType(RoleCard));
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byType(StoryThumbnail)), before);
      expect(
        tester.getRect(find.byType(RoleCard)).bottom,
        lessThanOrEqualTo(768),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('폰은 2단으로 쪼개지 않고 세로로 쌓는다', (WidgetTester tester) async {
      await pump(
        tester,
        detailUnder(_StubRepository(detail: _detail)),
        size: const Size(390, 844),
      );

      final Rect cover = tester.getRect(find.byType(StoryThumbnail));
      final Rect chip = tester.getRect(find.text('쉬움'));
      // 표지 아래로 글이 옵니다. 390dp 를 둘로 나누면 표지도 글도 못 씁니다.
      expect(cover.bottom, lessThanOrEqualTo(chip.top));
      // 폰에서 2:3 을 전폭으로 깔면 첫 화면이 표지 하나로 끝납니다.
      expect(cover.width / cover.height, closeTo(StoryThumbnail.wide, 0.01));
    });

    testWidgets('시드가 비면 빈 카드 대신 섹션이 사라진다', (WidgetTester tester) async {
      await pump(tester, detailUnder(_StubRepository(detail: _seedless)));

      // 역할 카드도, 도입 카드도, 영영 안 눌리는 "들려줘"도 없습니다.
      expect(find.byType(RoleCard), findsNothing);
      expect(find.text(StoryDetailStrings.roleIntro), findsNothing);
      expect(find.byType(SpeakerButton), findsNothing);
      // 남는 것만으로도 화면은 성립합니다 — 제목·소개·칩·시작하기.
      expect(find.text('방귀 뀌는 며느리'), findsOneWidget);
      expect(find.textContaining('마음을 털어놓는'.keepWords), findsOneWidget);
      expect(find.text('쉬움'), findsOneWidget);
      expect(find.text(StoryDetailStrings.start), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('빈 시드도 폰 폭에서 무너지지 않는다', (WidgetTester tester) async {
      await pump(
        tester,
        detailUnder(_StubRepository(detail: _seedless)),
        size: const Size(390, 844),
      );

      expect(find.text(StoryDetailStrings.start), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('역할 카드는 폰에서 세로로 쌓인다', (WidgetTester tester) async {
      // 좁으면 카드를 줄이는 게 아니라 레이아웃을 바꿉니다 — 160 짜리 그림
      // 옆에 이름을 붙이면 폰에서 이름이 세 줄로 쪼개집니다.
      await pump(
        tester,
        detailUnder(_StubRepository(detail: _detail)),
        size: const Size(390, 844),
      );
      await tester.ensureVisible(find.byType(RoleCard));
      await tester.pumpAndSettle();

      final Offset avatar = tester.getCenter(
        find
            .descendant(of: find.byType(RoleCard), matching: find.byType(Image))
            .first,
      );
      final Offset label = tester.getCenter(
        find.text(StoryDetailStrings.roleIntro),
      );
      // 그림 아래에 글, 그리고 둘 다 같은 세로축 위에.
      expect(label.dy, greaterThan(avatar.dy));
      expect((label.dx - avatar.dx).abs(), lessThan(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('캐릭터가 있는 이야기는 역할 카드에 그 캐릭터가 뜬다', (WidgetTester tester) async {
      await pump(tester, detailUnder(_StubRepository(detail: _withCharacter)));

      final Image avatar = tester.widget<Image>(
        find.descendant(
          of: find.byType(RoleCard),
          matching: find.byType(Image),
        ),
      );
      expect(
        (avatar.image as AssetImage).assetName,
        contains('dialogue/banggui'),
      );
    });

    testWidgets('캐릭터가 없는 이야기는 로고 마크로 돌아간다', (WidgetTester tester) async {
      // 8편 중 7편이 이 상태입니다. 빈 원반이 되면 안 됩니다.
      await pump(tester, detailUnder(_StubRepository(detail: _detail)));

      final Image avatar = tester.widget<Image>(
        find.descendant(
          of: find.byType(RoleCard),
          matching: find.byType(Image),
        ),
      );
      expect((avatar.image as AssetImage).assetName, AppAssets.logoMark);
    });

    testWidgets('없는 이야기는 목록으로 가는 문을 준다', (WidgetTester tester) async {
      await pump(tester, detailUnder(_StubRepository(), storyId: '999'));

      expect(find.text(StoryDetailStrings.notFound), findsOneWidget);
      expect(find.text(StoryDetailStrings.goToList), findsOneWidget);
      // 없는 이야기를 시작할 수는 없습니다.
      expect(find.text(StoryDetailStrings.start), findsNothing);
      // "다시 불러오기"를 권하면 안 됩니다 — 눌러도 영원히 안 나옵니다.
      expect(find.text(AppStrings.retryKid), findsNothing);
    });

    testWidgets('들려줘를 누르면 재생 상태로 바뀐다', (WidgetTester tester) async {
      await pump(tester, detailUnder(_StubRepository(detail: _detail)));

      await tester.ensureVisible(find.text(StoryDetailStrings.listen));
      await tester.pumpAndSettle();
      await tester.tap(find.text(StoryDetailStrings.listen));
      await tester.pump();

      expect(tester.takeException(), isNull);
      // 무음 환경에서도 눌린 게 보여야 하므로 아이콘이 파형으로 바뀝니다.
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);

      // 재생이 끝나면 스스로 원상 복귀합니다.
      await tester.pump(SpeakerButton.mockDuration);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.graphic_eq_rounded), findsNothing);
    });

    // ── 후속 자유 대화 진입점 ──

    testWidgets('완주한 이야기는 친구들 카드와 완주 도장이 함께 뜬다', (WidgetTester tester) async {
      await pump(
        tester,
        detailUnder(
          _StubRepository(detail: _detail),
          freeTalk: const _StubFreeTalkRepository(result: _threeFriends),
        ),
        size: const Size(430, 1400),
      );

      // 얼굴이 셋 다 보여야 합니다. 버튼 한 줄이었을 때는 친구가 셋이라는
      // 사실 자체가 화면에 없었습니다.
      expect(find.text(FreeTalkStrings.friendsIntro), findsOneWidget);
      expect(findKidText('며느리'), findsOneWidget);
      expect(findKidText('시아버지'), findsOneWidget);
      expect(findKidText('마을 이장'), findsOneWidget);
      // 표지 도장 — 목록 카드와 같은 뱃지입니다.
      expect(find.byType(CompletedBadge), findsOneWidget);
      // 하단 버튼은 여전히 하나뿐이고, 이름만 "다시 듣기"로 바뀝니다.
      expect(find.text(StoryDetailStrings.restart), findsOneWidget);
      expect(find.text(StoryDetailStrings.start), findsNothing);
    });

    testWidgets('완주 전이면 친구도 도장도 없다', (WidgetTester tester) async {
      await pump(
        tester,
        detailUnder(
          _StubRepository(detail: _detail),
          freeTalk: const _StubFreeTalkRepository(
            error: ServerFailure(message: '완주 전', code: 'NOT_FOUND'),
          ),
        ),
      );

      expect(find.text(StoryDetailStrings.start), findsOneWidget);
      expect(find.text(FreeTalkStrings.friendsIntro), findsNothing);
      expect(find.byType(CompletedBadge), findsNothing);
    });

    testWidgets('폰 폭에서도 시작하기가 하단에 남는다', (WidgetTester tester) async {
      await pump(
        tester,
        detailUnder(_StubRepository(detail: _detail)),
        size: const Size(390, 844),
      );

      expect(find.text(StoryDetailStrings.start), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
