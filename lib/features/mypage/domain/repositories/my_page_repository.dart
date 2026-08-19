import '../entities/app_settings.dart';
import '../entities/my_page_summary.dart';
import '../entities/report_detail.dart';
import '../entities/report_summary.dart';

/// 마이페이지 허브 데이터.
abstract class MyPageRepository {
  Future<MyPageSummary> getSummary();
}

abstract class ChildProfileRepository {
  String? get selectedChildId;

  Future<void> createChild({required String name, required int age});

  /// 이미 있는 아이를 고칩니다. **새로 만들지 않습니다** - 화면의 연필
  /// 아이콘이 여기로 옵니다.
  Future<void> updateChild({
    required String childId,
    required String name,
    required int age,
  });

  Future<List<MyPageChild>> getChildren();

  Future<void> selectChild(String childId);
}

/// 보호자 리포트. 목록과 상세가 같은 출처를 씁니다.
abstract class ReportRepository {
  Future<ReportList> getReportList();

  /// 없는 sessionId 면 `null` — 예외가 아닙니다.
  /// (아직 분석이 안 끝난 세션과 로드 실패는 화면이 다릅니다)
  Future<ReportDetail?> getReportDetail(String sessionId);
}

/// 알림·계정 설정.
abstract class SettingsRepository {
  Future<AppSettings> getSettings();

  /// 토글은 즉시 반영됩니다. 바뀐 전체 설정을 돌려줍니다.
  Future<AppSettings> setReportNotification({required bool enabled});

  Future<AppSettings> setMarketingConsent({required bool enabled});
}
