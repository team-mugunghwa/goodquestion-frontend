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
  static const String planet = '행성';
  static const String myPage = '마이';
}

/// 홈(`/`) 전용 문구.
abstract final class HomeStrings {
  // ── 섹션1 상단 바 ──
  /// 인사말 헤더. 이름이 없으면 [greetingNoName] 을 씁니다.
  static String greeting(String name) => '안녕, $name!';
  static const String greetingNoName = '안녕!';
  static const String greetingSub = '오늘은 어떤 이야기를 해볼까?';
  static const String profileSemantics = '아이 바꾸기';
  static const String stardust = '별가루';

  // ── 섹션2 이어하기 / 새 이야기 ──
  static const String resume = '이어서 말하기';

  /// 이어하기 카드 썸네일 위의 상태 뱃지. 버튼(행동)과 달리 "지금 여기"를
  /// 알려 주는 표식이라 문구를 다르게 둡니다.
  static const String resumeBadge = '이어보던 이야기';

  /// "3번째 장면까지 했어요" — 마지막으로 **완료한** 장면 번호입니다.
  static String sceneProgress(int lastCompletedScene) =>
      '$lastCompletedScene번째 장면까지 했어요';

  /// 진행 중인 이야기가 없을 때 섹션2를 대신하는 카드.
  static const String startTitle = '새 이야기를 골라볼까?';
  static const String startAction = '이야기 고르기';

  /// 새 이야기 카드 표지 위의 표식.
  static const String startBadge = '새 이야기';

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

  /// 제목 아래 한 줄. 화면의 일을 아이 말로 알려 줍니다.
  static const String subtitle = '마음에 드는 그림을 골라 봐';

  /// 고른 주제에 이야기가 없을 때. 아이 탓이 아니라는 톤.
  static const String emptyTopic = '이 주제는 아직 이야기가 없어.\n다른 것도 볼까?';
  static const String showAll = '전체 보기';
}

/// 이야기 상세(`/stories/:storyId`) 전용 문구.
abstract final class StoryDetailStrings {
  /// 도입문을 소리로 듣는 버튼. 이 화면의 음성 우선 원칙의 핵심.
  static const String listen = '들려줘';

  /// 이 화면의 단일 핵심 액션. 세션이 생성되는 유일한 지점입니다.
  static const String start = '시작하기';

  /// 역할 카드의 눈길잡이. 주인공은 아랫줄의 이름이라 이 줄은 작게 둡니다.
  static const String roleIntro = '이 이야기에서 너는';

  /// 역할 카드에서 가장 큰 글자. 서버가 주는 역할 정보는 이 이름 하나뿐입니다.
  static String roleName(String name) => '"$name"야!';

  /// 없는 storyId 로 들어온 경우.
  static const String notFound = '앗, 이 이야기를 찾을 수 없어.';
  static const String goToList = '이야기 고르러 가기';
}

/// 이야기 말하기(`/play/:sessionId`) 전용 문구.
///
/// 이 화면에서 아이가 듣는 말은 거의 다 서버가 내려주는 캐릭터 대사입니다.
/// 여기 두는 것은 **화면이 스스로 하는 말**뿐입니다.
abstract final class PlayStrings {
  // ── 말하기 후 활동으로 넘어가는 전환 ──

  /// 전환 화면의 제목. 이 화면에서 가장 큰 글자입니다.
  ///
  /// 다음에 할 일의 **이름을 먼저 대 줍니다** — 화면이 통째로 바뀌는 자리라,
  /// 이름이 없으면 아이는 이야기가 그냥 끝난 줄 압니다.
  ///
  /// 단계 이름([RecapStrings.stepArrange] "순서 맞추기")을 쓰지 않습니다.
  /// 순서 맞추기는 뒤이어 나올 두 단계 중 하나일 뿐이라, 여기서 미리 말하면
  /// 활동 전체가 그것 하나인 줄 압니다. 게다가 다음 화면이 장면 그림을
  /// 순서대로 놓는 활동이라 **무엇을 하는지 미리 말할수록 정답에 가까워집니다.**
  static const String toRecapTitle = '말하기 후 활동';

