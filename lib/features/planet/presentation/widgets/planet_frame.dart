/// 행성 웹앱을 화면에 심는 위젯의 플랫폼 분기.
///
/// 행성은 3D(WebGL) 웹앱이라 **웹에서만** iframe 으로 심을 수 있습니다.
/// 네이티브(안드로이드/iOS)는 웹뷰 패키지를 붙이기 전까지 안내 화면을 냅니다.
/// 두 구현의 생성자 시그니처는 반드시 같아야 합니다.
library;

export 'planet_frame_stub.dart'
    if (dart.library.js_interop) 'planet_frame_web.dart';
