/// 이야기 상세가 보여 주는 것 전부. (PRD F-03 의 story 엔티티와 1:1)
class StoryDetail {
  const StoryDetail({
    required this.storyId,
    required this.title,
    required this.estimatedMinutes,
    required this.difficulty,
    required this.topics,
    required this.introText,
    required this.situationText,
    required this.role,
    this.sceneCount = 0,
    this.coverImage,
    this.introAudio,
  });

  final String storyId;
  final String title;
  final String? coverImage;
  final int estimatedMinutes;

  /// 이 이야기의 전체 장면 수(서버 `StoryDetailResponse.sceneCount`).
  ///
  /// 상세 화면은 안 쓰지만, **시작하기로 넘어가는 재생 화면의 진행바**가
  /// 이 값을 씁니다 - 세션 API 는 총 장면 수를 안 내려줍니다.
  /// 값을 모르면 `0` 입니다. → `AppRoutes.playOf`
  final int sceneCount;

  /// "쉬움" · "보통" — 숫자가 아니라 말입니다. 보호자가 함께 볼 때의 판단 정보.
  final String difficulty;

  final List<String> topics;

  /// 도입문. **글자는 보조**이고 [introAudio] 가 본체입니다.
  final String introText;

  /// 지금 어떤 상황인지 한두 문장.
  final String situationText;

  /// 도입문 + 역할 설명을 읽어 주는 음성.
  final String? introAudio;

  /// 이 화면에서 가장 중요한 정보.
  final StoryRole role;
}

/// 아이가 맡을 역할.
///
/// 별도 카드로 승격한 이유: 아이가 아무 정보 없이 장면에 던져지면 "무슨
/// 역할로 무엇을 말해야 하는지" 몰라 위축됩니다. 완주율에 직결됩니다.
class StoryRole {
  const StoryRole({
    required this.name,
    required this.description,
    this.characterImage,
  });

  /// "며느리의 친구"
  final String name;

  /// "며느리를 도와서 고민을 들어주게 될 거야."
  final String description;

  final String? characterImage;
}
