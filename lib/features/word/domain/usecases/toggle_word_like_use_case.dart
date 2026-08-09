import '../repositories/word_repository.dart';

/// 단어 좋아요를 켜고 끕니다. 상세 모달에서만 부릅니다.
class ToggleWordLikeUseCase {
  const ToggleWordLikeUseCase(this._repository);

  final WordRepository _repository;

  Future<bool> call(int wordId) => _repository.toggleLike(wordId);
}
