import 'package:flutter/material.dart';

import '../constants/app_breakpoints.dart';
import 'app_colors.dart';

/// 폰트 패밀리 이름.
///
/// 두 개만 씁니다. 세 번째 폰트를 넣고 싶으면 먼저 팀에 이유를 말하세요.
///
/// **폰트 파일이 아직 없어도 앱은 그냥 돕니다.** Flutter 는 등록되지 않은
/// 패밀리를 만나면 시스템 기본 글꼴로 조용히 대체합니다. 설치 방법과
/// 라이선스는 `assets/fonts/README.md` 참고.
abstract final class AppFonts {
  /// 아이 화면의 제목·버튼·미션. 둥근 획이라 로고 워드마크와 같은 인상입니다.
  ///
  /// 나눔스퀘어라운드 — 무료, 상업적 이용·임베딩 허용.
  static const String display = 'NanumSquareRound';

  /// 본문 전체와 보호자 화면. 자소 균형이 좋고 숫자가 정갈합니다.
  ///
  /// Pretendard — SIL Open Font License 1.1.
  static const String body = 'Pretendard';

  /// 글리프가 없을 때 넘어갈 순서. 두 폰트 다 한글 11,172자를 갖고 있어서
  /// 서로가 서로의 폴백이 됩니다. 이걸 두지 않으면 웹은 빠진 글자 하나 때문에
  /// 구글 폰트 서버에서 Noto Sans KR 을 받아오고, 그동안 네모(□)가 보입니다.
  static const List<String> displayFallback = [body];
  static const List<String> bodyFallback = [display];
}

/// 글자 크기 토큰.
///
/// ## 두 개의 스케일
///
/// | 쓰는 곳 | 접두사 | 폰트 |
/// |---|---|---|
/// | 아이가 보는 화면 (홈·이야기·장면·활동·행성·단어장) | `kid*` | [AppFonts.display] |
/// | 보호자·시스템 화면 (로그인·마이페이지·리포트·설정) | `Theme.of(context).textTheme` | [AppFonts.body] |
///
/// 아이 스케일은 **초1~3 가독성 기준**이라 본문이 24sp에서 시작합니다.
/// 작아 보인다고 줄이지 마세요. 글을 못 읽어도 진행되게 만드는 게 목표지,
/// 글자를 예쁘게 앉히는 게 목표가 아닙니다. (PRD §6 화면)
///
/// ## 크기 기준은 태블릿(≥840dp)
///
/// 폰에서는 [scaled] 로 줄여 씁니다.
///
/// ```dart
/// Text('무슨 일이 있었어?',
///   style: AppTypography.scaled(AppTypography.kidTitle, context.windowSize))
/// ```
abstract final class AppTypography {
  // ─────────────────────────────────────────────────────────
  // 아이 화면
  // ─────────────────────────────────────────────────────────

