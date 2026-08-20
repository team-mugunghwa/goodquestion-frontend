import 'package:flutter/material.dart';

/// 색 토큰.
///
/// 로고(말풍선 Q)의 그라디언트에서 출발했습니다. 왼쪽 위 민트블루 →
/// 오른쪽 아래 라이트그린으로 흐르고, 워드마크는 "Good"(그린) +
/// "Question"(블루) 로 나뉩니다.
///
/// ## 이 팔레트의 규칙 3가지 (→ `docs/DESIGN_SYSTEM.md`)
///
/// 1. **따뜻한 색은 보상에만.** 화면 전체가 차가운 파스텔이라서,
///    [stardust] 계열 노랑이 나오면 시선이 자동으로 그리로 갑니다.
///    별가루·완주 축하 말고 다른 곳에 노랑을 쓰면 이 장치가 죽습니다.
/// 2. **아이 화면에 빨강([danger])을 쓰지 않습니다.** STT 실패·오답은
///    실패가 아니라 "한 번 더"입니다. [caution] 을 쓰세요. (PRD §6)
/// 3. **[brandBlue]·[brandGreen]·[brandMint] 는 면과 장식 전용입니다.**
///    흰 배경에서 대비가 2:1 근처라 글자로 쓰면 안 읽힙니다.
///    글자·아이콘에는 [brandBlueDeep] / [brandGreenDeep] 을 쓰세요.
///
/// 일반적인 UI 색은 가능하면 `Theme.of(context).colorScheme.*` 를 쓰고,
/// 여기 있는 값은 **브랜드 표현·아이 화면 전용 표면**에 씁니다.
abstract final class AppColors {
  // ─────────────────────────────────────────────────────────
  // 브랜드 — 로고에서 추출
  // ─────────────────────────────────────────────────────────

  /// 워드마크 "Question" 의 파랑. 앱의 주 색상. **면 전용.**
  static const Color brandBlue = Color(0xFF83B9DD);

  /// 워드마크 "Good" 의 초록. 보조 색상. **면 전용.**
  static const Color brandGreen = Color(0xFFA0CE99);

  /// Q 마크 왼쪽 위의 민트. **면 전용.**
  static const Color brandMint = Color(0xFF8FD4E3);

  /// 파랑의 글자용 버전. 흰 배경 대비 5.5:1.
  static const Color brandBlueDeep = Color(0xFF2A6E9E);

  /// 초록의 글자용 버전. 흰 배경 대비 5.1:1.
  static const Color brandGreenDeep = Color(0xFF387C4C);

  /// [brandBlue] 10% 면. 아이 발화 말풍선, 미션 배너, 칩, 선택된 탭처럼
  /// **흰 카드 위에서 한 겹 구분**이 필요한 자리에 씁니다.
  ///
  /// 알파를 화면마다 손으로 정하면(8%·12%·15%…) 같은 뜻의 면이 화면마다
  /// 다른 색이 됩니다. 이 값 하나만 쓰세요.
  static const Color brandBlueSurface = Color(0x1A83B9DD);

  /// [brandGreen] 10% 면. **해낸 것**을 흰 카드 위에서 표시하는 자리에만
  /// 씁니다 — 말하기 후 활동에서 아이가 실제로 쓴 낱말 칩이 여기서
  /// [brandBlueSurface] 로부터 갈라집니다.
  ///
  /// 파스텔 초록을 그대로 면으로 깔면 [brandGreenDeep] 글자와 대비가
  /// 2.8:1 로 떨어져 안 읽힙니다. 흰 면에 10% 로 얹으면 4.7:1 입니다.
  static const Color brandGreenSurface = Color(0x1AA0CE99);

  /// Material 3 팔레트 생성용 시드.
  ///
  /// 로고 색을 그대로 시드로 쓰면 채도가 너무 낮아 버튼·텍스트 대비가
  /// 부족해집니다. 같은 색상(hue)을 유지한 채 채도만 올린 값입니다.
  static const Color seed = Color(0xFF4E9BC9);

