/// 에셋 경로 상수.
///
/// 위젯에 `'assets/images/logo.png'` 같은 문자열을 직접 쓰지 마세요.
/// 오타가 나면 컴파일 단계에서 못 잡고 **런타임에 화면이 깨집니다.**
/// 파일을 옮길 때도 여기 한 줄만 고치면 됩니다.
abstract final class AppAssets {
  static const String _images = 'assets/images';

  /// 로고 전체 (Q마크 + 워드마크). 1024×366, 배경 투명.
  static const String logo = '$_images/logo.png';

  /// Q마크만. 512×512, 배경 투명. 앱 아이콘·스플래시·좁은 화면용.
  static const String logoMark = '$_images/logo_mark.png';
}
