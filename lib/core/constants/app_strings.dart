/// 사용자에게 보이는 문구.
///
/// 위젯 안에 한글 문자열을 직접 쓰지 마세요. (`docs/CONVENTIONS.md` 5장)
/// 문구는 디자인만큼 화면의 인상을 정하기 때문에, 한 곳에 모아 두고
/// **톤을 통째로 검토**할 수 있어야 합니다. (`docs/DESIGN_SYSTEM.md` 11장)
///
/// ## 규칙
///
/// - 공통 문구는 [AppStrings], 화면 전용 문구는 화면별 클래스(`HomeStrings` 등)
/// - 아이에게 보이는 문구는 **캐릭터가 말하듯이**. 시스템이 말하지 않습니다
/// - 실패를 실패라고 부르지 않습니다 — "인식하지 못했어요" ❌ / "잘 안 들렸어" ✅
/// - 값이 끼어드는 문구는 상수가 아니라 **함수**로 둡니다 ([HomeStrings.sceneProgress])
///
/// 다국어는 MVP 범위 밖입니다. 필요해지면 이 파일이 `l10n` 으로 넘어갑니다.
library;

/// 여러 화면이 함께 쓰는 문구.
abstract final class AppStrings {
  /// 아이 화면의 재시도. "다시 시도"(보호자 톤)와 구분합니다.
  static const String retryKid = '다시 불러오기';

  /// 아이 화면에서 무언가를 불러오지 못했을 때. 아이 탓이 아니라는 톤.
  static const String loadFailedKid = '앗, 지금은 못 가져왔어.\n한 번만 더 해볼까?';

  static const String back = '뒤로';

  /// 보호자 화면의 재시도. 아이 화면은 [retryKid] 를 씁니다.
  static const String retry = '다시 시도';

  /// 보호자 화면의 일반 실패.
  static const String loadFailed = '문제가 발생했습니다.';

  /// 필터의 "전체". 이야기 목록과 단어장이 같은 말을 씁니다.
  static const String filterAll = '전체';

  /// "15분" — 예상 소요 시간. 여러 화면의 칩에 들어갑니다.
  static String minutes(int value) => '$value분';
}

/// 하단 내비게이션 탭 이름. 네 화면이 같은 라벨을 씁니다.
abstract final class NavStrings {
  static const String home = '홈';
  static const String stories = '이야기';
  static const String words = '단어장';
  static const String myPage = '마이';
}

/// 홈(`/`) 전용 문구.
abstract final class HomeStrings {
  // ── 섹션1 상단 바 ──
  static const String profileSemantics = '아이 바꾸기';
  static const String stardust = '별가루';

  // ── 섹션2 이어하기 / 새 이야기 ──
  static const String resume = '이어서 말하기';

  /// "3번째 장면까지 했어요" — 마지막으로 **완료한** 장면 번호입니다.
  static String sceneProgress(int lastCompletedScene) =>
      '$lastCompletedScene번째 장면까지 했어요';

  /// 진행 중인 이야기가 없을 때 섹션2를 대신하는 카드.
  static const String startTitle = '새 이야기를 골라볼까?';
  static const String startAction = '이야기 고르기';

  // ── 섹션3 추천 ──
  static const String recommendedTitle = '새로운 이야기';
  static const String more = '더 보기';

  /// 큐레이션이 비었을 때. 아이 탓도, 고장도 아니라는 톤.
  static const String recommendedEmpty = '새 이야기를 준비하고 있어!';

  /// "15분" — 예상 소요 시간.
  static String minutes(int value) => '$value분';

  // ── 섹션4 행성 위젯 ──
  static const String planetTitle = '내 행성';
  static const String planetAction = '가기';

  // ── 프로필 없음 게이트 (F-01) ──
  static const String profileNeededTitle = '먼저 누가 이야기할지 알려줄래?';
  static const String profileNeededAction = '내 이름 만들기';

  // ── 아이 프로필 전환 모달(모달 6) 호출 지점 ──
  static const String switchChildTitle = '누가 이야기할 거야?';
  static const String close = '닫기';
}

/// 이야기 목록(`/stories`) 전용 문구.
abstract final class StoryListStrings {
  static const String title = '어떤 이야기를 해볼까?';

  /// 고른 주제에 이야기가 없을 때. 아이 탓이 아니라는 톤.
  static const String emptyTopic = '이 주제는 아직 이야기가 없어.\n다른 것도 볼까?';
  static const String showAll = '전체 보기';
}

/// 이야기 상세(`/stories/:storyId`) 전용 문구.
abstract final class StoryDetailStrings {
  /// 도입문·역할 설명을 소리로 듣는 버튼. 이 화면의 음성 우선 원칙의 핵심.
  static const String listen = '들려줘';

  /// 이 화면의 단일 핵심 액션. 세션이 생성되는 유일한 지점입니다.
  static const String start = '시작하기';

  /// "이 이야기에서 너는 ○○이야!"
  static String roleTitle(String roleName) => '이 이야기에서 너는\n"$roleName"야!';

  /// 없는 storyId 로 들어온 경우.
  static const String notFound = '앗, 이 이야기를 찾을 수 없어.';
  static const String goToList = '이야기 고르러 가기';
}

/// 단어장(`/words`) 전용 문구.
abstract final class WordStrings {
  static const String title = '내 단어장';

  /// 총 담은 단어 수. 스크린리더용 풀 문장.
  static String savedCount(int count) => '담은 단어 $count개';

  /// 아직 아무것도 담지 않았을 때. 본체 활동으로 보냅니다.
  static const String empty = '아직 담은 단어가 없어.\n이야기하면서 담아 볼까?';
  static const String goToStories = '이야기 하러 가기';