  /// 이야기가 끝나고 순서 맞추기로 넘어가기 직전, 캐릭터가 하는 마지막 한마디.
  ///
  /// 예고 없이 화면이 갈아 끼워지면 아이는 대화하던 친구가 사라지고 다른 앱으로
  /// 튕긴 것처럼 느낍니다. 그래서 "끝났어"가 아니라 **"같이 …해보자"** 로
  /// 다음 활동에 초대합니다 — 이야기가 끝난 게 아니라 이어진다는 뜻이어야 합니다.
  ///
  /// **소리로 읽어 주지 않습니다.** 지금은 글자로만 보여 줍니다.
  static const String toRecap = '이제 이야기를 같이 정리해보자!';

  /// 전환을 끝내고 활동으로 들어가는 버튼.
  ///
  /// **통과 조건이 아니라 지름길입니다** — 누르지 않아도 몇 초 뒤 저절로
  /// 넘어갑니다. 그래도 버튼을 그리는 이유는, 버튼이 없으면 아무 일도 일어나지
  /// 않는 화면으로 보여서 아이가 넘어가는 방법을 찾아 화면을 더듬기 때문입니다.
  ///
  /// 한 단어로 둡니다. "시작하기"·"활동 시작하기"는 글을 막 배우는 아이에게
  /// 길고, 무엇을 시작하는지는 [toRecapTitle] 이 이미 말해 줍니다.
  static const String toRecapStart = '시작';
}

/// 말하기 후 활동(`/play/:sessionId/recap`) 전용 문구.
///
/// 이 화면은 **아이 화면**입니다. 캐릭터가 말을 걸고, 버튼은 한 단어입니다.
/// 틀린 순서를 "틀렸다"고 부르지 않습니다 — 순서 오답은 실패가 아닙니다. (PRD §6)
abstract final class RecapStrings {
  // ── 상단 바 ──
  static const String stepArrange = '순서 맞추기';
  static const String stepRetell = '다시 말하기';

  /// 스크린리더용. "2단계 중 1단계"
  static String stepOf(int current, int total) => '$total단계 중 $current단계';

  // ── 1단계 순서 맞추기 ──
  /// 캐릭터가 하는 말. 한 화면에 한 가지만 시킵니다.
  static const String arrangeGuide = '아래 그림을 이야기 순서대로 놓아 볼래?';

  /// 순서가 다를 때. 다시 해보자는 말이지 오답 통보가 아닙니다.
  static const String arrangeRetry = '거의 다 왔어! 처음에 무슨 일이 있었는지 볼까?';

  /// 자리를 다 채웠을 때. 다음 행동(확인)을 가리킵니다.
  static const String arrangeReady = '다 놓았네! 이 순서가 맞는지 볼까?';

  static const String check = '확인';

  static String slotEmpty(int order) => '$order번째 자리, 비어 있어요';
  static String slotFilled(int order, String title) => '$order번째 자리, $title';

  // ── 2단계 다시 말하기 ──
  /// 낱말이 과제의 일부임이 첫 문장에서 드러나야 합니다. "그림을 보면서"로만
  /// 시작하면 낱말은 있어도 그만인 참고자료가 됩니다.
  ///
  /// 그래도 **강요는 하지 않습니다** — 낱말을 다 쓰지 않아도 완료할 수 있습니다.
  /// (`docs/DESIGN_SYSTEM.md` — "아이 화면에 실패는 없다")
  static const String retellGuide = '그림 아래 낱말을 넣어서 들려줄래?';
  static const String retellListening = '듣고 있어. 천천히 말해도 괜찮아.';
  static const String retellSpoken = '잘했어! 다 말했으면 알려 줘.';

  static const String speak = '말하기';
  static const String stopSpeaking = '멈추기';

  /// 아직 말하기 전의 말풍선 안내.
  static const String transcriptEmpty = '여기에 네 이야기가 글자로 보여';

  static const String finish = '다 했어';
  static const String saving = '저장 중';

  /// 녹음을 끝내고 글자를 받아 오는 사이.
  static const String retellTranscribing = '무슨 이야기인지 듣고 있어…';

