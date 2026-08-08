import '../entities/question.dart';
import '../repositories/question_repository.dart';

/// 질문 목록 조회.
///
/// UseCase 는 **동작 하나 = 클래스 하나**, 진입점은 `call()` 하나입니다.
///
/// 지금은 Repository 를 그대로 통과시키기만 해서 불필요해 보일 수 있습니다.
/// 그래도 두는 이유: 나중에 캐싱·권한 검사·여러 Repository 조합이 들어갈
/// 자리가 정해져 있어야 4명이 같은 곳에 코드를 넣습니다.
class GetQuestionsUseCase {
  const GetQuestionsUseCase(this._repository);

  final QuestionRepository _repository;

  Future<List<Question>> call({int page = 1, int size = 20}) =>
      _repository.getQuestions(page: page, size: size);
}
