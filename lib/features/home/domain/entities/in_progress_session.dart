/// 진행 중인 이야기 세션 (`status = in_progress` 중 가장 최근 1건).
///
/// 홈의 성패는 "이어하기의 시각적 우선순위"입니다. 이 값이 있으면 화면에서
/// **가장 큰 면적**을 이어하기 카드에 줍니다.
class InProgressSession {
  const InProgressSession({
    required this.sessionId,
    required this.storyTitle,
    required this.lastCompletedScene,
    required this.totalScenes,
    this.storyImage,
  });

  final int sessionId;
  final String storyTitle;

  /// 이야기 대표 이미지. `null` 이면 화면이 브랜드 그라디언트로 대체합니다.
  final String? storyImage;

  /// 마지막으로 **완료한** 장면 번호. 재개는 이 다음 장면부터입니다.
  final int lastCompletedScene;

  final int totalScenes;

  /// 0.0 ~ 1.0. 장면 수가 0 으로 내려와도 나눗셈이 깨지지 않게 막습니다.
  double get progress =>
      totalScenes <= 0 ? 0 : (lastCompletedScene / totalScenes).clamp(0.0, 1.0);
}
