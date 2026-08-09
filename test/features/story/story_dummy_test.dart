import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/features/story/data/datasources/story_local_data_source.dart';
import 'package:goodquestion/features/story/data/repositories/story_repository_mock.dart';
import 'package:goodquestion/features/story/domain/entities/story_catalog.dart';
import 'package:goodquestion/features/story/domain/entities/story_detail.dart';
import 'package:goodquestion/features/story/domain/entities/story_summary.dart';
import 'package:goodquestion/features/story/domain/entities/story_topic.dart';

/// 더미 JSON 이 화면이 기대하는 모양인지 검사합니다.
/// 더미는 컴파일러가 안 봅니다 — 오타를 여기서 잡습니다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const StoryRepositoryMock repository = StoryRepositoryMock(
    StoryLocalDataSource(),
    latency: Duration.zero,
  );

  test('목록 더미가 주제와 이야기로 파싱된다', () async {
    final StoryCatalog catalog = await repository.getCatalog();

    expect(catalog.topics, isNotEmpty);
    expect(catalog.topics.first.isAll, isTrue, reason: '첫 칩은 항상 "전체"여야 합니다');
    expect(catalog.stories, isNotEmpty);
    for (final StorySummary story in catalog.stories) {
      expect(story.title, isNotEmpty);
      expect(story.estimatedMinutes, greaterThan(0));
    }
  });

  test('모든 이야기의 주제가 칩 목록에 있다', () async {
    final StoryCatalog catalog = await repository.getCatalog();
    final Set<String> known = catalog.topics
        .map((StoryTopic t) => t.id)
        .toSet();

    for (final StorySummary story in catalog.stories) {
      for (final String topicId in story.topicIds) {
        // 칩에 없는 주제를 단 이야기는 어떤 필터로도 안 보입니다.
        expect(
          known,
          contains(topicId),
          reason: '${story.title} 의 주제 $topicId',
        );
      }
    }
  });

  test('전체 필터는 모든 이야기를 통과시킨다', () async {
    final StoryCatalog catalog = await repository.getCatalog();

    expect(catalog.filtered(StoryTopic.allId).length, catalog.stories.length);
  });

  test('목록의 모든 이야기가 상세를 가진다', () async {
    final StoryCatalog catalog = await repository.getCatalog();

    for (final StorySummary story in catalog.stories) {
      final StoryDetail? detail = await repository.getStoryDetail(
        story.storyId,
      );
      // 카드를 눌렀는데 "찾을 수 없어"로 빠지면 시연이 무너집니다.
      expect(detail, isNotNull, reason: '${story.title}(${story.storyId})');
      expect(detail!.role.name, isNotEmpty, reason: '역할은 이 화면의 핵심입니다');
      expect(detail.introText, isNotEmpty);
    }
  });

  test('없는 이야기는 예외가 아니라 null 이다', () async {
    // 잘못된 주소와 로드 실패는 화면이 다르게 그려야 합니다.
    expect(await repository.getStoryDetail(999999), isNull);
  });

  test('시작하기는 같은 이야기에 같은 sessionId 를 준다', () async {
    expect(
      await repository.startSession(11),
      await repository.startSession(11),
    );
  });
}
