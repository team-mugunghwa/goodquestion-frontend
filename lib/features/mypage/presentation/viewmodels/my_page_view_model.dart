import '../../../../core/error/failure.dart';
import '../../../../core/presentation/base_view_model.dart';
import '../../domain/entities/my_page_summary.dart';
import '../../domain/usecases/my_page_use_cases.dart';

/// 마이페이지 허브의 상태.
///
/// 이 화면은 **허브**입니다. 리포트 내용도 프로필 폼도 여기서 펼치지 않고
/// 모달·하위 라우트로 넘깁니다. 그래서 ViewModel 도 요약 하나만 듭니다.
class MyPageViewModel extends BaseViewModel {
  MyPageViewModel(
    this._getSummary,
    this._createChild,
    this._updateChild,
    this._getChildren,
    this._selectChild,
  );

  final GetMyPageSummaryUseCase _getSummary;
  final CreateMyPageChildUseCase _createChild;
  final UpdateMyPageChildUseCase _updateChild;
  final GetMyPageChildrenUseCase _getChildren;
  final SelectMyPageChildUseCase _selectChild;

  MyPageSummary? _summary;
  List<MyPageChild> _children = <MyPageChild>[];

  MyPageSummary? get summary => _summary;
  List<MyPageChild> get children => List<MyPageChild>.unmodifiable(_children);
  bool _isSavingChild = false;
  String? _childSaveError;

  bool get isSavingChild => _isSavingChild;
  String? get childSaveError => _childSaveError;

  /// 아이 프로필이 0명인가. 이때 리포트 메뉴는 비활성입니다 — 볼 게 없습니다.
  bool get hasChild => _summary?.hasChild ?? false;

  Future<void> load() => guard(() async {
    _summary = await _getSummary();
    _children = await _getChildren();
  });

  Future<bool> addChild({required String name, required int age}) =>
      _saveChild(() => _createChild(name: name.trim(), age: age));

  /// 이미 있는 아이를 고칩니다. **[childId] 가 있어야** 새로 만들지 않고
  /// 그 아이를 고칩니다.
  Future<bool> updateChild({
    required String childId,
    required String name,
    required int age,
  }) => _saveChild(
    () => _updateChild(childId: childId, name: name.trim(), age: age),
  );

  /// 추가와 수정이 같은 뒷정리를 씁니다 - 저장 중 표시, 실패 메시지,
  /// 그리고 성공하면 요약·목록을 다시 읽어 화면을 맞춥니다.
  Future<bool> _saveChild(Future<void> Function() save) async {
    if (_isSavingChild) return false;
    _isSavingChild = true;
    _childSaveError = null;
    safeNotify();
    try {
      await save();
      _summary = await _getSummary();
      _children = await _getChildren();
      return true;
    } catch (error) {
      _childSaveError = error is Failure
          ? error.message
          : Failure.fromException(error).message;
      return false;
    } finally {
      _isSavingChild = false;
      safeNotify();
    }
  }

  Future<bool> switchChild(String childId) async {
    try {
      await _selectChild(childId);
      _summary = await _getSummary();
      _children = await _getChildren();
      safeNotify();
      return true;
    } catch (error) {
      _childSaveError = error is Failure
          ? error.message
          : Failure.fromException(error).message;
      safeNotify();
      return false;
    }
  }
}
