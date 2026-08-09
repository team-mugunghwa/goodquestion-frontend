/// 설정 화면이 보여 주는 값.
class AppSettings {
  const AppSettings({
    required this.reportNotification,
    required this.marketingConsent,
    required this.accountType,
    required this.accountLabel,
    required this.hasNewNotice,
    required this.appVersion,
    this.consentAt,
  });

  /// 완주 알림 수신 여부. F-09 알림의 **유일한 사용자 제어 지점**이라
  /// 화면 최상단에 둡니다.
  final bool reportNotification;

  final bool marketingConsent;

  /// 동의 시각. 화면에 보여 주지는 않지만 법적으로 기록이 필요합니다.
  final DateTime? consentAt;

  /// `email` · `kakao` · `google`
  final String accountType;

  /// 마스킹된 표시값. 원본 이메일을 그대로 두지 않습니다.
  final String accountLabel;

  final bool hasNewNotice;
  final String appVersion;

  AppSettings copyWith({bool? reportNotification, bool? marketingConsent}) =>
      AppSettings(
        reportNotification: reportNotification ?? this.reportNotification,
        marketingConsent: marketingConsent ?? this.marketingConsent,
        consentAt: consentAt,
        accountType: accountType,
        accountLabel: accountLabel,
        hasNewNotice: hasNewNotice,
        appVersion: appVersion,
      );
}
