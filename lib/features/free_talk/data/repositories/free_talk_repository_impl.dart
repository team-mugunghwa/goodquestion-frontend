import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../mypage/domain/entities/my_page_summary.dart';
import '../../../mypage/domain/repositories/my_page_repository.dart';
import '../../domain/entities/free_talk.dart';
import '../../domain/repositories/free_talk_repository.dart';
import '../datasources/free_talk_remote_data_source.dart';

/// 자유 대화 저장소.
///
/// 인물 목록·시작 경로에만 `childId` 가 필요합니다. 단어장·리포트와 같은
/// 방식으로 [ChildProfileRepository] 에서 고른 아이를 가져옵니다 — 화면이
/// 아이 식별자를 들고 다니면 아이를 바꾼 뒤 옛 값으로 요청하게 됩니다.
class FreeTalkRepositoryImpl implements FreeTalkRepository {
  const FreeTalkRepositoryImpl(this._remote, this._children);

  final FreeTalkRemoteDataSource _remote;
  final ChildProfileRepository _children;

  @override
  Future<List<FreeTalkCharacter>> characters(String storyId) =>
      _guard(() async {
        final MyPageChild child = await _selectedChild();
        return _remote.characters(childId: child.childId, storyId: storyId);
      });

  @override
  Future<FreeTalkSession> start({
    required String storyId,
    required String characterId,
  }) => _guard(() async {
    final MyPageChild child = await _selectedChild();
    return _remote.start(
      childId: child.childId,
      storyId: storyId,
      characterId: characterId,
    );
  });

  @override
  Future<FreeTalkTurn> sendMessage(
    String freeTalkId, {
    required String text,
    String? idempotencyKey,
  }) => _guard(
    () => _remote.sendMessage(
      freeTalkId,
      text: text,
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<FreeTalkSpeech> end(String freeTalkId) =>
      _guard(() => _remote.end(freeTalkId));

  Future<MyPageChild> _selectedChild() async {
    final List<MyPageChild> children = await _children.getChildren();
    if (children.isEmpty) {
      throw const UnknownFailure('아이 프로필을 먼저 만들어 주세요.');
    }
    final String? selectedId = _children.selectedChildId;
    for (final MyPageChild child in children) {
      if (child.childId == selectedId) return child;
    }
    final MyPageChild child = children.first;
    await _children.selectChild(child.childId);
    return child;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      rethrow;
    } on AppException catch (error) {
      throw Failure.fromException(error);
    } on Object catch (error) {
      throw Failure.fromException(ParseException('$error'));
    }
  }
}
