/// 현재 선택된 아이.
///
/// **순수 Dart 입니다.** `fromJson` 을 여기 두지 마세요 —
/// JSON 변환은 `data/dtos/home_summary_dto.dart` 가 담당합니다.
class ChildProfile {
  const ChildProfile({required this.name, this.avatar});

  /// 아이가 홈에서 자기 이름을 확인하는 유일한 자리.
  final String name;

  /// 아바타 이미지 경로. 아직 고르지 않았으면 `null` 이고,
  /// 화면은 이름 첫 글자로 대체합니다.
  final String? avatar;
}
