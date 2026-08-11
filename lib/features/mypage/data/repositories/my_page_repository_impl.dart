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
        completedStories: 0,
        stardust: 0,
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
