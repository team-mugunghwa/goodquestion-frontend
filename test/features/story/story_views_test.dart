import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/core/widgets/app_bottom_nav.dart';
import 'package:goodquestion/core/widgets/speaker_button.dart';
import 'package:goodquestion/core/widgets/story_card.dart';
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
import 'package:goodquestion/features/story/presentation/views/story_detail_view.dart';
import 'package:goodquestion/features/story/presentation/views/story_list_view.dart';
import 'package:provider/provider.dart';

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
  introText: '옛날 어느 마을에 방귀를 참는 며느리가 살았어요.',
  situationText: '오늘은 며느리가 말해 줄 참이에요.',
  introAudio: 'assets/sounds/story_11_intro.mp3',
  role: StoryRole(name: '며느리의 친구', description: '고민을 들어주게 될 거야.'),
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

  Widget listUnder(StoryRepository repository) =>
      ChangeNotifierProvider<StoryListViewModel>(
        create: (_) =>
            StoryListViewModel(GetStoryCatalogUseCase(repository))..load(),
        child: const StoryListView(),
      );

  Widget detailUnder(StoryRepository repository, {String storyId = '11'}) =>
      ChangeNotifierProvider<StoryDetailViewModel>(
        create: (_) => StoryDetailViewModel(
          GetStoryDetailUseCase(repository),
          StartStorySessionUseCase(repository),
          storyId: storyId,
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
  });

  group('이야기 상세', () {
    testWidgets('제목·도입문·역할·시작하기가 보인다', (WidgetTester tester) async {
      await pump(tester, detailUnder(_StubRepository(detail: _detail)));

      expect(find.text('방귀 뀌는 며느리'), findsOneWidget);
      expect(find.textContaining('옛날 어느 마을에'), findsOneWidget);
      expect(find.textContaining('며느리의 친구'), findsOneWidget);
      expect(find.text(StoryDetailStrings.listen), findsOneWidget);
      expect(find.text(StoryDetailStrings.start), findsOneWidget);
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
