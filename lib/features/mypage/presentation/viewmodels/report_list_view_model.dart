import '../../../../core/presentation/base_view_model.dart';
import '../../domain/entities/report_summary.dart';
import '../../domain/usecases/my_page_use_cases.dart';

/// 보호자 리포트 목록의 상태.
class ReportListViewModel extends BaseViewModel {
  ReportListViewModel(this._getReportList);

  final GetReportListUseCase _getReportList;

  ReportList? _list;

  ReportList? get list => _list;

  List<ReportSummary> get reports => _list?.reports ?? const <ReportSummary>[];

  bool get isEmpty => state.isSuccess && (_list?.isEmpty ?? true);

  Future<void> load() => guard(() async {
    _list = await _getReportList();
  });
}
