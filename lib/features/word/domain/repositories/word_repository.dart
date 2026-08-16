import 'dart:typed_data';

import '../entities/sentence_practice.dart';
import '../entities/word_book.dart';

/// 담아 둔 단어의 출처.
///
/// childId 는 여기서 받지 않습니다 - 홈/이야기와 같은 방식으로 구현체가
/// `ChildProfileRepository` 에서 현재 아이를 해석합니다.
abstract class WordRepository {
  /// 현재 아이가 담은 단어를 이야기별로 묶어서 가져옵니다.
  Future<WordBook> getWordBook();

  /// 좋아요를 켜고 끕니다. 바뀐 값을 돌려줍니다.
  Future<bool> toggleLike(String wordId);

  /// 아이가 따라 말한 문장을 서버에 채점받습니다.
  ///
  /// 해당 종류의 예문이 없는 단어면 `ServerFailure` 코드
  /// `EXAMPLE_SENTENCE_MISSING` 이 옵니다. (예문 확장 전에 담은 단어)
  Future<SentencePracticeResult> practiceSentence({
    required String wordId,
    required SentenceType sentenceType,
    required String spokenText,
  });

  /// 녹음(WAV)을 글자로 바꿉니다. 알아듣지 못했으면 예외를 던집니다.
  Future<String> transcribe(Uint8List wavBytes);
}
