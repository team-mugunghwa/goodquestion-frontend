// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_summary_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HomeSummaryDto _$HomeSummaryDtoFromJson(Map<String, dynamic> json) =>
    HomeSummaryDto(
      recommendedStories:
          (json['recommendedStories'] as List<dynamic>?)
              ?.map(
                (e) => RecommendedStoryDto.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      planet: PlanetSummaryDto.fromJson(json['planet'] as Map<String, dynamic>),
      child: json['child'] == null
          ? null
          : ChildProfileDto.fromJson(json['child'] as Map<String, dynamic>),
      inProgressSession: json['inProgressSession'] == null
          ? null
          : InProgressSessionDto.fromJson(
              json['inProgressSession'] as Map<String, dynamic>,
            ),
    );

ChildProfileDto _$ChildProfileDtoFromJson(Map<String, dynamic> json) =>
    ChildProfileDto(
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
    );

InProgressSessionDto _$InProgressSessionDtoFromJson(
  Map<String, dynamic> json,
) => InProgressSessionDto(
  sessionId: (json['sessionId'] as num).toInt(),
  storyTitle: json['storyTitle'] as String,
  lastCompletedScene: (json['lastCompletedScene'] as num).toInt(),
  totalScenes: (json['totalScenes'] as num).toInt(),
  storyImage: json['storyImage'] as String?,
);

RecommendedStoryDto _$RecommendedStoryDtoFromJson(Map<String, dynamic> json) =>
    RecommendedStoryDto(
      storyId: (json['storyId'] as num).toInt(),
      title: json['title'] as String,
      estimatedMinutes: (json['estimatedMinutes'] as num).toInt(),
      topicTag: json['topicTag'] as String,
      image: json['image'] as String?,
    );

PlanetSummaryDto _$PlanetSummaryDtoFromJson(Map<String, dynamic> json) =>
    PlanetSummaryDto(
      stardustBalance: (json['stardustBalance'] as num).toInt(),
      thumbnailImage: json['thumbnailImage'] as String?,
    );
