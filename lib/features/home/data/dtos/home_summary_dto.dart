import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/child_profile.dart';
import '../../domain/entities/home_summary.dart';
import '../../domain/entities/in_progress_session.dart';
import '../../domain/entities/planet_summary.dart';
import '../../domain/entities/recommended_story.dart';

part 'home_summary_dto.g.dart';

/// `GET /home` 응답의 `data` 모양 그대로.
/// 지금은 같은 모양의 더미(`assets/dummy/home.json`)를 읽습니다.
///
/// 이 파일을 고쳤다면 코드 생성을 다시 돌리세요.
/// ```bash
/// dart run build_runner build
/// ```
@JsonSerializable(createToJson: false)
class HomeSummaryDto {
  const HomeSummaryDto({
    required this.recommendedStories,
    required this.planet,
    this.child,
    this.inProgressSession,
  });

  factory HomeSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$HomeSummaryDtoFromJson(json);

  /// 아이 프로필 미등록 계정이면 `null` 로 내려옵니다.
  final ChildProfileDto? child;

  /// 진행 중 세션이 없으면 `null`.
  final InProgressSessionDto? inProgressSession;

  /// 없을 때 `null` 이 아니라 `[]` 로 내려주기로 했습니다. (`docs/API.md` 2장)
  @JsonKey(defaultValue: <RecommendedStoryDto>[])
  final List<RecommendedStoryDto> recommendedStories;

  final PlanetSummaryDto planet;

  HomeSummary toEntity() => HomeSummary(
    child: child?.toEntity(),
    inProgressSession: inProgressSession?.toEntity(),
    recommendedStories: recommendedStories
        .map((RecommendedStoryDto dto) => dto.toEntity())
        .toList(growable: false),
    planet: planet.toEntity(),
  );
}

@JsonSerializable(createToJson: false)
class ChildProfileDto {
  const ChildProfileDto({required this.name, this.avatar});

  factory ChildProfileDto.fromJson(Map<String, dynamic> json) =>
      _$ChildProfileDtoFromJson(json);

  final String name;
  final String? avatar;

  ChildProfile toEntity() => ChildProfile(name: name, avatar: avatar);
}

@JsonSerializable(createToJson: false)
class InProgressSessionDto {
  const InProgressSessionDto({
    required this.sessionId,
    required this.storyTitle,
    required this.lastCompletedScene,
    required this.totalScenes,
    this.storyImage,
  });

  factory InProgressSessionDto.fromJson(Map<String, dynamic> json) =>
      _$InProgressSessionDtoFromJson(json);

  final int sessionId;
  final String storyTitle;
  final String? storyImage;
  final int lastCompletedScene;
  final int totalScenes;

  /// 더미는 여전히 숫자 id 를 씁니다. 엔티티는 서버 UUID 에 맞춰 String 이라
  /// 여기서만 변환합니다 — 더미 JSON 은 손대지 않습니다.
  InProgressSession toEntity() => InProgressSession(
    sessionId: sessionId.toString(),
    storyTitle: storyTitle,
    storyImage: storyImage,
    lastCompletedScene: lastCompletedScene,
    totalScenes: totalScenes,
  );
}

@JsonSerializable(createToJson: false)
class RecommendedStoryDto {
  const RecommendedStoryDto({
    required this.storyId,
    required this.title,
    required this.estimatedMinutes,
    required this.topicTag,
    this.image,
  });

  factory RecommendedStoryDto.fromJson(Map<String, dynamic> json) =>
      _$RecommendedStoryDtoFromJson(json);

  final int storyId;
  final String title;
  final String? image;
  final int estimatedMinutes;
  final String topicTag;

  /// [InProgressSessionDto.toEntity] 와 같은 이유로 여기서만 String 변환합니다.
  RecommendedStory toEntity() => RecommendedStory(
    storyId: storyId.toString(),
    title: title,
    image: image,
    estimatedMinutes: estimatedMinutes,
    topicTag: topicTag,
  );
}

@JsonSerializable(createToJson: false)
class PlanetSummaryDto {
  const PlanetSummaryDto({required this.stardustBalance, this.thumbnailImage});

  factory PlanetSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$PlanetSummaryDtoFromJson(json);

  final int stardustBalance;
  final String? thumbnailImage;

  PlanetSummary toEntity() => PlanetSummary(
    stardustBalance: stardustBalance,
    thumbnailImage: thumbnailImage,
  );
}
