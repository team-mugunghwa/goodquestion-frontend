import '../../../../core/error/failure.dart';
import '../../domain/entities/my_page_summary.dart';
import '../../domain/repositories/my_page_repository.dart';

/// `AppConfig.demoMode` 에서만 쓰는 인메모리 아이 프로필 목업.
///
/// `MyPageRepositoryMock` 은 이 인터페이스를 구현하지 않습니다 — 서버 연동
/// 때 새로 생긴 인터페이스라 더미 JSON 출처와 분리돼 있기 때문입니다.
/// 선택 상태를 화면 이동 간에도 유지해야 하므로 lazySingleton 등록을
/// 전제로 만들었습니다.
class ChildProfileRepositoryMock implements ChildProfileRepository {
  ChildProfileRepositoryMock({
    this.latency = const Duration(milliseconds: 300),
  });

  /// 로딩 상태가 실제로 보이도록 일부러 지연을 줍니다.
  final Duration latency;

  final List<MyPageChild> _children = <MyPageChild>[
    const MyPageChild(childId: 'demo-child-1', name: '민준', age: 6),
    const MyPageChild(childId: 'demo-child-2', name: '서연', age: 4),
    const MyPageChild(childId: 'demo-child-3', name: '하은', age: 8),
  ];

  String? _selectedChildId = 'demo-child-1';

  @override
  String? get selectedChildId => _selectedChildId;

  @override
  Future<void> createChild({required String name, required int age}) async {
    await Future<void>.delayed(latency);
    final String childId = 'demo-child-${_children.length + 1}';
    _children.add(MyPageChild(childId: childId, name: name, age: age));
    _selectedChildId = childId;
  }

  @override
  Future<List<MyPageChild>> getChildren() async {
    await Future<void>.delayed(latency);
    return List<MyPageChild>.unmodifiable(_children);
  }

  @override
  Future<void> selectChild(String childId) async {
    await Future<void>.delayed(latency);
    if (!_children.any((MyPageChild child) => child.childId == childId)) {
      throw const UnknownFailure('선택한 아이 프로필을 찾을 수 없습니다.');
    }
    _selectedChildId = childId;
  }
}
