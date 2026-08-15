import '../../../../core/presentation/base_view_model.dart';
import '../../domain/entities/report_summary.dart';
import '../../domain/usecases/my_page_use_cases.dart';

/// 보호자 리포트 목록의 상태.
class ReportListViewModel extends BaseViewModel {
  ReportListViewModel(this._getReportList, this._markAsRead);

  final GetReportListUseCase _getReportList;
  final MarkReportAsReadUseCase _markAsRead;

  ReportList? _list;

  ReportList? get list => _list;

  List<ReportSummary> get reports => _list?.reports ?? const <ReportSummary>[];

  bool get isEmpty => state.isSuccess && (_list?.isEmpty ?? true);

  Future<void> load() => guard(() async {
    _list = await _getReportList();
  });

  /// 카드를 눌러 상세로 들어가는 순간. **배지를 먼저 지우고** 이동합니다 —
  /// 상세를 보고 돌아왔는데 NEW 가 그대로면 읽은 건지 알 수 없습니다.
  Future<void> markAsRead(String sessionId) async {
    await _markAsRead(sessionId);
    final ReportList? current = _list;
    if (current == null) return;
    final List<ReportSummary> updated = current.reports
        .map(
          (ReportSummary r) =>
              r.sessionId == sessionId ? r.copyWith(isNew: false) : r,
        )
        .toList(growable: false);
    _list = ReportList(
      childName: current.childName,
      totalCount: current.totalCount,
      newCount: updated.where((ReportSummary r) => r.isNew).length,
      reports: updated,
    );
    safeNotify();
  }
}