  /// 이 이야기에서 담은 단어가 없을 때 (필터 결과 0건).
  static const String emptyInStory = '이 이야기에서 담은 단어가 없어.';

  static String listenTo(String word) => '$word 발음 듣기';

  // ── 단어 상세 모달(모달 #2) ──
  static const String meaning = '무슨 뜻이냐면';
  static const String exampleInStory = '이야기에서는 이렇게 나왔어';
  static const String like = '좋아요';
  static const String close = '닫기';
}

/// 마이페이지(`/mypage`) 전용 문구.
///
/// 여기부터는 **보호자 화면**입니다. 아이 화면과 톤이 다릅니다 —
/// 캐릭터가 말하지 않고, 사실을 그대로 적습니다.
abstract final class MyPageStrings {
  static const String title = '마이페이지';

  static String childAge(int age) => '$age살';

  /// 활동 요약. 통계 화면이 아니므로 숫자는 둘까지만.
  static String completedStories(int count) => '완주한 이야기 $count편';
  static String stardust(int count) => '별가루 $count';

  static const String switchChild = '프로필 전환';
  static const String editChild = '프로필 수정';

  static const String guardianMenu = '보호자 메뉴';
  static const String report = '보호자 리포트';

  static const String manageMenu = '관리';
  static const String addChild = '아이 프로필 추가';
  static const String settings = '설정';

  /// 아이 프로필이 0명일 때.
  static const String noChild = '아이 프로필을 만들어 주세요.';
  static const String createChild = '아이 등록하기';

  static const String loadFailed = '정보를 불러오지 못했어요.';

  // ── 보호자 확인 게이트(모달 5) 호출 지점 ──
  static const String gateTitle = '보호자 확인';
  static const String gateBody = '리포트는 보호자만 볼 수 있어요.\n보호자가 맞다면 확인을 눌러 주세요.';
  static const String gateConfirm = '확인';
  static const String gateCancel = '취소';
}

/// 보호자 리포트 목록(`/mypage/report`) 전용 문구.
abstract final class ReportListStrings {
  static const String title = '보호자 리포트';

  static String childLabel(String name) => '아이: $name';

  /// "리포트 4개 · 새 리포트 1개"
  static String summary(int total, int unread) =>
      '리포트 $total개 · 새 리포트 $unread개';

  /// 미열람 배지.
  static const String badgeNew = 'NEW';

  /// "2회차" — 같은 이야기를 여러 번 하면 카드가 쌓이므로 회차가 없으면
  /// 보호자에게 중복으로 보입니다.
  static String playCount(int count) => '$count회차';

  static const String empty = '아직 도착한 리포트가 없어요.\n아이가 이야기를 완주하면 이곳에 도착해요.';
  static const String goToHome = '이야기 보러 가기';

  static const String loadFailed = '리포트를 불러오지 못했어요.';
}

/// 보호자 리포트 상세(`/mypage/report/:sessionId`) 전용 문구.
abstract final class ReportDetailStrings {
  static const String title = '말하기 리포트';

  static const String skills = '역량 분석';
  static const String askedWords = '질문한 어휘';
  static const String evidence = '근거 발화';
  static const String strength = '잘한 점';

  /// 보완할 부분. **권유형으로만** 씁니다 — 단정적 부정 표현 금지. (PRD F-09)
  static const String improvement = '이렇게 해보면 좋아요';

  static const String highlight = '이번 세션의 대표 발화';
  static const String highlightReason = '선정 이유';

  static const String questions = '오늘 아이와 이런 대화를 해보세요';
  static const String copy = '복사';
  static const String copied = '복사했어요';

  static const String goToList = '목록으로';

  /// 완주 직후라 아직 분석이 안 끝난 경우. 빈 화면으로 방치하지 않습니다.
  static const String pending = '리포트를 만들고 있어요.\n잠시 후 다시 확인해 주세요.';

  static const String loadFailed = '리포트를 불러오지 못했어요.';
}

/// 설정(`/mypage/settings`) 전용 문구.
abstract final class SettingsStrings {
  static const String title = '설정';

  static const String notificationGroup = '알림';
  static const String reportNotification = '리포트 도착 알림';
  static const String reportNotificationDesc = '아이가 이야기를 완주하면 알려드려요.';
  static const String marketingConsent = '마케팅 수신 동의';
  static const String marketingOn = '마케팅 수신에 동의했어요.';
  static const String marketingOff = '마케팅 수신 동의를 철회했어요.';

  static const String infoGroup = '안내';
  static const String notice = '공지사항';
  static const String guide = '이용 안내';
  static const String support = '고객센터';

  /// 목업에서는 외부 채널 연결 대신 알림만 띄웁니다.
  static const String supportToast = '고객센터로 연결됩니다. (준비 중)';

  static const String policyGroup = '약관·정책';
  static const String terms = '서비스 이용약관';

  /// 아동 개인정보 동의는 가입 시 **별도로** 받으므로 행도 별도입니다. (F-01)
  static const String childPrivacy = '아동 개인정보 처리방침';
  static const String privacy = '개인정보 처리방침';

  static const String accountGroup = '계정';
  static const String signOut = '로그아웃';
  static const String signOutConfirm = '로그아웃할까요?';
  static const String cancel = '취소';

  static String appVersion(String version) => '앱 버전 $version';

  static const String loadFailed = '설정을 불러오지 못했어요.';

  /// 목업의 문서 뷰. 실제 문서가 들어오면 이 자리를 채웁니다.
  static const String documentPlaceholder = '문서 내용은 준비 중입니다.';
}