  /// 로고와 같은 방향의 그라디언트. 스플래시·헤더·엠티 상태 일러스트에 사용.
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandMint, brandBlue, brandGreen],
    stops: [0.0, 0.45, 1.0],
  );

  // ─────────────────────────────────────────────────────────
  // 잉크 — 글자·아이콘·테두리
  // ─────────────────────────────────────────────────────────

  /// 본문 글자. 순수 검정 대신 파랑기가 도는 남색이라 파스텔 배경에서
  /// 덜 딱딱해 보입니다.
  static const Color ink900 = Color(0xFF16233F);

  /// 부제·보조 제목.
  static const Color ink700 = Color(0xFF33456B);

  /// 캡션·비활성 글자. 흰 배경 대비 5.4:1 — 작은 글자에도 씁니다.
  static const Color ink500 = Color(0xFF5A6A8A);

  /// 테두리·구분선. **글자로 쓰지 마세요.**
  static const Color ink300 = Color(0xFFC2CCDB);

  /// 옅은 구분선·비활성 면.
  static const Color ink100 = Color(0xFFE4E9F2);

  // ─────────────────────────────────────────────────────────
  // 캔버스 — 화면의 바탕
  //
  // 아이의 하루는 낮에서 시작해 밤에서 끝납니다. 홈·이야기·활동은 [dayGradient],
  // 별가루를 받는 완료 화면과 내 행성은 [nightGradient] 입니다.
  // 이 전환 자체가 "오늘 이야기를 끝냈다"는 신호입니다.
  // ─────────────────────────────────────────────────────────

  static const Color dayTop = Color(0xFFEAF7FA);
  static const Color dayBottom = Color(0xFFF0F7EC);

  /// 낮 — 아이 화면 기본 바탕.
  static const LinearGradient dayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [dayTop, dayBottom],
  );

  static const Color nightTop = Color(0xFF16233F);
  static const Color nightBottom = Color(0xFF2B3E66);

  /// 밤 — 완료 화면·내 행성. 별가루가 가장 잘 보이는 배경.
  static const LinearGradient nightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [nightTop, nightBottom],
  );

  /// 보호자·시스템 화면 바탕. 아이 화면과 달리 그라디언트를 쓰지 않습니다.
  /// 리포트는 읽는 화면이라 배경이 조용해야 합니다.
  static const Color guardianCanvas = Color(0xFFF6F8FA);

  /// 카드·시트·말풍선의 면.
  static const Color surface = Color(0xFFFFFFFF);

  // ─────────────────────────────────────────────────────────
  // 별가루 — 화면에서 유일하게 따뜻한 색
  // ─────────────────────────────────────────────────────────

  /// 별가루 본색. **밤 배경 위에서만 글자로 쓸 수 있습니다**(대비 9.7:1).
  /// 낮 배경에서는 [stardustGlow] 면 + [ink900] 글자 조합으로 쓰세요.
  static const Color stardust = Color(0xFFFFC24B);

  /// 별가루 테두리·그림자용 진한 금색.
  static const Color stardustDeep = Color(0xFFE39A16);

  /// 별가루 칩·배지의 옅은 면.
  static const Color stardustGlow = Color(0xFFFFF3D2);

  // ─────────────────────────────────────────────────────────
  // 시맨틱
  // ─────────────────────────────────────────────────────────

  /// 미션 통과·저장 완료.
  static const Color success = brandGreenDeep;

  /// "한 번 더 해볼까?" — STT 실패, 순서 오답, 무응답 힌트.
  /// 아이에게 보이는 유일한 경고색입니다.
  static const Color caution = Color(0xFFB4682A);

  /// [caution] 의 면 버전.
  static const Color cautionSurface = Color(0xFFFDEBD8);

  /// ⚠️ **보호자 화면 전용.** 로그인 실패, 계정 삭제 확인 등.
  /// 아이가 보는 화면에는 쓰지 않습니다.
  static const Color danger = Color(0xFFB3403C);

  /// 키보드 포커스 링. 접근성상 어디서든 같은 색이어야 합니다.
  static const Color focus = brandBlueDeep;

  /// 상점의 잠긴 아이템 위에 덮는 막. 실루엣만 보이게 합니다.
  static const Color lockedScrim = Color(0x7316233F);
}
