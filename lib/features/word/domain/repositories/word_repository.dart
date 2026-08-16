import 'dart:typed_data';

import '../entities/sentence_practice.dart';
import '../entities/word_book.dart';

/// 담아 둔 단어의 출처.
abstract class WordRepository {
  /// 현재 아이가 담은 단어를 이야기별로 묶어서 가져옵니다.
  Future<WordBook> getWordBook();

  /// 좋아요를 켜고 끕니다. 바뀐 값을 돌려줍니다.
  ///
  /// 서버에서는 좋아요가 **단어의 분류**입니다 — `UNKNOWN`(모르는 말) 과
  /// `FAVORITE`(좋아하는 말) 을 오갑니다. 화면은 하트 하나로 보여 주고,
  /// 목록은 분류로 거르지 않습니다. 거르면 하트를 누른 단어가 목록에서
  /// 사라져 아이가 자기가 지운 줄 압니다. → `docs/API.md` 2.12
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
