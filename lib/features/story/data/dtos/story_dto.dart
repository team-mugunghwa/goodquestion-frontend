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

  /// 더미는 숫자 id 를 씁니다. 엔티티는 서버 UUID 에 맞춰 String 이라
  /// 여기서만 변환합니다 — 더미 JSON 은 손대지 않습니다.
  StorySummary toEntity() => StorySummary(
    storyId: storyId.toString(),
    title: title,
    image: image,
    estimatedMinutes: estimatedMinutes,
    topicIds: topicIds,
  );
}

/// 더미 JSON(`assets/dummy/story_details.json`)의 모양.
///
/// 이 더미는 서버가 붙기 전에 쓰던 것이라 **서버에 없는 키**(`situationText`,
/// `role.description`)를 아직 들고 있습니다. 엔티티에서 걷어낸 필드라 여기서
/// 읽지 않고 그냥 흘려보냅니다 — 더미 파일은 손대지 않습니다.
class StoryDetailDto {
  const StoryDetailDto({
    required this.storyId,
    required this.title,
    required this.estimatedMinutes,
    required this.difficulty,
    required this.topics,
    required this.summary,
    required this.introText,
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
    // 더미에는 아직 `summary` 키가 없어 빈 문자열입니다. 화면은 비면 그 줄을
    // 안 그리므로 더미도 그대로 성립합니다.
    summary: json['summary'] as String? ?? '',
    introText: json['introText'] as String? ?? '',
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
  final String summary;
  final String introText;
  final String? introAudio;
  final StoryRoleDto role;

  /// [StorySummaryDto.toEntity] 와 같은 이유로 여기서만 String 변환합니다.
  StoryDetail toEntity() => StoryDetail(
    storyId: storyId.toString(),
    title: title,
    coverImage: coverImage,
    estimatedMinutes: estimatedMinutes,
    difficulty: difficulty,
    topics: topics,
    summary: summary,
    introText: introText,
    introAudio: introAudio,
    role: role.toEntity(),
  );
}

class StoryRoleDto {
  const StoryRoleDto({required this.name, this.characterImage});

  factory StoryRoleDto.fromJson(Map<String, dynamic> json) => StoryRoleDto(
    name: json['name'] as String? ?? '',
    characterImage: json['characterImage'] as String?,
  );

  final String name;
  final String? characterImage;

  StoryRole toEntity() => StoryRole(name: name, characterImage: characterImage);
}

List<Map<String, dynamic>> _list(Object? raw) =>
    (raw as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
