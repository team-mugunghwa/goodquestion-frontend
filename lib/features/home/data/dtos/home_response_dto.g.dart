// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_response_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HomeResponseDto _$HomeResponseDtoFromJson(Map<String, dynamic> json) =>
    HomeResponseDto(
      recommendedStories:
          (json['recommendedStories'] as List<dynamic>?)
              ?.map(
                (e) => StoryCardResponseDto.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      planetWidget: PlanetWidgetResponseDto.fromJson(
        json['planetWidget'] as Map<String, dynamic>,
      ),
      inProgressSession: json['inProgressSession'] == null
          ? null
          : SessionSummaryResponseDto.fromJson(
              json['inProgressSession'] as Map<String, dynamic>,
            ),
    );

SessionSummaryResponseDto _$SessionSummaryResponseDtoFromJson(
  Map<String, dynamic> json,
) => SessionSummaryResponseDto(
  sessionId: json['sessionId'] as String,
  storyId: json['storyId'] as String,
  storyTitle: json['storyTitle'] as String,
  status: json['status'] as String,
  currentSceneOrder: (json['currentSceneOrder'] as num).toInt(),
  totalScenes: (json['totalScenes'] as num).toInt(),
  storyImageUrl: json['storyImageUrl'] as String?,
  lastActivityAt: json['lastActivityAt'] as String?,
);

StoryCardResponseDto _$StoryCardResponseDtoFromJson(
  Map<String, dynamic> json,
) => StoryCardResponseDto(
  id: json['id'] as String,
  title: json['title'] as String,
  summary: json['summary'] as String,
  difficulty: json['difficulty'] as String,
  estimatedMinutes: (json['estimatedMinutes'] as num).toInt(),
  topics:
      (json['topics'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
  imageUrl: json['imageUrl'] as String?,
);

PlanetWidgetResponseDto _$PlanetWidgetResponseDtoFromJson(
  Map<String, dynamic> json,
) => PlanetWidgetResponseDto(
  stardustBalance: (json['stardustBalance'] as num).toInt(),
  placedCount: (json['placedCount'] as num).toInt(),
  hasUnacknowledged: json['hasUnacknowledged'] as bool,
);
