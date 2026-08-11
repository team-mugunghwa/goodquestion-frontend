/// 에셋 경로 상수.
///
/// 위젯에 `'assets/images/logo.png'` 같은 문자열을 직접 쓰지 마세요.
/// 오타가 나면 컴파일 단계에서 못 잡고 **런타임에 화면이 깨집니다.**
/// 파일을 옮길 때도 여기 한 줄만 고치면 됩니다.
abstract final class AppAssets {
  static const String _images = 'assets/images';

  /// 화면별 더미 JSON. 서버가 준비되기 전까지 화면 하나당 파일 하나입니다.
  /// → `docs/DECISIONS.md` 015
  static const String _dummy = 'assets/dummy';

  /// 로고 전체 (Q마크 + 워드마크). 1024×366, 배경 투명.
  static const String logo = '$_images/logo.png';

  /// Q마크만. 512×512, 배경 투명. 앱 아이콘·스플래시·좁은 화면용.
  static const String logoMark = '$_images/logo_mark.png';

  static const String googleLogo = 'assets/icons/google_g.svg';
  static const String kakaoLogo = 'assets/icons/kakao_bubble.svg';

  /// 홈 화면 더미. 서버 `GET /home` 응답의 `data` 와 1:1 입니다.
  static const String homeDummy = '$_dummy/home.json';

  /// 이야기 목록 더미. 주제 필터 목록도 여기 함께 들어 있습니다.
  static const String storiesListDummy = '$_dummy/stories_list.json';

  /// 이야기 상세 더미. **storyId 를 키로 하는 맵**입니다.
  ///
  /// 화면마다 파일 하나가 원칙이지만, 상세는 이야기 수만큼 파일이 늘어나고
  /// 목록의 카드를 눌렀을 때 절반이 "찾을 수 없어요"로 빠지면 시연이 안 됩니다.
  /// 서버에서는 `GET /stories/{id}` 하나로 바뀝니다.
  static const String storyDetailsDummy = '$_dummy/story_details.json';

  /// 단어장 더미. 이야기별 그룹 + 단어 목록.
  static const String wordsDummy = '$_dummy/words_screen.json';

  /// 마이페이지 더미. 현재 아이 · 활동 요약 · 리포트 배지.
  static const String myPageDummy = '$_dummy/mypage.json';

  /// 보호자 리포트 목록 더미.
  static const String reportListDummy = '$_dummy/report_list.json';

  /// 보호자 리포트 상세 더미. **sessionId 를 키로 하는 맵**입니다.
  /// (이유는 [storyDetailsDummy] 와 같습니다)
  static const String reportDetailsDummy = '$_dummy/report_details.json';

  /// 설정 더미.
  static const String settingsDummy = '$_dummy/settings.json';

  /// 보호자 인증 더미. 로그인 수단 · 동의 항목 · 나이 선택지 · 목업 계정.
  static const String authDummy = '$_dummy/auth_screen.json';
}
