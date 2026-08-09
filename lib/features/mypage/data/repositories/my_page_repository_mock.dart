import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/my_page_summary.dart';
import '../../domain/entities/report_detail.dart';
import '../../domain/entities/report_summary.dart';
import '../../domain/repositories/my_page_repository.dart';
import '../datasources/my_page_local_data_source.dart';
import '../dtos/my_page_dto.dart';

/// 서버가 준비되기 전까지 보호자 화면 데이터를 번들 더미에서 읽는 구현.
///
/// 세 Repository 를 한 클래스가 구현합니다. 출처가 같은 파일 묶음이고
/// 열람 처리·토글 상태를 **한 곳에서** 들고 있어야 화면 간에 어긋나지
/// 않기 때문입니다. 서버가 붙으면 셋으로 쪼개도 화면은 그대로입니다.
class MyPageRepositoryMock
    implements MyPageRepository, ReportRepository, SettingsRepository {
  MyPageRepositoryMock(
    this._localDataSource, {
    this.latency = const Duration(milliseconds: 400),
  });

  final MyPageLocalDataSource _localDataSource;
  final Duration latency;

  /// 열람한 세션. 더미의 `isNew` 위에 덮어씁니다.
  final Set<int> _readSessions = <int>{};

  /// 토글 결과. 메모리에만 남습니다 — 앱을 다시 켜면 더미 값으로 돌아갑니다.
  bool? _reportNotification;
  bool? _marketingConsent;

  @override
  Future<MyPageSummary> getSummary() => _guard(() async {
    final MyPageSummary summary = (await _localDataSource.fetchSummary())
        .toEntity();
    // 리포트를 다 읽었으면 마이페이지의 빨간 점도 사라져야 합니다.
    if (_readSessions.isEmpty) return summary;
    final ReportList reports = await _reportListRaw();
    final bool hasUnread = reports.reports.any(
      (ReportSummary r) => r.isNew && !_readSessions.contains(r.sessionId),
    );
    return MyPageSummary(
      child: summary.child,
      childCount: summary.childCount,
      completedStories: summary.completedStories,
      stardust: summary.stardust,
      hasNewReport: hasUnread,
    );
  });

  @override
  Future<ReportList> getReportList() => _guard(() async {
    final ReportList raw = await _reportListRaw();
    if (_readSessions.isEmpty) return raw;
    final List<ReportSummary> reports = raw.reports
        .map(
          (ReportSummary r) => _readSessions.contains(r.sessionId)
              ? r.copyWith(isNew: false)
              : r,
        )
        .toList(growable: false);
    return ReportList(
      childName: raw.childName,
      totalCount: raw.totalCount,
      newCount: reports.where((ReportSummary r) => r.isNew).length,
      reports: reports,
    );
  });

  @override
  Future<ReportDetail?> getReportDetail(int sessionId) => _guard(() async {
    final ReportDetailDto? dto = await _localDataSource.fetchReportDetail(
      sessionId,
    );
    return dto?.toEntity();
  });

  @override
  Future<void> markAsRead(int sessionId) async {
    _readSessions.add(sessionId);
  }

  @override
  Future<AppSettings> getSettings() => _guard(_settingsWithOverrides);

  @override
  Future<AppSettings> setReportNotification({required bool enabled}) async {
    _reportNotification = enabled;
    return _settingsWithOverrides();
  }

  @override
  Future<AppSettings> setMarketingConsent({required bool enabled}) async {
    _marketingConsent = enabled;
    return _settingsWithOverrides();
  }

  Future<ReportList> _reportListRaw() async =>
      (await _localDataSource.fetchReportList()).toEntity();

  Future<AppSettings> _settingsWithOverrides() async {
    final AppSettings base = (await _localDataSource.fetchSettings())
        .toEntity();
    return base.copyWith(
      reportNotification: _reportNotification,
      marketingConsent: _marketingConsent,
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    await Future<void>.delayed(latency);
    try {
      return await action();
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } on Object catch (e) {
      throw Failure.fromException(ParseException('$e'));
    }
  }
}
