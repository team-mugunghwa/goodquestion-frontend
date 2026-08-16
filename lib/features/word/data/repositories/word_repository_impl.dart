import 'dart:typed_data';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../mypage/domain/entities/my_page_summary.dart';
import '../../../mypage/domain/repositories/my_page_repository.dart';
import '../../domain/entities/saved_word.dart';
import '../../domain/entities/sentence_practice.dart';
import '../../domain/entities/word_book.dart';
import '../../domain/entities/word_group.dart';
import '../../domain/repositories/word_repository.dart';
import '../datasources/word_remote_data_source.dart';
import '../dtos/word_response_dto.dart';

/// 단어장을 서버에 붙입니다.
///
/// `WordResponse` 목록에는 아이 정보가 없어서, 홈/이야기와 같은 방식으로
/// [ChildProfileRepository] 에서 현재 아이를 정합니다.
/// -> `lib/features/story/data/repositories/story_repository_impl.dart`
class WordRepositoryImpl implements WordRepository {
  const WordRepositoryImpl(this._remote, this._childProfileRepository);

  final WordRemoteDataSource _remote;
  final ChildProfileRepository _childProfileRepository;

  @override
  Future<WordBook> getWordBook() => _guard(() async {
    final List<MyPageChild> children = await _childProfileRepository
        .getChildren();
    if (children.isEmpty) {
      // 아이 프로필이 없으면 담은 단어도 없습니다. 빈 단어장을 돌려주면
      // 화면이 "이야기 하러 가기"로 안내합니다.
      return const WordBook(totalCount: 0, groups: <WordGroup>[]);
    }
    final MyPageChild selected = await _resolveSelected(children);
    final List<SavedWord> words = (await _remote.fetchWords(
      selected.childId,
    )).map((WordResponseDto dto) => dto.toEntity()).toList(growable: false);
    return WordBook.fromWords(
      words,
      childName: selected.name,
      childAvatar: selected.avatar,
    );
  });

  @override
  Future<bool> toggleLike(String wordId) => _guard(() async {
    final String childId = await _requireChildId();
    return (await _remote.toggleFavorite(childId, wordId)).toEntity().liked;
  });

  @override
  Future<SentencePracticeResult> practiceSentence({
    required String wordId,
    required SentenceType sentenceType,
    required String spokenText,
  }) => _guard(() async {
    final String childId = await _requireChildId();
    return (await _remote.practiceSentence(
      childId,
      wordId,
      sentenceType: sentenceType.serverValue,
      spokenText: spokenText,
    )).toEntity();
  });

  @override
  Future<String> transcribe(Uint8List wavBytes) =>
      _guard(() => _remote.transcribe(wavBytes));

  Future<String> _requireChildId() async {
    final List<MyPageChild> children = await _childProfileRepository
        .getChildren();
    if (children.isEmpty) {
      throw const UnknownFailure('아이 프로필을 먼저 만들어 주세요.');
    }
    return (await _resolveSelected(children)).childId;
  }

  /// 홈과 같은 규칙입니다 - selectedChildId 가 목록에 있으면 그 아이,
  /// 없으면 첫 번째 아이를 고르고 선택을 기록합니다.
  Future<MyPageChild> _resolveSelected(List<MyPageChild> children) async {
    final String? selectedId = _childProfileRepository.selectedChildId;
    if (selectedId == null) {
      await _childProfileRepository.selectChild(children.first.childId);
      return children.first;
    }
    for (final MyPageChild child in children) {
      if (child.childId == selectedId) return child;
    }
    return children.first;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on Failure {
      // ChildProfileRepository(mypage) 는 이미 Failure 를 던집니다.
      // 여기서 다시 AppException 으로 감싸면 이중 래핑입니다.
      rethrow;
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } on Object catch (e) {
      throw Failure.fromException(ParseException('$e'));
    }
  }
}
