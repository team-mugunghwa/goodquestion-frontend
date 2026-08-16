import 'dart:typed_data';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/saved_word.dart';
import '../../domain/entities/sentence_practice.dart';
import '../../domain/entities/word_book.dart';
import '../../domain/entities/word_group.dart';
import '../../domain/repositories/word_repository.dart';
import '../datasources/word_local_data_source.dart';
import '../dtos/word_response_dto.dart';

/// 서버 없이 단어장을 번들 더미에서 읽는 구현.
///
/// 좋아요와 따라 말하기 보상은 **메모리에만** 남습니다. 앱을 다시 켜면 더미
/// 값으로 돌아가는데, 그게 목업의 정직한 동작입니다. 로컬 저장소에 흉내를
/// 내 두면 나중에 서버 값과 어긋나는 걸 디버깅하게 됩니다.
class WordRepositoryMock implements WordRepository {
  WordRepositoryMock(
    this._localDataSource, {
    this.latency = const Duration(milliseconds: 400),
  });

  final WordLocalDataSource _localDataSource;
  final Duration latency;

  /// 더미에는 아이 정보가 없어서(서버 응답과 1:1) 헤더용 이름만 흉내 냅니다.
  static const String _childName = '하늘이';

  /// wordId → 좋아요. 더미 값 위에 덮어씁니다.
  final Map<String, bool> _likeOverrides = <String, bool>{};

  /// 이미 별가루를 준 "wordId/예문 종류". 실제 규칙 중
  /// "한 문장당 한 번"만 흉내 냅니다. (하루 한도는 목업에서 생략)
  final Set<String> _rewardedSentences = <String>{};

  int _stardustBalance = 20;

  @override
  Future<WordBook> getWordBook() async {
    await Future<void>.delayed(latency);
    try {
      return WordBook.fromWords(
        (await _fetchWords()).toList(growable: false),
        childName: _childName,
      );
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } on Object catch (e) {
      throw Failure.fromException(ParseException('$e'));
    }
  }

  @override
  Future<bool> toggleLike(String wordId) async {
    final bool current = (await _findWord(wordId))?.liked ?? false;
    final bool next = !current;
    _likeOverrides[wordId] = next;
    return next;
  }

  @override
  Future<SentencePracticeResult> practiceSentence({
    required String wordId,
    required SentenceType sentenceType,
    required String spokenText,
  }) async {
    final SavedWord? word = await _findWord(wordId);
    if (word == null) {
      throw const ServerFailure(message: '단어를 찾을 수 없습니다.', code: 'NOT_FOUND');
    }
    final String? target = word.sentenceOf(sentenceType)?.trim();
    if (target == null || target.isEmpty) {
      // 예문 확장 전에 담은 단어. 서버와 같은 코드로 거절합니다.
      throw const ServerFailure(
        message: '이 종류의 예문이 없습니다.',
        code: 'EXAMPLE_SENTENCE_MISSING',
      );
    }
    // 채점 서버가 없으니 항상 정답으로 칩니다. 보상 규칙 중
    // "한 문장당 한 번"만 흉내 내서 결과 화면 분기를 눈으로 볼 수 있게 합니다.
    final String key = '$wordId/${sentenceType.serverValue}';
    final bool rewarded = _rewardedSentences.add(key);
    if (rewarded) _stardustBalance += 2;
    return SentencePracticeResult(
      matched: true,
      similarity: 0.95,
      targetSentence: target,
      rewarded: rewarded,
      skipReason: rewarded ? null : SentencePracticeSkipReason.alreadyRewarded,
      stardustAmount: rewarded ? 2 : 0,
      stardustBalance: _stardustBalance,
    );
  }

  @override
  Future<String> transcribe(Uint8List wavBytes) async {
    await Future<void>.delayed(latency);
    // 인식 서버가 없어 고정 문구를 돌려줍니다. 목업 채점이 어차피 항상
    // 정답이라 화면 흐름을 보는 데는 지장이 없습니다.
    return '따라 말해 본 문장이에요';
  }

  Future<SavedWord?> _findWord(String wordId) async {
    final WordBook book = await getWordBook();
    for (final WordGroup group in book.groups) {
      for (final SavedWord word in group.words) {
        if (word.wordId == wordId) return word;
      }
    }
    return null;
  }

  Future<Iterable<SavedWord>> _fetchWords() async =>
      (await _localDataSource.fetchWords()).map((WordResponseDto dto) {
        final SavedWord word = dto.toEntity();
        final bool? liked = _likeOverrides[word.wordId];
        return liked == null ? word : word.copyWith(liked: liked);
      });
}
