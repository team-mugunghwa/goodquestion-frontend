/// 홈의 행성 위젯에 필요한 최소 정보.
///
/// 위젯은 **보상 루프를 상기시키는 장치**이지 놀이 진입 유도가 아닙니다.
/// 그래서 잔액과 썸네일만 있고 행성 조작에 필요한 값은 담지 않습니다.
/// (PRD F-08 "말하기보다 재미있어지지 않는다")
class PlanetSummary {
  const PlanetSummary({required this.stardustBalance, this.thumbnailImage});

  /// 별가루 잔액. 상단 바 뱃지와 같은 값입니다.
  final int stardustBalance;

  /// 아이템이 배치된 내 행성의 미니 썸네일.
  /// `null` 이면 화면이 브랜드 그라디언트로 대체합니다.
  final String? thumbnailImage;
}
