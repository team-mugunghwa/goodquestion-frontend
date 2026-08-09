import '../../../../core/presentation/base_view_model.dart';
import '../../domain/entities/home_summary.dart';
import '../../domain/usecases/get_home_summary_use_case.dart';

/// 홈 화면의 상태.
///
/// 홈은 분기가 두 개뿐입니다 — **진행 중 세션이 있는가**, **아이 프로필이
/// 있는가**. 그 외의 판단(프로필 전환, 진입 차단)은 모달과 라우터 게이트가
/// 맡습니다. ViewModel 이 화면 이동을 결정하지 않습니다.
class HomeViewModel extends BaseViewModel {
  HomeViewModel(this._getHomeSummary);

  final GetHomeSummaryUseCase _getHomeSummary;

  HomeSummary? _summary;

  /// 로딩·에러 중에는 `null` 입니다.
  HomeSummary? get summary => _summary;

  /// 아이 프로필이 있는지. 이야기 진입 게이트의 판단 근거입니다. (PRD F-01)
  bool get hasChild => _summary?.hasChild ?? false;

  /// 홈 진입·아이 전환·에러 후 재시도에서 모두 이걸 부릅니다.
  Future<void> load() => guard(() async {
    _summary = await _getHomeSummary();
  });
}
