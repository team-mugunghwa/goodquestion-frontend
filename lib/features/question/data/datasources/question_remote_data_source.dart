import '../../../../core/network/api_response.dart';
import '../../../../core/network/dio_client.dart';
import '../dtos/question_dto.dart';

/// 질문 관련 HTTP 호출만 담당합니다.
///
/// 여기서는 **예외를 잡지 않습니다.** `DioClient` 가 던진 예외를 그대로 위로
/// 올리고, `RepositoryImpl` 이 `Failure` 로 번역합니다.
class QuestionRemoteDataSource {
  const QuestionRemoteDataSource(this._client);

  final DioClient _client;

  static const String _path = '/questions';

  Future<PageResponse<QuestionDto>> fetchQuestions({
    required int page,
    required int size,
  }) => _client.get(
    _path,
    queryParameters: {'page': page, 'size': size},
    parse: (data) => PageResponse.fromJson(
      data as Map<String, dynamic>,
      QuestionDto.fromJson,
    ),
  );

  Future<QuestionDto> fetchQuestion(int id) => _client.get(
    '$_path/$id',
    parse: (data) => QuestionDto.fromJson(data as Map<String, dynamic>),
  );

  Future<QuestionDto> createQuestion(CreateQuestionRequest request) =>
      _client.post(
        _path,
        body: request.toJson(),
        parse: (data) => QuestionDto.fromJson(data as Map<String, dynamic>),
      );
}
