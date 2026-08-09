/// 로그인 화면이 서버에서 받아야 하는 선택지들.
///
/// 소셜 제공자와 동의 항목을 앱에 하드코딩하지 않는 이유는 같습니다 —
/// **법무·제휴 사정으로 바뀌는 값**이고, 바뀔 때마다 앱을 새로 배포할 수는
/// 없습니다. 특히 동의 항목은 문구 한 줄만 바뀌어도 재동의를 받아야 합니다.
class AuthOptions {
  const AuthOptions({
    required this.providers,
    required this.consents,
    required this.ages,
  });

  final List<SocialProvider> providers;

  /// 필수가 먼저, 선택이 나중. 서버 순서를 그대로 씁니다.
  final List<ConsentItem> consents;

  /// 나이 선택지. **타이핑을 줄이려고 버튼형**으로 받습니다.
  final List<int> ages;

  /// 필수 동의 항목의 id 들. 이걸 다 채워야 다음으로 넘어갑니다.
  Set<String> get requiredConsentIds => consents
      .where((ConsentItem c) => c.required)
      .map((ConsentItem c) => c.id)
      .toSet();
}

/// 소셜 로그인 버튼 하나.
class SocialProvider {
  const SocialProvider({required this.provider, required this.label});

  /// `kakao` · `google`
  final String provider;

  final String label;
}

/// 동의 항목 하나.
class ConsentItem {
  const ConsentItem({
    required this.id,
    required this.title,
    required this.required,
    this.docUrl,
  });

  final String id;
  final String title;

  /// 필수 항목은 체크하지 않으면 진행할 수 없습니다.
  ///
  /// **아동 개인정보 수집은 서비스 약관과 별도의 필수 항목**입니다.
  /// 하나로 묶으면 안 됩니다. (PRD F-01)
  final bool required;

  final String? docUrl;
}
