import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/in_progress_session.dart';
import '../../domain/entities/planet_summary.dart';
import '../../domain/entities/recommended_story.dart';

part 'home_response_dto.g.dart';

/// `GET /children/{childId}/home` 응답. → `api_spec.md` §3.4
///
/// `HomeResponse` 에는 아이 프로필이 없습니다. 선택된 아이는
/// `HomeRepositoryImpl` 이 `ChildProfileRepository` 에서 합성합니다.
@JsonSerializable(createToJson: false)
class HomeResponseDto {
  const HomeResponseDto({
    required this.recommendedStories,
    required this.planetWidget,
    this.inProgressSession,
  });

  factory HomeResponseDto.fromJson(Map<String, dynamic> json) =>
      _$HomeResponseDtoFromJson(json);

  /// 진행 중 세션이 없으면 `null`.
  final SessionSummaryResponseDto? inProgressSession;

  /// 없으면 `[]` — PUBLISHED 최신 3개.
  @JsonKey(defaultValue: <StoryCardResponseDto>[])
  final List<StoryCardResponseDto> recommendedStories;

  final PlanetWidgetResponseDto planetWidget;
}

/// `SessionSummaryResponse` — 홈 이어하기 카드.
@JsonSerializable(createToJson: false)
class SessionSummaryResponseDto {
  const SessionSummaryResponseDto({
    required this.sessionId,
    required this.storyId,
    required this.storyTitle,
    required this.status,
    required this.currentSceneOrder,
    required this.totalScenes,
    this.storyImageUrl,
    this.lastActivityAt,
  });

  factory SessionSummaryResponseDto.fromJson(Map<String, dynamic> json) =>
      _$SessionSummaryResponseDtoFromJson(json);

  final String sessionId;
  final String storyId;
  final String storyTitle;
  final String? storyImageUrl;

  /// `SessionStatus` 문자열. 엔티티가 아직 쓰지 않아도 값은 보존해 둡니다.
  final String status;
  final int currentSceneOrder;
  final int totalScenes;
  final String? lastActivityAt;

  /// `currentSceneOrder` 는 **지금 보고 있는** 장면 순서라 완료한 장면 수는
  /// 그 하나 앞입니다. 음수·초과를 막아 진행률이 0~1 밖으로 안 나가게 합니다.
  InProgressSession toEntity() => InProgressSession(
    sessionId: sessionId,
    storyTitle: storyTitle,
    storyImage: storyImageUrl,
    lastCompletedScene: (currentSceneOrder - 1).clamp(0, totalScenes),
    totalScenes: totalScenes,
  );
}

/// `StoryCardResponse` — 목록·홈 추천이 공유.
@JsonSerializable(createToJson: false)
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
      _$StoryCardResponseDtoFromJson(json);

  final String id;
  final String title;
  final String summary;
  final String difficulty;
  final int estimatedMinutes;
  final String? imageUrl;

  @JsonKey(defaultValue: <String>[])
  final List<String> topics;

  /// 홈의 `topicTag` 는 한 단어입니다. 여러 주제 중 첫 번째만 씁니다.
  RecommendedStory toEntity() => RecommendedStory(
    storyId: id,
    title: title,
    image: imageUrl,
    estimatedMinutes: estimatedMinutes,
    topicTag: topics.isEmpty ? '' : topics.first,
  );
}

/// `HomeResponse.planetWidget` — `{stardustBalance, placedCount, hasUnacknowledged}`.
@JsonSerializable(createToJson: false)
class PlanetWidgetResponseDto {
  const PlanetWidgetResponseDto({
    required this.stardustBalance,
    required this.placedCount,
    required this.hasUnacknowledged,
  });

  factory PlanetWidgetResponseDto.fromJson(Map<String, dynamic> json) =>
      _$PlanetWidgetResponseDtoFromJson(json);

  final int stardustBalance;

  /// 엔티티가 아직 안 쓰지만, 행성 화면이 이걸 필요로 할 때를 대비해 보존합니다.
  final int placedCount;

  /// true면 행성 진입 전 연출 예고 점을 표시합니다. (행성 화면 몫이라 아직 미사용)
  final bool hasUnacknowledged;

  PlanetSummary toEntity() => PlanetSummary(stardustBalance: stardustBalance);
}
