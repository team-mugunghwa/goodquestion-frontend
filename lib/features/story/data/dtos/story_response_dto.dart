import '../../domain/entities/story_catalog.dart';
import '../../domain/entities/story_detail.dart';
import '../../domain/entities/story_summary.dart';
import '../../domain/entities/story_topic.dart';

/// 서버 `GET /stories` · `GET /stories/{storyId}` 응답 매핑.
/// → `api_spec.md` §3.5
///
/// `json_serializable` 을 쓰지 않고 손으로 씁니다. 로컬 더미 DTO
/// (`story_dto.dart`) 와 같은 이유입니다 — 모든 캐스팅을 방어적으로 합니다.
class StoryCardResponseDto {
  const StoryCardResponseDto({
    required this.id,
    required this.title,
    required this.summary,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.topics,
    this.imageUrl,
  });

  factory StoryCardResponseDto.fromJson(Map<String, dynamic> json) =>
      StoryCardResponseDto(
        id: json['id']?.toString() ?? '',
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        difficulty: json['difficulty'] as String? ?? '',
        estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt() ?? 0,
        imageUrl: json['imageUrl'] as String?,
        topics: (json['topics'] as List<dynamic>? ?? <dynamic>[])
            .whereType<String>()
            .toList(growable: false),
      );

  final String id;
  final String title;
  final String summary;
  final String difficulty;
  final int estimatedMinutes;
  final String? imageUrl;
  final List<String> topics;

  StorySummary toSummary() => StorySummary(
    storyId: id,
    title: title,
    image: imageUrl,
    estimatedMinutes: estimatedMinutes,
    topicIds: topics,
  );
}

/// `StoryListResponse` — `{stories, topics}`.
class StoryListResponseDto {
  const StoryListResponseDto({required this.stories, required this.topicNames});

  factory StoryListResponseDto.fromJson(Map<String, dynamic> json) =>
      StoryListResponseDto(
        stories: (json['stories'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(StoryCardResponseDto.fromJson)
            .toList(growable: false),
        topicNames: (json['topics'] as List<dynamic>? ?? <dynamic>[])
            .whereType<String>()
            .toList(growable: false),
      );

  final List<StoryCardResponseDto> stories;

  /// 서버는 주제를 **이름 문자열**로만 준다(`GET /api/topics`의 UUID id 와는
  /// 별개). 목록 필터가 이름으로 서버 응답의 이야기별 `topics` 와 매칭돼야
  /// 하므로, 여기서도 **이름을 그대로 필터 id 로 씁니다.**
  final List<String> topicNames;

  StoryCatalog toEntity() => StoryCatalog(
    topics: <StoryTopic>[
      const StoryTopic(id: StoryTopic.allId, label: '전체', icon: TopicIcon.all),
      for (final String name in topicNames)
        StoryTopic(id: name, label: name, icon: TopicIcon.fromKey(name)),
    ],
    stories: stories
        .map((StoryCardResponseDto story) => story.toSummary())
        .toList(growable: false),
  );
}

/// `StoryDetailResponse` — `{story, sceneCount, childRole, intro}`.
class StoryDetailResponseDto {
  const StoryDetailResponseDto({
    required this.story,
    required this.sceneCount,
    required this.childRole,
    required this.intro,
  });

  factory StoryDetailResponseDto.fromJson(Map<String, dynamic> json) =>
      StoryDetailResponseDto(
        story: StoryCardResponseDto.fromJson(
          json['story'] as Map<String, dynamic>? ?? <String, dynamic>{},
        ),
        sceneCount: (json['sceneCount'] as num?)?.toInt() ?? 0,
        childRole: json['childRole'] as String? ?? '',
        intro: json['intro'] as String? ?? '',
      );

  final StoryCardResponseDto story;

  /// 엔티티가 아직 안 쓰지만(장면 진행은 세션 쪽 값), 보존해 둡니다.
  final int sceneCount;
  final String childRole;
  final String intro;

  /// **서버 `StoryDetailResponse` 는 역할 설명·상황문·도입 음성을 담지
  /// 않습니다.** 기존 [StoryDetail] 은 더미 시절 필드라 그보다 촘촘합니다.
  /// - `situationText` 는 근사치로 `story.summary` 를 재사용합니다.
  /// - `role.description` 은 서버에 대응 필드가 없어 빈 문자열입니다 —
  ///   화면에 빈 줄로 보일 수 있어 기획 확인이 필요합니다.
  /// - `introAudio` 는 서버가 안 내려줘 `null` 입니다(TTS 는 아직 501).
  StoryDetail toEntity() => StoryDetail(
    storyId: story.id,
    title: story.title,
    coverImage: story.imageUrl,
    estimatedMinutes: story.estimatedMinutes,
    difficulty: story.difficulty,
    topics: story.topics,
    introText: intro,
    situationText: story.summary,
    role: StoryRole(name: childRole, description: ''),
  );
}
