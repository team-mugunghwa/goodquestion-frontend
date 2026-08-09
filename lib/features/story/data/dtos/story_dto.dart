import '../../domain/entities/story_catalog.dart';
import '../../domain/entities/story_detail.dart';
import '../../domain/entities/story_summary.dart';
import '../../domain/entities/story_topic.dart';

/// 서버 응답(지금은 더미 JSON)의 모양 그대로.
///
/// `json_serializable` 을 쓰지 않고 손으로 씁니다 — 화면 하나 만들 때마다
/// `build_runner` 2분을 기다릴 이유가 없습니다. 대신 **모든 캐스팅을 방어적으로**
/// 합니다. 더미는 컴파일러가 검사하지 않으므로, 필드 하나가 빠져도 화면 전체가
/// 죽는 대신 그 값만 기본값으로 떨어져야 합니다.
/// → `docs/SCREEN_RECIPE.md`
class StoryCatalogDto {
  const StoryCatalogDto({required this.topics, required this.stories});

  factory StoryCatalogDto.fromJson(Map<String, dynamic> json) =>
      StoryCatalogDto(
        topics: _list(
          json['topics'],
        ).map(StoryTopicDto.fromJson).toList(growable: false),
        stories: _list(
          json['stories'],
        ).map(StorySummaryDto.fromJson).toList(growable: false),
      );

  final List<StoryTopicDto> topics;
  final List<StorySummaryDto> stories;

  StoryCatalog toEntity() => StoryCatalog(
    topics: topics
        .map((StoryTopicDto dto) => dto.toEntity())
        .toList(growable: false),
    stories: stories
        .map((StorySummaryDto dto) => dto.toEntity())
        .toList(growable: false),
  );
}

class StoryTopicDto {
  const StoryTopicDto({
    required this.id,
    required this.label,
    required this.icon,
  });

  factory StoryTopicDto.fromJson(Map<String, dynamic> json) => StoryTopicDto(
    id: json['id'] as String? ?? StoryTopic.allId,
    label: json['label'] as String? ?? '',
    icon: json['icon'] as String?,
  );

  final String id;
  final String label;
  final String? icon;

  StoryTopic toEntity() =>
      StoryTopic(id: id, label: label, icon: TopicIcon.fromKey(icon));
}

class StorySummaryDto {
  const StorySummaryDto({
    required this.storyId,
    required this.title,
    required this.estimatedMinutes,
    required this.topicIds,
    this.image,
  });

  factory StorySummaryDto.fromJson(Map<String, dynamic> json) =>
      StorySummaryDto(
        storyId: json['storyId'] as int? ?? 0,
        title: json['title'] as String? ?? '',
        image: json['image'] as String?,
        estimatedMinutes: json['estimatedMinutes'] as int? ?? 0,
        topicIds: (json['topicIds'] as List<dynamic>? ?? <dynamic>[])
            .whereType<String>()
            .toList(growable: false),
      );

  final int storyId;
  final String title;
  final String? image;
  final int estimatedMinutes;
  final List<String> topicIds;

  StorySummary toEntity() => StorySummary(
    storyId: storyId,
    title: title,
    image: image,
    estimatedMinutes: estimatedMinutes,
    topicIds: topicIds,
  );
}

class StoryDetailDto {
  const StoryDetailDto({
    required this.storyId,
    required this.title,
    required this.estimatedMinutes,
    required this.difficulty,
    required this.topics,
    required this.introText,
    required this.situationText,
    required this.role,
    this.coverImage,
    this.introAudio,
  });

  factory StoryDetailDto.fromJson(Map<String, dynamic> json) => StoryDetailDto(
    storyId: json['storyId'] as int? ?? 0,
    title: json['title'] as String? ?? '',
    coverImage: json['coverImage'] as String?,
    estimatedMinutes: json['estimatedMinutes'] as int? ?? 0,
    difficulty: json['difficulty'] as String? ?? '',
    topics: (json['topics'] as List<dynamic>? ?? <dynamic>[])
        .whereType<String>()
        .toList(growable: false),
    introText: json['introText'] as String? ?? '',
    situationText: json['situationText'] as String? ?? '',
    introAudio: json['introAudio'] as String?,
    role: StoryRoleDto.fromJson(
      json['role'] as Map<String, dynamic>? ?? <String, dynamic>{},
    ),
  );

  final int storyId;
  final String title;
  final String? coverImage;
  final int estimatedMinutes;
  final String difficulty;
  final List<String> topics;
  final String introText;
  final String situationText;
  final String? introAudio;
  final StoryRoleDto role;

  StoryDetail toEntity() => StoryDetail(
    storyId: storyId,
    title: title,
    coverImage: coverImage,
    estimatedMinutes: estimatedMinutes,
    difficulty: difficulty,
    topics: topics,
    introText: introText,
    situationText: situationText,
    introAudio: introAudio,
    role: role.toEntity(),
  );
}

class StoryRoleDto {
  const StoryRoleDto({
    required this.name,
    required this.description,
    this.characterImage,
  });

  factory StoryRoleDto.fromJson(Map<String, dynamic> json) => StoryRoleDto(
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    characterImage: json['characterImage'] as String?,
  );

  final String name;
  final String description;
  final String? characterImage;

  StoryRole toEntity() => StoryRole(
    name: name,
    description: description,
    characterImage: characterImage,
  );
}

List<Map<String, dynamic>> _list(Object? raw) =>
    (raw as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
