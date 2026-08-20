import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/storage/selected_child_store.dart';
import '../../../../core/util/child_age.dart';
import '../../domain/entities/my_page_summary.dart';
import '../../domain/repositories/my_page_repository.dart';
import '../datasources/child_profile_remote_data_source.dart';
import '../dtos/my_page_dto.dart';

class MyPageRepositoryImpl implements MyPageRepository, ChildProfileRepository {
  MyPageRepositoryImpl(this._remote, {SelectedChildStore? selectedChild})
    : _selected = selectedChild ?? SelectedChildStore();

  final ChildProfileRemoteDataSource _remote;

  /// 고른 아이는 기기에 남습니다 - 새로고침해도 그 아이로 돌아옵니다.
  final SelectedChildStore _selected;

  @override
  String? get selectedChildId => _selected.value;

  @override
  Future<MyPageSummary> getSummary() async {
    try {
      final List<MyPageChild> children = await _fetchChildren();
      final MyPageChild? current = await _currentChild(children);
      // 아이를 고르지 않았으면 부를 대상이 없습니다.
      final ChildActivityDto? activity = current == null
          ? null
          : await _activity(current.childId);
      return MyPageSummary(
        child: current,
        childCount: children.length,
        completedStories: activity?.completedStories ?? 0,
        stardust: activity?.stardust ?? 0,
      );
    } on AppException catch (error) {
      throw Failure.fromException(error);
    }
  }

  /// 아이를 만들고 **곧바로 동의를 기록합니다.**
  ///
  /// 동의 기록이 없으면 그 아이로 이야기를 시작할 때 서버가
  /// `CONSENT_REQUIRED`(409) 로 막습니다. 아이를 먼저 만들어야 childId 가
  /// 나오므로 순서를 뒤집을 수는 없고, 대신 **동의까지 끝나야 성공**으로
  /// 칩니다.
  ///
  /// 동의만 실패하면 한 번 더 시도합니다(끊긴 연결·순간 오류가 대부분입니다).
  /// 그래도 실패하면 실패로 올리고 **새 아이를 고르지 않습니다** - 반쯤
  /// 만들어진 아이로 화면을 바꿔 두면 보호자가 그 아이로 이야기를 시작했다가
  /// 409 를 만납니다. 아이는 서버에 남으므로, 다시 추가하지 말고 그 아이를
  /// 골라 다시 시도하면 됩니다.
  @override
  Future<void> createChild({required String name, required int age}) async {
    try {
      final Map<String, dynamic> created = await _remote.createChild(
        name: name.trim(),
        birthYear: birthYearFromAge(age),
      );
      final String childId = _toChild(created).childId;
      await _saveConsentWithRetry(childId);
      await _selected.save(childId);
    } on AppException catch (error) {
      throw Failure.fromException(error);
    }
  }

  Future<void> _saveConsentWithRetry(String childId) async {
    try {
      await _remote.saveConsent(childId);
    } on AppException {
      await _remote.saveConsent(childId);
    }
  }

  @override
  Future<void> updateChild({
    required String childId,
    required String name,
    required int age,
  }) async {
    try {
      // 화면은 나이를 받고 서버는 출생연도만 압니다. 아이 등록과 **같은 식**을
      // 써야 같은 아이의 연도가 어긋나지 않습니다. → [birthYearFromAge]
      await _remote.updateChild(
        childId,
        name: name.trim(),
        birthYear: birthYearFromAge(age),
      );
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
    await _selected.save(childId);
  }

  /// 완주 편수·별가루. **실패해도 두 값을 0 으로 두고 넘어갑니다.**
  ///
  /// 이 화면은 프로필·리포트·설정으로 가는 허브입니다. 숫자를 못 받아
  /// 왔다고 화면 전체를 에러로 바꾸면 보호자는 아무 데도 가지 못합니다.
  /// (0 과 "못 받아 왔다"가 화면에서 같아 보이는 것은 감수합니다 - 요약에
  /// 실패 표시를 새로 만드는 것은 이 화면이 하려는 일이 아닙니다)
  Future<ChildActivityDto?> _activity(String childId) async {
    try {
      return await _remote.getActivity(childId);
    } on AppException {
      return null;
    }
  }

  Future<List<MyPageChild>> _fetchChildren() async =>
      (await _remote.getChildren()).map(_toChild).toList(growable: false);

  /// 저장된 아이가 목록에 없으면(지워졌거나 다른 계정으로 로그인했으면)
  /// 첫 번째 아이로 되돌립니다 - 그 값을 그대로 쓰면 남의 아이를 부릅니다.
  Future<MyPageChild?> _currentChild(List<MyPageChild> children) async {
    if (children.isEmpty) return null;
    final String? selectedId = _selected.value;
    if (selectedId != null) {
      for (final MyPageChild child in children) {
        if (child.childId == selectedId) return child;
      }
    }
    await _selected.save(children.first.childId);
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
      age: responseAge ?? ageFromBirthYear(birthYear!),
    );
  }
}
