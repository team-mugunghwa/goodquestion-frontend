/// 이야기 상세가 보여 주는 것 전부.
///
/// 서버 `GET /api/stories/{storyId}` 의 `StoryDetailResponse` 와 1:1 입니다.
/// 필드를 늘리기 전에 **서버가 그걸 내려주는지** 먼저 보세요 — 예전에
/// 더미로 화면을 만들던 시절 지어낸 필드(역할 설명, 별도 상황문)가 오래
/// 남아서 화면에 빈 줄로 보였습니다.
class StoryDetail {
  const StoryDetail({
    required this.storyId,
    required this.title,
    required this.estimatedMinutes,
    required this.difficulty,
    required this.topics,
    required this.summary,
    required this.introText,
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

  /// 목록 카드와 상세가 함께 쓰는 **3인칭 소개**(서버 `story.summary`).
  ///
  /// 아이에게 읽어 주는 글이 아니라 **보호자가 고를 때 보는 설명**입니다.
  /// 그래서 도입 카드가 아니라 메타 칩 아래에 작게 붙습니다.
  final String summary;

  /// 도입/상황 소개 한 덩어리(서버 `intro`).
  ///
  /// 기획의 "이야기 도입"과 "상황"은 서버에서 **한 필드로 합쳐져** 있습니다.
  /// (`데이터베이스_설계.md` §3.1 `stories.intro` = "상세 화면 도입/상황 소개")
  /// 시드가 안 채워진 이야기는 **빈 문자열**로 옵니다.
  final String introText;

  /// 도입문을 읽어 주는 음성.
  ///
  /// TTS 가 붙을 자리입니다. 서버는 아직 안 내려주므로 실제로는 늘 `null`
  /// 이고, 그동안 화면은 "들려줘" 버튼을 그리지 않습니다.
  final String? introAudio;

  /// 이 화면에서 가장 중요한 정보. 이름이 비면 섹션을 통째로 안 그립니다.
  final StoryRole role;
}

/// 아이가 맡을 역할.
///
/// 별도 카드로 승격한 이유: 아이가 아무 정보 없이 장면에 던져지면 "무슨
/// 역할로 무엇을 말해야 하는지" 몰라 위축됩니다. 완주율에 직결됩니다.
class StoryRole {
  const StoryRole({required this.name, this.characterImage});

  /// "며느리의 친구" — 서버 `childRole` (varchar 50).
  ///
  /// **서버가 주는 역할 정보는 이 이름 하나가 전부입니다.** 역할 설명문은
  /// 기획(`MVP_요건.md`)에도 API 에도 없습니다. 카드는 이름만으로 성립하게
  /// 그립니다. → `role_card.dart`
  ///
  /// 시드가 안 채워진 이야기는 빈 문자열로 옵니다.
  final String name;

  /// 역할 캐릭터 그림(로컬 에셋 경로).
  ///
  /// 서버 필드가 아니라 **앞으로 붙일 에셋 자리**입니다. 지금은 늘 `null`
  /// 이라 카드가 로고 마크로 대신 그립니다.
  final String? characterImage;
}