  /// 완료 화면의 축하 문구, 획득 별가루 개수. 화면당 한 번만.
  static const TextStyle kidHero = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.displayFallback,
    fontSize: 44,
    height: 1.25,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.ink900,
  );

  /// 화면 제목, 미션 제목, 이야기 제목.
  static const TextStyle kidTitle = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.displayFallback,
    fontSize: 32,
    height: 1.3,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: AppColors.ink900,
  );

  /// 캐릭터 대사, 상황 설명, 미션 지시문. 말풍선 안의 글자.
  ///
  /// 한 줄 20자를 넘기지 마세요 — 넘으면 폭을 줄이지 말고 문장을 자릅니다.
  static const TextStyle kidBody = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.displayFallback,
    fontSize: 24,
    height: 1.55,
    fontWeight: FontWeight.w400,
    color: AppColors.ink900,
  );

  /// 아이 발화가 STT 로 변환돼 실시간으로 찍히는 글자.
  /// 확정 전이라는 걸 굵기와 색으로 구분합니다.
  static const TextStyle kidTranscript = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.bodyFallback,
    fontSize: 24,
    height: 1.5,
    fontWeight: FontWeight.w500,
    color: AppColors.ink700,
  );

  /// 큰 버튼 안의 한 단어. ("말하기", "다음", "다시 듣기")
  static const TextStyle kidButton = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.displayFallback,
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w800,
    color: AppColors.surface,
  );

  /// 아이 화면의 짧은 보조 글자. 별가루 개수, 아이템 가격.
  static const TextStyle kidLabel = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.displayFallback,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.ink700,
  );

  /// 카드 안에 들어가는 아주 짧은 꼬리표. 이야기 카드의 시간·주제 칩.
  ///
  /// [kidLabel] 을 카드에 그대로 쓰면 폭 200 짜리 카드에서 칩 두 개가
  /// 한 줄에 안 들어가 주제 이름이 잘립니다. **읽는 정보이지 누르는 것이
  /// 아니라서** 조금 작아도 됩니다. 누르는 칩([KidFilterChips])에는
  /// 쓰지 마세요 — 그쪽은 터치 타겟 64 를 지켜야 합니다.
  static const TextStyle kidCaption = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.displayFallback,
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.ink700,
  );

  // ─────────────────────────────────────────────────────────
  // 보호자·시스템 화면
  //
  // 아래는 ThemeData 의 textTheme 으로 들어갑니다. 화면에서는
  // `Theme.of(context).textTheme.titleLarge` 처럼 쓰세요.
  // ─────────────────────────────────────────────────────────

  static const TextStyle _pageTitle = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.bodyFallback,
    fontSize: 28,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.ink900,
  );

  static const TextStyle _sectionTitle = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.bodyFallback,
    fontSize: 20,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: AppColors.ink900,
  );

  static const TextStyle _cardTitle = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.bodyFallback,
    fontSize: 17,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: AppColors.ink900,
  );

  /// 리포트 본문. 보호자는 긴 글을 읽으므로 행간을 넉넉히 줍니다.
  static const TextStyle _body = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.bodyFallback,
    fontSize: 16,
    height: 1.65,
    fontWeight: FontWeight.w400,
    color: AppColors.ink700,
  );

  static const TextStyle _bodyStrong = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.bodyFallback,
    fontSize: 16,
    height: 1.65,
    fontWeight: FontWeight.w600,
    color: AppColors.ink900,
  );

  static const TextStyle _caption = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.bodyFallback,
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.ink500,
  );

  static const TextStyle _button = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.bodyFallback,
    fontSize: 16,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );

  /// 리포트에서 아이의 발화를 그대로 인용할 때.
  /// 분석 결과(우리 말)와 아이 말을 눈으로 구분해야 합니다.
  static const TextStyle quote = TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.displayFallback,
    fontSize: 18,
    height: 1.6,
    fontWeight: FontWeight.w400,
    color: AppColors.ink900,
  );

  /// ThemeData 에 넣을 텍스트 테마.
  static const TextTheme textTheme = TextTheme(
    displayLarge: kidHero,
    displayMedium: kidTitle,
    displaySmall: kidBody,
    headlineLarge: _pageTitle,
    headlineMedium: _pageTitle,
    headlineSmall: _sectionTitle,
    titleLarge: _sectionTitle,
    titleMedium: _cardTitle,
    titleSmall: _cardTitle,
    bodyLarge: _bodyStrong,
    bodyMedium: _body,
    bodySmall: _caption,
    labelLarge: _button,
    labelMedium: _caption,
    labelSmall: _caption,
  );

  // ─────────────────────────────────────────────────────────

  /// 폭 구간에 맞춰 글자 크기를 줄입니다. 태블릿(expanded)이 100% 입니다.
  ///
  /// 패딩·아이콘 크기도 같은 비율로 줄이면 화면이 통째로 축소된 것처럼
  /// 보여서 자연스럽습니다.
  static TextStyle scaled(TextStyle base, WindowSizeClass size) {
    final factor = switch (size) {
      WindowSizeClass.expanded => 1.0,
      WindowSizeClass.medium => 0.92,
      WindowSizeClass.compact => 0.84,
    };
    if (factor == 1.0) return base;
    return base.copyWith(fontSize: (base.fontSize ?? 16) * factor);
  }
}
