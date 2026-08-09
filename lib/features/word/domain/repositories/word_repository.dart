import '../entities/word_book.dart';

/// 담아 둔 단어의 출처.
abstract class WordRepository {
  /// 현재 아이가 담은 단어를 이야기별로 묶어서 가져옵니다.
  Future<WordBook> getWordBook();

  /// 좋아요를 켜고 끕니다. 바뀐 값을 돌려줍니다.
  ///
  /// 서버가 붙기 전에는 메모리에만 남습니다 — 앱을 다시 켜면 더미 값으로
  /// 돌아갑니다. 그게 목업의 정직한 동작입니다.
  Future<bool> toggleLike(int wordId);
}
