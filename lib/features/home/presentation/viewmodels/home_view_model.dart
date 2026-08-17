import '../../../../core/presentation/base_view_model.dart';
import '../../../mypage/domain/entities/my_page_summary.dart';
import '../../../mypage/domain/usecases/my_page_use_cases.dart';
import '../../domain/entities/home_summary.dart';
import '../../domain/usecases/get_home_summary_use_case.dart';

/// 홈 화면의 상태.
///
/// 홈은 분기가 두 개뿐입니다 — **진행 중 세션이 있는가**, **아이 프로필이
/// 있는가**. 그 외의 판단(진입 차단)은 라우터 게이트가 맡습니다.
/// ViewModel 이 화면 이동을 결정하지 않습니다.
///
/// 아이 전환은 홈 상단 인사말에서 바로 하므로 목록·선택 유스케이스를
/// 함께 듭니다. 전환 뒤에는 그 아이 기준으로 홈을 다시 받습니다.
class HomeViewModel extends BaseViewModel {
  HomeViewModel(this._getHomeSummary, this._getChildren, this._selectChild);

  final GetHomeSummaryUseCase _getHomeSummary;
  final GetMyPageChildrenUseCase _getChildren;
  final SelectMyPageChildUseCase _selectChild;

  HomeSummary? _summary;
  List<MyPageChild> _children = <MyPageChild>[];

  /// 로딩·에러 중에는 `null` 입니다.
  HomeSummary? get summary => _summary;

  /// 이 계정의 아이들. 전환 시트가 씁니다.
  List<MyPageChild> get children => List<MyPageChild>.unmodifiable(_children);

  /// 아이 프로필이 있는지. 이야기 진입 게이트의 판단 근거입니다. (PRD F-01)
  bool get hasChild => _summary?.hasChild ?? false;

  /// 홈 진입·아이 전환·에러 후 재시도에서 모두 이걸 부릅니다.
  Future<void> load() => guard(() async {
    _summary = await _getHomeSummary();
    // 아이 목록은 있으면 좋고 없어도 홈은 그려져야 합니다. 목록 조회가
    // 실패했다고 홈 전체를 에러로 만들지 않습니다.
    try {
      _children = await _getChildren();
    } on Object {
      _children = <MyPageChild>[];
    }
  });

  /// 아이를 바꾸고 홈을 그 아이 기준으로 다시 받습니다.
  Future<void> selectChild(String childId) async {
    await _selectChild(childId);
    await load();
  }
}