  // ── 마이크·STT 안내 ──
  // 화면을 통째로 에러로 바꾸지 않습니다. 아이는 말하는 중이고, 이 부류는
  // 다시 말하거나 잠시 뒤에 하면 풀립니다. (`play_view.dart` 와 같은 표)
  static const String micDenied = '마이크를 쓰게 해 줄래?';
  static const String micFailed = '마이크를 켜지 못했어. 다시 눌러 볼까?';
  static const String sttEmpty = '잘 못 들었어요. 다시 말해 볼까?';
  static const String sttTooLong = '말이 조금 길었어요. 짧게 말해 볼까?';
  static const String sttUnavailable = '지금은 잘 안 들려요. 잠시 뒤에 다시 말해 볼까?';

  /// 완료 저장이 실패했을 때. **다시 누르면 된다**를 반드시 함께 말합니다 -
  /// 안 그러면 아이가 활동을 처음부터 다시 합니다.
  static String saveFailed(String reason) => '$reason 다시 눌러 볼까?';

  static String sceneOrder(int order, String title) => '$order번째 장면, $title';

  /// 낱말이 붙은 장면. 장면과 낱말을 **한 덩어리**로 읽어 줍니다 — 따로 읽으면
  /// 화면에서 붙여 놓은 뜻("이 장면을 말할 땐 이 말을 쓴다")이 사라집니다.
  static String sceneOrderWithKeyword(
    int order,
    String title,
    String keyword,
  ) => '$order번째 장면, $title, 낱말 $keyword';

  // ── 완료 ──
  static const String completed = '이야기를 멋지게 들려줬어!';

  /// 이번 완주로 받은 별가루. 서버가 지급한 실제 수치입니다.
  static String completedStardust(int earned) => '별가루 $earned개를 받았어!';

  static String completedUnlocked(int count) => '새 아이템 $count개가 열렸어!';

  static const String completedAction = '마치기';
}

/// 단어장(`/words`) 전용 문구.
abstract final class WordStrings {
  static const String title = '내 단어장';

  /// 제목 아래 한 줄. 담은 개수를 자연스러운 문장으로 녹입니다.
  static String subtitle(int count) => '이야기에서 만난 단어 $count개를 다시 만나요';

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

  /// 뜻이 아직 없는 단어. 빈 칸을 두면 고장으로 보입니다.
  static const String meaningMissing = '아직 뜻을 준비하고 있어.';
  static const String exampleInStory = '이야기에서는 이렇게 나왔어';
  static const String exampleInDaily = '평소에는 이렇게 써';
  static const String exampleAdvanced = '조금 어려운 문장에도 도전!';
  static const String like = '좋아요';
  static const String unlike = '좋아요 해제';
  static const String practice = '따라 말하기';
  static const String close = '닫기';
}

/// 예문 따라 말하기(`/words/:wordId/practice`) 전용 문구.
///
/// 아이 화면입니다. 캐릭터가 말을 걸고, 못 알아들은 건 아이 탓이 아닙니다 -
/// "인식 실패" 대신 "잘 안 들렸어"라고 말합니다.
abstract final class SentencePracticeStrings {
  static const String title = '따라 말하기';

  // ── 1단계 예문 고르기 ──
  static const String pickGuide = '어떤 문장을 따라 말해 볼까?';
  static const String typeStory = '이야기 예문';
  static const String typeDaily = '일상 예문';
  static const String typeAdvanced = '심화 예문';

  /// 따라 말할 예문이 하나도 없는 단어로 들어온 경우. (딥링크 등)
  static const String noSentence = '이 단어는 아직 따라 말할 문장이 없어.';
  static const String backToWords = '단어장으로';

  // ── 2단계 말하기 ──
  static const String speakGuide = '이 문장을 천천히 따라 말해 봐';
  static const String micReady = '마이크를 누르고 말해 봐';
  static String micRecording(int seconds) => '듣고 있어, $seconds초\n다 말했으면 다시 눌러 줘';
  static const String micTranscribing = '네 목소리를 글자로 옮기고 있어...';
  static const String micSubmitting = '얼마나 닮게 말했는지 보고 있어...';

  /// 스크린리더용 마이크 라벨.
  static const String micStart = '눌러서 말하기';
  static const String micStop = '말하기 끝내기';

