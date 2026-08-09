import '../entities/word_book.dart';
import '../repositories/word_repository.dart';

/// 단어장 진입·재시도에서 부릅니다.
class GetWordBookUseCase {
  const GetWordBookUseCase(this._repository);

  final WordRepository _repository;

  Future<WordBook> call() => _repository.getWordBook();
}
