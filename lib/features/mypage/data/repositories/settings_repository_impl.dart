import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/my_page_summary.dart';
import '../../domain/repositories/my_page_repository.dart';
import '../datasources/my_page_local_data_source.dart';
import '../datasources/settings_remote_data_source.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._local, this._remote, this._childProfiles);

  final MyPageLocalDataSource _local;
  final SettingsRemoteDataSource _remote;
  final ChildProfileRepository _childProfiles;

  AppSettings? _current;

  @override
  Future<AppSettings> getSettings() async {
    try {
      final AppSettings base = (await _local.fetchSettings()).toEntity();
      final Map<String, dynamic> parent = await _remote.getParent();
      final String? childId = await _selectedChildId();
      final Map<String, dynamic>? consent = childId == null
          ? null
          : await _remote.getChildConsent(childId);
      final Map<String, dynamic>? currentConsent =
          consent?['current'] as Map<String, dynamic>?;

      _current = AppSettings(
        reportNotification:
            _current?.reportNotification ?? base.reportNotification,
        marketingConsent: _current?.marketingConsent ?? base.marketingConsent,
        consentAt: DateTime.tryParse(
          currentConsent?['consentedAt'] as String? ?? '',
        ),
        accountType: _accountType(parent['provider']),
        accountLabel: _accountLabel(parent),
        hasNewNotice: base.hasNewNotice,
        appVersion: base.appVersion,
      );
      return _current!;
    } on Failure {
      rethrow;
    } on AppException catch (error) {
      throw Failure.fromException(error);
    } on Object catch (error) {
      throw Failure.fromException(ParseException('$error'));
    }
  }

  @override
  Future<AppSettings> setReportNotification({required bool enabled}) async {
    final AppSettings settings = _current ?? await getSettings();
    return _current = settings.copyWith(reportNotification: enabled);
  }

  @override
  Future<AppSettings> setMarketingConsent({required bool enabled}) async {
    final AppSettings settings = _current ?? await getSettings();
    return _current = settings.copyWith(marketingConsent: enabled);
  }

  Future<String?> _selectedChildId() async {
    final String? selectedId = _childProfiles.selectedChildId;
    if (selectedId != null) return selectedId;

    final List<MyPageChild> children = await _childProfiles.getChildren();
    if (children.isEmpty) return null;
    await _childProfiles.selectChild(children.first.childId);
    return children.first.childId;
  }

  String _accountType(Object? provider) {
    final String value = provider?.toString().toLowerCase() ?? 'email';
    return value == 'local' ? 'email' : value;
  }

  String _accountLabel(Map<String, dynamic> parent) {
    final String email = parent['email'] as String? ?? '';
    if (email.isEmpty) return parent['name'] as String? ?? '';
    final int at = email.indexOf('@');
    if (at < 1) return email;
    final String local = email.substring(0, at);
    final int visibleLength = local.length > 2 ? 2 : local.length;
    final String visible = local.substring(0, visibleLength);
    return '$visible***${email.substring(at)}';
  }
}
