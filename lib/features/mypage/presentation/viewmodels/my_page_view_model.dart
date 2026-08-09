import '../../../../core/presentation/base_view_model.dart';
import '../../domain/entities/my_page_summary.dart';
import '../../domain/usecases/my_page_use_cases.dart';

/// 마이페이지 허브의 상태.
///
/// 이 화면은 **허브**입니다. 리포트 내용도 프로필 폼도 여기서 펼치지 않고
/// 모달·하위 라우트로 넘깁니다. 그래서 ViewModel 도 요약 하나만 듭니다.
class MyPageViewModel extends BaseViewModel {
  MyPageViewModel(this._getSummary);

  final GetMyPageSummaryUseCase _getSummary;

  MyPageSummary? _summary;

  MyPageSummary? get summary => _summary;

  /// 아이 프로필이 0명인가. 이때 리포트 메뉴는 비활성입니다 — 볼 게 없습니다.
  bool get hasChild => _summary?.hasChild ?? false;

  Future<void> load() => guard(() async {
    _summary = await _getSummary();
  });
}
