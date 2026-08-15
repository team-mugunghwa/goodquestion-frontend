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

  /// 재생 화면 진행바가 "전체 몇 장면 중 몇 번째"를 그리는 데 씁니다 -
  /// 세션 API 는 총 장면 수를 안 내려줍니다. → `AppRoutes.playOf`
  final int sceneCount;

  /// 아이가 맡을 역할 **이름 하나**. (`stories.child_role`, varchar 50)
  final String childRole;

  /// 도입과 상황이 **합쳐진** 한 덩어리. (`stories.intro`)
  final String intro;

  /// 상세 화면이 쓰는 건 이게 전부입니다.
  ///
  /// 기획(`MVP_요건.md`)의 요건은 "도입 · 상황 · 아이 역할" 한 줄이고,
  /// DB 설계(`데이터베이스_설계.md` §3.1)가 그걸 `intro`(도입+상황) ·
  /// `child_role` · `summary`(3인칭 소개) 세 필드로 받았습니다. **역할
  /// 설명문이나 별도 상황문 같은 필드는 서버에도 기획에도 없습니다** —
  /// 없는 걸 빈 문자열로 만들어 넘기지 마세요. 화면에 빈 줄로 보입니다.
  ///
  /// - `childRole`·`intro` 는 **빈 문자열로 옵니다**(시드 미완). 화면이
  ///   해당 섹션을 통째로 안 그리는 것으로 대응합니다.
  /// - `introAudio` 는 서버가 안 내려줘 `null` 입니다(TTS 는 아직 501).
  ///   TTS 가 붙을 자리라 엔티티 필드는 남겨 둡니다.
  StoryDetail toEntity() => StoryDetail(
    storyId: story.id,
    title: story.title,
    coverImage: story.imageUrl,
    estimatedMinutes: story.estimatedMinutes,
    difficulty: story.difficulty,
    topics: story.topics,
    sceneCount: sceneCount,
    summary: story.summary,
    introText: intro,
    role: StoryRole(name: childRole),
  );
}
