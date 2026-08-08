import '../../../../core/error/failure.dart';
import '../../domain/entities/question.dart';
import '../../domain/repositories/question_repository.dart';
import '../datasources/question_remote_data_source.dart';
import '../dtos/question_dto.dart';

/// domain 의 추상 Repository 를 실제 서버 통신으로 구현합니다.
///
/// 이 클래스의 책임 두 가지:
/// 1. DTO → Entity 변환
/// 2. data 레이어 예외 → domain 의 [Failure] 로 번역
class QuestionRepositoryImpl implements QuestionRepository {
  const QuestionRepositoryImpl(this._remote);

  final QuestionRemoteDataSource _remote;

  @override
  Future<List<Question>> getQuestions({int page = 1, int size = 20}) async {
    try {
      final response = await _remote.fetchQuestions(page: page, size: size);
      return response.items
          .map((dto) => dto.toEntity())
          .toList(growable: false);
    } catch (e) {
      throw Failure.fromException(e);
    }
  }

  @override
  Future<Question> getQuestion(int id) async {
    try {
      final dto = await _remote.fetchQuestion(id);
      return dto.toEntity();
    } catch (e) {
      throw Failure.fromException(e);
    }
  }

  @override
  Future<Question> createQuestion({
    required String title,
    required String content,
  }) async {
    try {
      final dto = await _remote.createQuestion(
        CreateQuestionRequest(title: title, content: content),
      );
      return dto.toEntity();
    } catch (e) {
      throw Failure.fromException(e);
    }
  }
}
