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

  /// 후속 자유 대화 — 인물 고르기 (템플릿). 이동할 때는 [freeTalkOf] 를 쓰세요.
  ///
  /// `/stories/:storyId` 아래 중첩하지 않습니다. 이야기 완료 화면에서 `go` 로
  /// 들어오는데, 중첩하면 go_router 가 부모(이야기 상세)까지 함께 세워
  /// 보이지도 않는 화면이 서버를 한 번 더 부릅니다.
  static const String freeTalkPath = '/free-talk/:storyId';

  /// 후속 자유 대화 — 대화 화면 (템플릿). 이동할 때는 [freeTalkChatOf] 를 쓰세요.
  static const String freeTalkChatPath = '/free-talk/:storyId/:characterId';

  /// 내 행성
  static const String planet = '/planet';

  /// 단어장
  static const String words = '/words';

  /// 예문 따라 말하기 (템플릿). 이동할 때는 [wordPracticeOf] 를 쓰세요.
  static const String wordPracticePath = '/words/:wordId/practice';

  /// 마이페이지
  static const String myPage = '/mypage';

  /// 보호자 리포트 목록
  static const String report = '/mypage/report';

  /// 보호자 리포트 상세 (템플릿). 이동할 때는 [reportDetailOf] 를 쓰세요.
  static const String reportDetailPath = '/mypage/report/:sessionId';

  /// [path] 가 보호자 리포트 영역인가. **목록과 상세를 한 영역으로 봅니다** -
  /// 둘을 오갈 때마다 보호자 확인을 다시 물으면 아무도 안 씁니다.
  ///
  /// `startsWith(report)` 만으로 보면 `/mypage/reports-2026` 같은 경로가
  /// 딸려 들어옵니다. 정확히 그 경로이거나 그 아래여야 합니다.
  static bool isReportArea(String path) =>
      path == report || path.startsWith('$report/');

  /// 설정
  static const String settings = '/settings';

  /// 공지사항 목록. 설정 > 안내에서 들어옵니다.
  static const String notices = '/notices';

  /// 공지 상세 (템플릿). 이동할 때는 [noticeDetailOf] 를 쓰세요.
  static const String noticeDetailPath = '/notices/:noticeId';

  /// 이용 안내.
  static const String guides = '/guides';

  /// 고객센터 — 내 문의 목록.
  ///
  /// **관리자 콘솔이 답변 알림에 `/support/{inquiryId}` 를 실어 보냅니다.**
  /// 이 경로를 바꾸면 이미 나간 알림이 갈 곳을 잃습니다.
  static const String support = '/support';

  /// 문의 작성.
  static const String inquiryNew = '/support/new';

  /// 문의 상세 (템플릿). 이동할 때는 [inquiryDetailOf] 를 쓰세요.
  static const String inquiryDetailPath = '/support/:inquiryId';

  /// 알림함.
  static const String notifications = '/notifications';

  /// 보호자 인증 — 로그인·회원가입·약관 동의를 한 화면에서 처리합니다.
  static const String auth = '/auth';

  /// 로그인 화면의 사용자 친화적 주소. 기존 `/auth`도 호환을 위해 유지합니다.
  static const String login = '/login';

  /// 보호자 가입 이메일 찾기.
  static const String findId = '/auth/find-id';

  /// 보호자 비밀번호 재설정.
  static const String findPassword = '/auth/find-password';

  /// 이메일 링크에서 새 비밀번호를 입력하는 화면.
  static const String resetPassword = '/auth/reset-password';

  /// 로그인은 됐는데 아이 프로필이 없는 계정이 갈 곳.
  ///
  /// 스텝을 별도 라우트로 쪼개지 않으려고 쿼리 파라미터로 둡니다.
  /// (`/auth/child` 같은 주소가 생기면 로그인 안 된 채로 북마크됩니다)
  static const String authChildStep = '/auth?$stepParam=$childStepValue';

  /// `/auth` 의 진입 스텝을 지정하는 쿼리 파라미터.
  static const String stepParam = 'step';
  static const String childStepValue = 'child';

  /// 경로 파라미터 이름. `state.pathParameters[AppRoutes.storyIdParam]`
  static const String storyIdParam = 'storyId';
  static const String sessionIdParam = 'sessionId';
  static const String characterIdParam = 'characterId';
  static const String noticeIdParam = 'noticeId';
  static const String inquiryIdParam = 'inquiryId';
  static const String wordIdParam = 'wordId';

  static String storyDetailOf(String storyId) => '/stories/$storyId';

  /// 재생 화면 주소.
  ///
  /// [totalScenes] 는 상단 진행바가 "전체 몇 장면 중 몇 번째"를 그리는 데
  /// 쓰는 값입니다. 세션 API 가 총 장면 수를 안 내려줘서(홈의
  /// `inProgressSession.totalScenes` · 이야기 상세의 `sceneCount` 에만 있습니다)
  /// 화면을 여는 쪽이 실어 보냅니다. `extra` 대신 쿼리 파라미터인 이유는
  /// 새로고침·딥링크로 들어와도 값이 살아남기 때문입니다.
  static String playOf(String sessionId, {int? totalScenes}) =>
      totalScenes == null
      ? '/play/$sessionId'
      : '/play/$sessionId?$totalScenesParam=$totalScenes';

  /// [playOf] 가 싣는 쿼리 파라미터 이름.
  static const String totalScenesParam = 'totalScenes';

  /// 말하기 후 활동 주소.
  ///
  /// [storyId] · [characterName] 은 완료 화면의 "○○와 더 이야기하기" 진입점이
  /// 쓰는 값입니다. 활동 API 는 세션만 알고 이야기·인물을 안 내려줘서,
  /// 화면을 여는 재생 화면이 실어 보냅니다. `extra` 가 아니라 쿼리
  /// 파라미터인 이유는 [playOf] 와 같습니다 - 새로고침·딥링크로 들어와도
  /// 값이 살아남습니다. 없으면 진입점을 그리지 않습니다.
  static String playRecapOf(
    String sessionId, {
    String? storyId,
    String? characterName,
  }) {
    final Map<String, String> query = <String, String>{
      if (storyId != null && storyId.isNotEmpty) storyIdParam: storyId,
      if (characterName != null && characterName.isNotEmpty)
        characterNameParam: characterName,
    };
    final String path = '/play/$sessionId/recap';
    if (query.isEmpty) return path;
    return Uri(path: path, queryParameters: query).toString();
  }

  /// [playRecapOf] 가 싣는 인물 이름 쿼리 파라미터.
  static const String characterNameParam = 'characterName';

  static String freeTalkOf(String storyId) => '/free-talk/$storyId';

  static String freeTalkChatOf(String storyId, String characterId) =>
      '/free-talk/$storyId/$characterId';

  static String wordPracticeOf(String wordId) => '/words/$wordId/practice';

  static String reportDetailOf(String sessionId) => '/mypage/report/$sessionId';

  static String noticeDetailOf(String noticeId) => '/notices/$noticeId';

  static String inquiryDetailOf(String inquiryId) => '/support/$inquiryId';
}