  // ── 마이크 옆 짧은 안내 ──
  static const String hintNotHeard = '잘 안 들렸어. 한 번만 더 말해 줄래?';
  static const String hintTooLong = '조금 길었어. 짧게 말해 볼까?';
  static const String hintWait = '지금은 잘 안 들려. 조금 있다가 다시 해 볼까?';
  static const String hintMicPermission = '마이크를 켜 주면 네 목소리를 들을 수 있어.';
  static const String hintMicFailed = '마이크가 안 켜졌어. 다시 한번 눌러 줄래?';

  // ── 3단계 결과 ──
  static const String rewardedTitle = '우와, 문장이랑 똑같았어!';

  /// "+2" - 이번에 받은 별가루.
  static String stardustGain(int amount) => '+$amount';
  static const String stardustBalanceLabel = '내 별가루';

  static const String alreadyRewardedTitle = '이번에도 멋지게 말했어!';
  static const String alreadyRewardedBody = '이 문장은 벌써 별가루를 받았어.\n다른 예문도 해 볼까?';

  static const String dailyLimitTitle = '오늘도 정말 잘 말했어!';
  static const String dailyLimitBody = '오늘 별가루 주머니가 가득 찼어.\n내일 또 하자!';

  static const String notMatchedTitle = '거의 다 왔어!';
  static String similarity(int percent) => '문장이랑 $percent% 닮았어';
  static const String targetLabel = '따라 할 문장';
  static const String spokenLabel = '이렇게 들렸어';
  static const String retry = '다시 말하기';

  static const String anotherSentence = '다른 예문 해보기';

  /// `EXAMPLE_SENTENCE_MISSING` - 예문 확장 전에 담은 단어.
  static const String sentenceMissing = '이 문장은 아직 준비하고 있어.\n다른 예문을 골라 볼까?';
  static const String pickAgain = '예문 고르기';
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

  /// 이메일 계정에 묻는 말. 소셜 계정은 비밀번호가 없어 아예 묻지 않습니다.
  static const String gateBody = '리포트는 보호자만 볼 수 있어요.\n계정 비밀번호를 입력해 주세요.';
  static const String gatePasswordLabel = '비밀번호';

  /// 비밀번호가 틀렸을 때. 다이얼로그를 닫지 않고 이 자리에만 뜹니다 -
  /// 닫아 버리면 보호자가 리포트 메뉴부터 다시 눌러야 합니다.
  static const String gateWrongPassword = '비밀번호가 올바르지 않아요.';

  /// 보호자 조회·비밀번호 확인이 네트워크 문제로 실패했을 때.
  /// **통과시키지 않습니다** - 연결이 끊긴 상태에서 게이트가 뚫리는 것보다
  /// 보호자가 잠깐 못 보고 다시 시도하는 편이 낫습니다.
  static const String gateNetworkError = '잠시 후 다시 시도해 주세요.';
  static const String gateRetry = '다시 시도';

  static const String gateConfirm = '확인';
  static const String gateCancel = '취소';
}

/// 보호자 리포트 목록(`/mypage/report`) 전용 문구.
abstract final class ReportListStrings {
  static const String title = '보호자 리포트';

  static String childLabel(String name) => '아이: $name';

  /// "리포트 4개"
  ///
  /// 안 읽은 개수는 붙이지 않습니다 - 서버가 열람 여부를 저장하지 않아
  /// 앱을 다시 켜면 전부 다시 "새 리포트"가 됐습니다. 틀린 숫자를 보여 주느니
  /// 총 개수만 말합니다. 서버가 열람 여부를 주면 그때 다시 넣습니다.
  static String summary(int total) => '리포트 $total개';

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

/// 설정(`/settings`) 전용 문구.
abstract final class SettingsStrings {
  static const String title = '설정';
  static const String consentComplete = '동의 완료';
  static const String consentRequired = '동의 필요';

  static const String notificationGroup = '알림';
  static const String reportNotification = '리포트 도착 알림';
  static const String reportNotificationDesc = '아이가 이야기를 완주하면 알려드려요.';
  static const String marketingConsent = '마케팅 수신 동의';
  static const String marketingOn = '마케팅 수신에 동의했어요.';
  static const String marketingOff = '마케팅 수신 동의를 철회했어요.';

  static const String infoGroup = '안내';

