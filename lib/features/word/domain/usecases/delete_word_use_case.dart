import '../repositories/word_repository.dart';

/// 단어를 지웁니다. 목록 화면에서 확인을 받은 뒤에만 부릅니다.
class DeleteWordUseCase {
  const DeleteWordUseCase(this._repository);

  final WordRepository _repository;

  Future<void> call(String wordId) => _repository.deleteWord(wordId);
}
