import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../mypage/domain/entities/my_page_summary.dart';
import '../../../mypage/domain/repositories/my_page_repository.dart';
import '../../domain/entities/saved_word.dart';
import '../../domain/entities/word_book.dart';
import '../../domain/entities/word_group.dart';
import '../../domain/repositories/word_repository.dart';
import '../datasources/word_remote_data_source.dart';
import '../dtos/word_response_dto.dart';

/// 단어장을 서버에 붙입니다. `story`·`home` 과 같은 패턴입니다.
/// → `lib/features/story/data/repositories/story_repository_impl.dart`
///
/// ## 이야기별로 묶지 못합니다
///
/// `GET /children/{childId}/words` 는 `sourceSceneId`(장면)만 내려주고
/// 이야기 제목·이미지는 안 줍니다. 그 장면이 어느 이야기인지 되짚으려면
/// 단어마다 장면 조회를 추가로 해야 해서(N+1), 지금은 **단어 전체를 그룹
/// 하나에 담아 평평한 목록으로 보여 줍니다.** 화면·필터 칩 코드는 그대로
/// 두었으니, 서버가 storyId/storyTitle 을 내려주기 시작하면 이 파일만
/// 고치면 됩니다. → `docs/BACKEND_REQUESTS.md`
class WordRepositoryImpl implements WordRepository {
  const WordRepositoryImpl(this._remote, this._childProfileRepository);

  final WordRemoteDataSource _remote;
  final ChildProfileRepository _childProfileRepository;

  static const String _flatGroupId = 'recent';

  @override
  Future<WordBook> getWordBook() => _guard(() async {
    final MyPageChild child = await _resolveChild();
    final List<SavedWord> words = (await _remote.getWords(child.childId))
        .map((Map<String, dynamic> json) => WordResponseDto.fromJson(json).toEntity())
        .toList(growable: false);

    return WordBook(
      totalCount: words.length,
      childName: child.name,
      childAvatar: child.avatar,
      groups: words.isEmpty
          ? const <WordGroup>[]
          : <WordGroup>[
              WordGroup(
                storyId: _flatGroupId,
                storyTitle: '최근 담은 단어',
                words: words,
              ),
            ],
    );
  });

  @override
  Future<bool> toggleLike(String wordId) => _guard(() async {
    final MyPageChild child = await _resolveChild();
    final Map<String, dynamic> json = await _remote.toggleFavorite(
      childId: child.childId,
      wordId: wordId,
    );
    return WordResponseDto.fromJson(json).liked;
  });

  /// 홈·이야기와 같은 방식으로 고릅니다 — selectedChildId 가 있으면 그 아이,
  /// 없으면 첫 번째 아이.
  Future<MyPageChild> _resolveChild() async {
    final List<MyPageChild> children = await _childProfileRepository
        .getChildren();
    if (children.isEmpty) {
      throw const UnknownFailure('아이 프로필을 먼저 만들어 주세요.');
    }
    final String? selectedId = _childProfileRepository.selectedChildId;
    MyPageChild selected = children.first;
    if (selectedId != null) {
      for (final MyPageChild child in children) {
        if (child.childId == selectedId) {
          selected = child;
          break;
        }
      }
    } else {
      await _childProfileRepository.selectChild(selected.childId);
    }
    return selected;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      // ChildProfileRepository(mypage) 는 이미 Failure 를 던집니다.
      rethrow;
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } on Object catch (e) {
      throw Failure.fromException(ParseException('$e'));
    }
  }
}
