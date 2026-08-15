import '../../../../core/presentation/base_view_model.dart';
import '../../domain/entities/report_detail.dart';
import '../../domain/usecases/my_page_use_cases.dart';

/// 보호자 리포트 상세의 상태.
///
/// 아직 분석이 안 끝난 세션(`null`)과 로드 실패는 **다른 화면**입니다.
/// 전자는 "만들고 있어요", 후자는 "다시 시도" 입니다.
class ReportDetailViewModel extends BaseViewModel {
  ReportDetailViewModel(this._getReportDetail, {required this.sessionId});

  final GetReportDetailUseCase _getReportDetail;
  final String sessionId;

  ReportDetail? _report;

  ReportDetail? get report => _report;

  /// 로드는 됐는데 리포트가 아직 없는 경우.
  bool get isPending => state.isSuccess && _report == null;

  Future<void> load() => guard(() async {
    _report = await _getReportDetail(sessionId);
  });
}
