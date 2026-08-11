import '../entities/app_settings.dart';
import '../entities/my_page_summary.dart';
import '../entities/report_detail.dart';
import '../entities/report_summary.dart';
import '../repositories/my_page_repository.dart';

/// 마이페이지 허브 진입·아이 전환 후 갱신.
class GetMyPageSummaryUseCase {
  const GetMyPageSummaryUseCase(this._repository);

  final MyPageRepository _repository;

  Future<MyPageSummary> call() => _repository.getSummary();
}

class CreateMyPageChildUseCase {
  const CreateMyPageChildUseCase(this._repository);

  final ChildProfileRepository _repository;

  Future<void> call({required String name, required int age}) =>
      _repository.createChild(name: name, age: age);
}

class GetMyPageChildrenUseCase {
  const GetMyPageChildrenUseCase(this._repository);

  final ChildProfileRepository _repository;

  Future<List<MyPageChild>> call() => _repository.getChildren();
}

class SelectMyPageChildUseCase {
  const SelectMyPageChildUseCase(this._repository);

  final ChildProfileRepository _repository;

  Future<void> call(String childId) => _repository.selectChild(childId);
}

/// 리포트 목록.
class GetReportListUseCase {
  const GetReportListUseCase(this._repository);

  final ReportRepository _repository;

  Future<ReportList> call() => _repository.getReportList();
}

/// 리포트 상세. 없으면 `null`.
class GetReportDetailUseCase {
  const GetReportDetailUseCase(this._repository);

  final ReportRepository _repository;

  Future<ReportDetail?> call(int sessionId) =>
      _repository.getReportDetail(sessionId);
}

/// 리포트 열람 처리. 카드를 눌러 상세로 들어가는 순간 부릅니다.
class MarkReportAsReadUseCase {
  const MarkReportAsReadUseCase(this._repository);

  final ReportRepository _repository;

  Future<void> call(int sessionId) => _repository.markAsRead(sessionId);
}

/// 설정 읽기.
class GetSettingsUseCase {
  const GetSettingsUseCase(this._repository);

  final SettingsRepository _repository;

  Future<AppSettings> call() => _repository.getSettings();
}

/// 알림 토글.
class SetReportNotificationUseCase {
  const SetReportNotificationUseCase(this._repository);

  final SettingsRepository _repository;

  Future<AppSettings> call({required bool enabled}) =>
      _repository.setReportNotification(enabled: enabled);
}

/// 마케팅 수신 동의 토글.
class SetMarketingConsentUseCase {
  const SetMarketingConsentUseCase(this._repository);

  final SettingsRepository _repository;

  Future<AppSettings> call({required bool enabled}) =>
      _repository.setMarketingConsent(enabled: enabled);
}
