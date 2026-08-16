import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/my_page_summary.dart';
import '../../domain/repositories/my_page_repository.dart';
import '../datasources/child_profile_remote_data_source.dart';

class MyPageRepositoryImpl implements MyPageRepository, ChildProfileRepository {
  MyPageRepositoryImpl(this._remote);

  final ChildProfileRemoteDataSource _remote;
  String? _selectedChildId;

  @override
  String? get selectedChildId => _selectedChildId;

  @override
  Future<MyPageSummary> getSummary() async {
    try {
      final List<MyPageChild> children = await _fetchChildren();
      final MyPageChild? current = _currentChild(children);
      return MyPageSummary(
        child: current,
        childCount: children.length,
        // 완주 편수를 주는 엔드포인트가 아직 없습니다. 리포트 목록 개수로
        // 세지 않습니다 - 리포트 생성이 비동기라 완주 직후에는 어긋납니다.
        completedStories: 0,
        // 아이를 고르지 않았으면 부를 대상이 없습니다.
        stardust: current == null ? 0 : await _stardustBalance(current.childId),
        // 리포트 목록 응답(`id·sessionId·storyTitle·createdAt`)에 안 읽음을
        // 가릴 값이 없습니다. 지금 목록 화면의 NEW 배지는 앱이 들고 있는
        // 열람 기록으로 만듭니다.
        hasNewReport: false,
      );
    } on AppException catch (error) {
      throw Failure.fromException(error);
    }
  }

  @override
  Future<void> createChild({required String name, required int age}) async {
    try {
      final Map<String, dynamic> created = await _remote.createChild(
        name: name.trim(),
        birthYear: DateTime.now().year - age,
      );
      _selectedChildId = _toChild(created).childId;
    } on AppException catch (error) {
      throw Failure.fromException(error);
    }
  }

  @override
  Future<List<MyPageChild>> getChildren() async {
    try {
      return await _fetchChildren();
    } on AppException catch (error) {
      throw Failure.fromException(error);
    }
  }

  @override
  Future<void> selectChild(String childId) async {
    final List<MyPageChild> children = await getChildren();
    if (!children.any((MyPageChild child) => child.childId == childId)) {
      throw const UnknownFailure('선택한 아이 프로필을 찾을 수 없습니다.');
    }
    _selectedChildId = childId;
  }

  /// 별가루 잔액. **실패해도 0 으로 두고 넘어갑니다.**
  ///
  /// 이 화면은 프로필·리포트·설정으로 가는 허브입니다. 숫자 하나를 못 받아
  /// 왔다고 화면 전체를 에러로 바꾸면 보호자는 아무 데도 가지 못합니다.
  /// (0 과 "못 받아 왔다"가 화면에서 같아 보이는 것은 감수합니다 - 요약에
  /// 실패 표시를 새로 만드는 것은 이 화면이 하려는 일이 아닙니다)
  Future<int> _stardustBalance(String childId) async {
    try {
      return await _remote.getStardustBalance(childId);
    } on AppException {
      return 0;
    }
  }

  Future<List<MyPageChild>> _fetchChildren() async =>
      (await _remote.getChildren()).map(_toChild).toList(growable: false);

  MyPageChild? _currentChild(List<MyPageChild> children) {
    if (children.isEmpty) return null;
    final String? selectedId = _selectedChildId;
    if (selectedId != null) {
      for (final MyPageChild child in children) {
        if (child.childId == selectedId) return child;
      }
    }
    _selectedChildId = children.first.childId;
    return children.first;
  }

  MyPageChild _toChild(Map<String, dynamic> json) {
    final String id = json['id']?.toString() ?? '';
    final String name = json['name'] as String? ?? '';
    final int? responseAge = (json['age'] as num?)?.toInt();
    final int? birthYear = (json['birthYear'] as num?)?.toInt();
    if (id.isEmpty ||
        name.isEmpty ||
        (responseAge == null && birthYear == null)) {
      throw const ParseException('아이 정보 응답 형식이 올바르지 않습니다.');
    }
    return MyPageChild(
      childId: id,
      name: name,
      age: responseAge ?? DateTime.now().year - birthYear!,
    );
  }
}