  /// 답변 알림과 공지 알림이 쌓이는 곳. 푸시를 못 받아도 여기서 확인합니다.
  ///
  /// 위쪽 알림 그룹(수신 토글)과 이름이 겹치지 않게 '알림함'으로 둡니다.
  static const String notifications = '알림함';
  static const String notice = '공지사항';
  static const String guide = '이용 안내';
  static const String support = '고객센터';

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

/// 보호자 인증(`/auth`) 전용 문구.
///
/// 이 화면의 사용자는 **보호자**입니다. 서비스 본편(아이 대상)과 달리
/// 그림·음성 우선 원칙이 적용되지 않고, 일반 성인용 인증 UX 톤을 씁니다.
abstract final class AuthStrings {
  // ── 스텝 1 로그인 ──
  static const String tagline = '아이의 말하기가 자라나요';
  static const String orDivider = '또는';
  static const String email = '이메일';
  static const String password = '비밀번호';
  static const String name = '보호자 이름';
  static const String signIn = '로그인';
  static const String socialSignIn = '소셜 로그인';
  static const String emailSignIn = '이메일 로그인';
  static const String kakaoSignIn = '카카오로 계속하기';
  static const String googleSignIn = '구글로 계속하기';
  static const String keepSignedIn = '로그인 유지';
  static const String signUpWithEmail = '회원가입';
  static const String findId = 'ID 찾기';
  static const String findPassword = 'PW 찾기';
  static const String accountHelpTitle = '계정 찾기';
  static const String accountHelpBody =
      '현재는 고객센터를 통해 계정을 확인할 수 있습니다. 계정 찾기 API가 준비되면 이 메뉴에서 바로 지원할 예정입니다.';
  static const String close = '확인';
  static const String signUp = '가입하기';
  static const String backToSignIn = '로그인으로 돌아가기';

  /// 자격 불일치. 어느 쪽이 틀렸는지는 알려주지 않습니다(계정 존재 여부 노출 방지).
  static const String signInFailed = '이메일 또는 비밀번호를 다시 확인해 주세요.';
  static const String emailRequired = '이메일을 입력해 주세요.';
  static const String passwordRequired = '비밀번호를 입력해 주세요.';
  static const String nameRequired = '보호자 이름을 입력해 주세요.';

  /// 소셜 로그인 실패 시뮬레이션.
  static const String socialFailed = '로그인에 실패했어요. 잠시 후 다시 시도해 주세요.';

  /// 비밀번호 5회 실패로 계정이 잠겼을 때(423 `ACCOUNT_LOCKED`).
  static const String accountLocked = '로그인을 너무 많이 시도했어요. 잠시 후 다시 시도해 주세요.';

  // ── 스텝 2 동의 ──
  static const String consentTitle = '동의가 필요해요';
  static const String consentAll = '전체 동의';
  static const String consentRequired = '필수';
  static const String consentOptional = '선택';
  static const String consentView = '보기';
  static const String consentContinue = '동의하고 계속하기';

  /// 필수 항목을 안 채운 채 눌렀을 때.
  static const String consentMissing = '필수 항목에 동의해야 계속할 수 있어요.';

  // ── 스텝 3 아이 프로필 ──
  static const String childTitle = '함께할 아이를 알려주세요';
  static const String childName = '아이 이름';
  static const String childNameHint = '예: 하늘이';
  static const String childAge = '나이';
  static String ageLabel(int age) => '$age세';
  static const String start = '시작하기';

  /// 완료 직후의 짧은 환영. 곧바로 홈으로 넘어갑니다.
  static String welcome(String name) {
    final String childName = name.trim();
    return childName.isEmpty ? '반가워요!' : '$childName, 환영해요!';
  }

  /// 프로필 없이 홈에 들어갈 수 없으므로, 여기서의 뒤로가기는 로그아웃입니다.
  static const String signOutConfirm = '로그아웃할까요?\n아이 프로필을 만들어야 시작할 수 있어요.';
  static const String signOutConfirmAction = '로그아웃';
  static const String cancel = '취소';

  static const String loadFailed = '화면을 불러오지 못했어요.';

  /// 목업의 문서 뷰. 실제 약관이 들어오면 이 자리를 채웁니다.
  static const String documentPlaceholder = '문서 내용은 준비 중입니다.';

