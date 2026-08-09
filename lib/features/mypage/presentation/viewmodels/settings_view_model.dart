import '../../../../core/presentation/base_view_model.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/usecases/my_page_use_cases.dart';

/// 설정 화면의 상태.
///
/// 토글은 **즉시 반영**됩니다. 저장 중 스피너를 돌리지 않습니다 — 스위치가
/// 눌린 뒤에 반응이 늦으면 사용자는 두 번 누릅니다.
class SettingsViewModel extends BaseViewModel {
  SettingsViewModel(
    this._getSettings,
    this._setReportNotification,
    this._setMarketingConsent,
  );

  final GetSettingsUseCase _getSettings;
  final SetReportNotificationUseCase _setReportNotification;
  final SetMarketingConsentUseCase _setMarketingConsent;

  AppSettings? _settings;

  /// 마케팅 동의를 방금 바꿨는가. View 가 토스트를 띄우고 지웁니다.
  bool? _marketingToast;

  AppSettings? get settings => _settings;

  /// 한 번 읽고 지웁니다. `null` 이면 띄울 토스트가 없습니다.
  bool? takeMarketingToast() {
    final bool? value = _marketingToast;
    _marketingToast = null;
    return value;
  }

  Future<void> load() => guard(() async {
    _settings = await _getSettings();
  });

  Future<void> setReportNotification({required bool enabled}) async {
    _settings = await _setReportNotification(enabled: enabled);
    safeNotify();
  }

  Future<void> setMarketingConsent({required bool enabled}) async {
    _settings = await _setMarketingConsent(enabled: enabled);
    // 마케팅 동의는 법적 의미가 있어서 바뀐 걸 사용자에게 알립니다.
    _marketingToast = enabled;
    safeNotify();
  }
}
