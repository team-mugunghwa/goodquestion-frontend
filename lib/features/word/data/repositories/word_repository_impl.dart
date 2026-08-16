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

/// 서버의 단어장을 화면 모델로 만듭니다.
///
/// ## 묶는 일은 여기서 합니다
///
/// 서버는 단어를 **평면 목록**으로 최신순으로만 줍니다. 이야기별 묶음은 이
/// 클래스가 만듭니다 — 응답 구조를 바꾸면 저장·즐겨찾기 응답까지 같이
/// 흔들리기 때문에 서버는 그대로 두기로 했습니다. → `docs/API.md` 2.12
///
/// ## 이야기 정보가 없을 수 있습니다
///
/// 장면 없이 저장된 단어는 `storyId` 가 `null` 입니다. 이런 단어는 이름 없는
/// 묶음 하나로 모으고, **화면이 헤더와 필터 칩을 그리지 않습니다** —
/// 붙일 이름이 없는데 지어내면 아이가 그걸 이야기 제목으로 읽습니다.
class WordRepositoryImpl implements WordRepository {
  WordRepositoryImpl(this._remote, this._children);

  final WordRemoteDataSource _remote;
  final ChildProfileRepository _children;

  @override
  Future<WordBook> getWordBook() => _guard(() async {
    final MyPageChild child = await _selectedChild();
    final List<WordResponseDto> words = await _remote.fetchWords(child.childId);
    return WordBook(
      // 서버가 개수를 따로 주지 않아 받은 목록으로 셉니다.
      totalCount: words.length,
      childName: child.name,
      childAvatar: child.avatar,
      groups: _group(words),
    );
  });

  @override
  Future<bool> toggleLike(String wordId) => _guard(() async {
    final MyPageChild child = await _selectedChild();
    final WordResponseDto updated = await _remote.toggleFavorite(
      child.childId,
      wordId,
    );
    return updated.liked;
  });

  /// 서버 순서(최신순)를 그대로 두고 **처음 나온 이야기 순서로** 묶습니다.
  /// 정렬을 다시 하지 않습니다 — 최근에 담은 이야기가 위에 오는 게 서버의
  /// 순서이고, 앱이 다시 정렬하면 기준이 두 곳에 생깁니다.
  List<WordGroup> _group(List<WordResponseDto> words) {
    final List<String> order = <String>[];
    final Map<String, WordResponseDto> heads = <String, WordResponseDto>{};
    final Map<String, List<SavedWord>> buckets = <String, List<SavedWord>>{};

    for (final WordResponseDto dto in words) {
      final String key = dto.storyId ?? WordGroup.noStory;
      if (!buckets.containsKey(key)) {
        order.add(key);
        heads[key] = dto;
        buckets[key] = <SavedWord>[];
      }
      buckets[key]!.add(_toEntity(dto));
    }

    return order
        .map((String key) {
          final WordResponseDto head = heads[key]!;
          return WordGroup(
            storyId: head.storyId,
            // 이름을 지어내지 않습니다. 비어 있으면 화면이 헤더를 안 그립니다.
            storyTitle: head.storyTitle ?? '',
            storyImage: head.storyImageUrl,
            words: buckets[key]!,
          );
        })
        .toList(growable: false);
  }

  SavedWord _toEntity(WordResponseDto dto) => SavedWord(
    wordId: dto.id,
    word: dto.word,
    meaning: dto.meaning ?? '',
    sentence: dto.exampleSentence ?? '',
    sentenceDaily: dto.exampleSentenceDaily,
    sentenceAdvanced: dto.exampleSentenceAdvanced,
    liked: dto.liked,
    // 서버에는 단어 음성이 없습니다. 화면은 기기 내장 목소리로 읽어 줍니다.
    // → `docs/DECISIONS.md` 019
    audio: null,
    savedAt: dto.createdAt,
  );

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