  /// "2/3" — 스텝 인디케이터의 스크린리더용 라벨.
  static String stepOf(int current, int total) => '$total단계 중 $current단계';
}

/// 로그인 화면에서 이어지는 계정 찾기 화면 문구.
abstract final class AuthRecoveryStrings {
  static const String backToLogin = '로그인으로 돌아가기';
  static const String findIdTab = 'ID 찾기';
  static const String resetPasswordTab = 'PW 찾기';

  static const String findIdTitle = '가입한 이메일을 찾아드릴게요';
  static const String findIdDescription =
      '가입할 때 입력한 보호자 이름과 아이 정보로 가입 이메일을 확인합니다.';
  static const String guardianName = '보호자 이름';
  static const String childName = '아이 이름';
  static const String childNameHint = '예: 지우';
  static const String childBirthYear = '아이 출생연도';
  static const String childBirthYearHint = '예: 2018';
  static const String findIdAction = '가입 이메일 확인하기';

  /// 아이 정보를 왜 다 받는지. **비워 두면 못 찾습니다** - 서버가 아이 정보
  /// 없이 찾을 때는 아이가 등록된 계정을 결과에서 빼기 때문입니다(아이 정보
  /// 없이 남의 계정을 캐낼 수 없게 하는 조건).
  static const String childInfoNotice = '아이 이름과 출생연도를 모두 입력해야 계정을 찾을 수 있어요.';

  static const String resetTitle = '비밀번호를 다시 설정해요';
  static const String resetDescription = '가입한 이메일로 안전한 비밀번호 재설정 링크를 보내드립니다.';
  static const String email = '가입 이메일';
  static const String emailHint = 'name@example.com';
  static const String resetAction = '재설정 링크 받기';

  static const String requiredFields = '입력하지 않은 항목이 있어요.';
  static const String invalidBirthYear = '출생연도를 네 자리로 입력해 주세요. (예: 2018)';
  static const String invalidEmail = '올바른 이메일 주소를 입력해 주세요.';
  static const String requestFailed = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.';

  static const String findIdDoneTitle = '가입 이메일을 확인했어요';

  /// 이메일은 **서버가 가려서** 옵니다(`de***@...`). 화면에서 또 가리지 않습니다.
  static const String findIdDoneBody = '아래 주소로 로그인해 보세요.';

  /// 못 찾았을 때. 오류가 아니라 결과입니다 - 서버도 404 가 아니라 빈 목록을 줍니다.
  static const String findIdEmptyTitle = '일치하는 계정을 찾지 못했어요';
  static const String findIdEmptyBody =
      '이름과 아이 정보가 가입할 때와 같은지 확인해 주세요. 소셜 계정으로 가입했다면 카카오·구글 로그인을 눌러 보세요.';
  static const String resetDoneTitle = '재설정 안내를 보냈어요';
  static const String resetDoneBody =
      '입력한 이메일로 비밀번호 재설정 링크를 보냈습니다. 메일함을 확인해 주세요.';
  static const String resend = '다시 보내기';

  /// ID 찾기의 같은 자리. 보낸 것이 없으니 "다시 보내기"가 아닙니다 -
  /// 특히 못 찾은 화면에서는 이 버튼이 유일한 재시도 통로입니다.
  static const String findIdRetry = '다시 찾기';

  /// **PW 찾기 전용입니다.** ID 찾기는 목적 자체가 이메일을 알려 주는 것이라
  /// 결과가 갈리고, 서버도 그렇게 동작합니다. 그 화면에는 [childInfoNotice] 를
  /// 씁니다.
  static const String securityNotice = '계정 보호를 위해 가입 여부와 관계없이 동일한 안내를 표시합니다.';
  static const String newPasswordTitle = '새 비밀번호 설정';
  static const String newPassword = '새 비밀번호';
  static const String confirmPassword = '새 비밀번호 확인';
  static const String passwordRule = '8자 이상 입력해 주세요.';
  static const String passwordMismatch = '비밀번호가 서로 일치하지 않습니다.';
  static const String invalidResetLink = '유효하지 않은 비밀번호 재설정 링크입니다.';
  static const String changePassword = '비밀번호 변경하기';
  static const String passwordChanged = '비밀번호가 변경되었습니다.';
}
