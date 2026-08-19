import 'package:flutter/material.dart';

/// 아이콘 토큰.
///
/// ## 규칙 1 — `_rounded` 변형만 씁니다
///
/// Flutter 에 내장된 Material 아이콘에는 `_rounded` / `_outlined` / `_sharp`
/// 변형이 있습니다. 이 앱은 로고와 폰트가 모두 둥글기 때문에 **`_rounded`
/// 하나로 통일**합니다. `Icons.home` (기본 = filled sharp) 을 쓰면
/// 그 화면만 각져 보입니다.
///
/// 아이콘 패키지를 추가하지 않는 이유도 같습니다 — 내장 세트로 충분하고,
/// 패키지를 섞으면 굵기와 광학 크기가 어긋납니다.
///
/// ## 규칙 2 — 아이 화면에서 아이콘 단독 금지
///
/// 초1~3은 아이콘 관습을 아직 모릅니다. 아이가 누르는 버튼은 반드시
/// **아이콘 + 한 단어 + 음성 안내** 세 가지를 함께 줍니다.
/// 보호자 화면에서는 아이콘만 써도 됩니다.
///
/// ## 규칙 3 — 이름을 여기서만 정합니다
///
/// 화면에서 `Icons.mic_rounded` 를 직접 쓰지 말고 [AppIcons.speak] 을 쓰세요.
/// "말하기"의 아이콘을 나중에 바꿀 때 한 줄만 고치면 됩니다.
abstract final class AppIcons {
  // 하단 내비게이션 (PRD F-02)
  static const IconData home = Icons.home_rounded;
  static const IconData stories = Icons.auto_stories_rounded;
  static const IconData words = Icons.menu_book_rounded;
  static const IconData myPage = Icons.person_rounded;

  // 말하기 루프 (PRD F-05)
  /// 마이크. 화면에서 가장 큰 버튼.
  static const IconData speak = Icons.mic_rounded;

  /// 지금 아이가 말하는 중 — 파형.
  static const IconData speaking = Icons.graphic_eq_rounded;

  /// 캐릭터가 말하는 중.
  static const IconData characterSpeaking = Icons.record_voice_over_rounded;

  /// 작별 인사. 손을 흔드는 그림이라 글자를 아직 못 읽는 아이도 "인사"로
  /// 읽습니다 — 나가는 두 갈래를 아이콘만으로도 가르는 자리입니다.
  static const IconData farewell = Icons.waving_hand_rounded;

  /// 다시 듣기.
  static const IconData replay = Icons.replay_rounded;

  /// 소리 켜기 / 끄기.
  static const IconData soundOn = Icons.volume_up_rounded;
  static const IconData soundOff = Icons.volume_off_rounded;

  /// 발화 확정.
  static const IconData send = Icons.send_rounded;

  /// 다시 녹음.
  static const IconData retry = Icons.refresh_rounded;

  /// 말하기 끝내기. 녹음 중인 마이크 버튼이 이 아이콘으로 바뀝니다.
  static const IconData stop = Icons.stop_rounded;

  /// 타이핑으로 고치기. **보조 수단이므로 마이크보다 작게 둡니다.**
  static const IconData typeInstead = Icons.keyboard_rounded;

  /// 다음 장면으로. 자동 전환하지 않고 아이가 직접 누릅니다. (PRD F-04)
  static const IconData next = Icons.arrow_forward_rounded;

  // 이야기 (PRD F-03, F-04)
  static const IconData play = Icons.play_arrow_rounded;
  static const IconData filter = Icons.filter_alt_rounded;
  static const IconData duration = Icons.schedule_rounded;
  static const IconData difficulty = Icons.bar_chart_rounded;

  /// 주제 태그.
  static const IconData topic = Icons.sell_rounded;

  /// 주제 필터 칩. 아이가 **그림으로** 주제를 구분하는 자리라서, 뜻이 바로
  /// 보이는 아이콘을 골랐습니다. 새 주제가 생기면 여기에 한 줄 추가하세요.
  static const IconData topicAll = Icons.grid_view_rounded;
  static const IconData topicFolk = Icons.cottage_rounded;
  static const IconData topicAnimal = Icons.pets_rounded;
  static const IconData topicAdventure = Icons.explore_rounded;
  static const IconData topicDaily = Icons.wb_sunny_rounded;

  /// 미션. 장면의 목표 발화 조건을 아이에게 보여줄 때.
  static const IconData mission = Icons.flag_rounded;

  /// 힌트. 무응답 30초, 순서 2회 오답 시.
  static const IconData hint = Icons.lightbulb_rounded;

  // 단어장 (PRD F-10)
  /// 모르는 단어 담기.
  static const IconData saveWord = Icons.bookmark_add_rounded;
  static const IconData savedWord = Icons.bookmark_rounded;
  static const IconData like = Icons.favorite_rounded;
  static const IconData likeOff = Icons.favorite_border_rounded;

  // 행성·보상 (PRD F-08)
  /// 별가루.
  static const IconData stardust = Icons.auto_awesome_rounded;
  static const IconData planet = Icons.public_rounded;
  static const IconData shop = Icons.storefront_rounded;
  static const IconData inventory = Icons.inventory_2_rounded;
  static const IconData rotate = Icons.rotate_right_rounded;
  static const IconData zoomIn = Icons.zoom_in_rounded;
  static const IconData zoomOut = Icons.zoom_out_rounded;

  /// 직전 한 동작 되돌리기. 항상 화면에 있어야 합니다.
  static const IconData undo = Icons.undo_rounded;

  /// 아직 못 여는 아이템.
  static const IconData locked = Icons.lock_rounded;

  // 보호자 (PRD F-01, F-09)
  static const IconData report = Icons.insights_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData notification = Icons.notifications_rounded;
  static const IconData childProfile = Icons.child_care_rounded;
  static const IconData switchChild = Icons.switch_account_rounded;
  static const IconData signOut = Icons.logout_rounded;

  /// 보호자 확인 게이트 — 아이가 혼자 리포트를 열지 못하게 하는 문.
  static const IconData guardianGate = Icons.shield_rounded;

  // 설정·운영 (보호자 화면 전용)
  static const IconData notice = Icons.campaign_rounded;
  static const IconData guide = Icons.info_rounded;
  static const IconData support = Icons.help_center_rounded;
  static const IconData terms = Icons.description_rounded;
  static const IconData privacy = Icons.privacy_tip_rounded;
  static const IconData account = Icons.account_circle_rounded;

  /// 추천 질문을 메신저로 옮겨 쓰라고 있는 버튼.
  static const IconData copy = Icons.copy_rounded;

  /// 아코디언 펼침. 접힌 상태에서 아래를, 펼친 상태에서 위를 가리킵니다.
  static const IconData expand = Icons.expand_more_rounded;

  /// 목록에서 고른 것 / 안 고른 것. 색만으로 구분하지 않기 위한 짝입니다.
  static const IconData checked = Icons.check_circle_rounded;
  static const IconData unchecked = Icons.radio_button_unchecked_rounded;

  // 공통
  /// "더 보기 ›", "가기 ›" 처럼 이동을 암시하는 꺾쇠.
  /// **단독으로 쓰지 말고** 항상 라벨 옆에 붙입니다.
  static const IconData chevronRight = Icons.chevron_right_rounded;

  static const IconData back = Icons.arrow_back_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData done = Icons.check_circle_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData delete = Icons.delete_outline_rounded;
}
