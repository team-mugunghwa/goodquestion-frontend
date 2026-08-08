import '../entities/question.dart';

/// 질문 데이터에 대해 **무엇이 필요한지**만 선언합니다.
/// 어떻게 가져오는지(HTTP? 로컬 DB? 목업?)는 data 레이어가 정합니다.
///
/// 이 추상화 덕분에 백엔드가 준비되기 전에도
/// `QuestionRepositoryMock` 을 꽂아 화면을 먼저 만들 수 있습니다.
abstract interface class QuestionRepository {
  /// 질문 목록. [page] 는 **1부터** 시작합니다.
  Future<List<Question>> getQuestions({int page, int size});

  Future<Question> getQuestion(int id);

  Future<Question> createQuestion({
    required String title,
    required String content,
  });
}
