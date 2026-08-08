/// 앱의 모든 경로를 한 곳에 모아 둔 곳.
///
/// 화면에서 이동할 때 문자열을 직접 쓰지 마세요. 오타가 나도 컴파일러가
/// 잡아 주지 못하고, 경로가 바뀌면 전부 찾아 고쳐야 합니다.
///
/// ```dart
/// context.go(AppRoutes.stories);              // 파라미터 없는 경로
/// context.go(AppRoutes.storyDetailOf('12'));  // 파라미터 있는 경로
/// ```
///
/// `*Path` 상수는 go_router 에 등록할 때 쓰는 **템플릿**(`:storyId` 포함)이고,
/// `*Of()` 는 실제 이동에 쓰는 **완성된 경로**입니다. 둘을 헷갈리지 마세요.
abstract final class AppRoutes {
  /// 홈 — 이어하기·추천 이야기·행성 위젯
  static const String home = '/';

  /// 이야기 목록
  static const String stories = '/stories';

  /// 이야기 상세 (템플릿). 이동할 때는 [storyDetailOf] 를 쓰세요.
  static const String storyDetailPath = '/stories/:storyId';

  /// 장면 진행 (템플릿). 이동할 때는 [playOf] 를 쓰세요.
  static const String playPath = '/play/:sessionId';

  /// 말하기 후 활동 (템플릿). 이동할 때는 [playRecapOf] 를 쓰세요.
  static const String playRecapPath = '/play/:sessionId/recap';

  /// 내 행성
  static const String planet = '/planet';

  /// 단어장
  static const String words = '/words';

  /// 마이페이지
  static const String myPage = '/mypage';

  /// 보호자 리포트 목록
  static const String report = '/mypage/report';

  /// 보호자 리포트 상세 (템플릿). 이동할 때는 [reportDetailOf] 를 쓰세요.
  static const String reportDetailPath = '/mypage/report/:sessionId';

  /// 설정
  static const String settings = '/mypage/settings';

  /// 보호자 인증 — 로그인·회원가입·약관 동의를 한 화면에서 처리합니다.
  static const String auth = '/auth';

  /// 경로 파라미터 이름. `state.pathParameters[AppRoutes.storyIdParam]`
  static const String storyIdParam = 'storyId';
  static const String sessionIdParam = 'sessionId';

  static String storyDetailOf(String storyId) => '/stories/$storyId';

  static String playOf(String sessionId) => '/play/$sessionId';

  static String playRecapOf(String sessionId) => '/play/$sessionId/recap';

  static String reportDetailOf(String sessionId) => '/mypage/report/$sessionId';
}
