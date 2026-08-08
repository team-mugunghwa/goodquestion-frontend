import '../../domain/entities/question.dart';
import '../../domain/repositories/question_repository.dart';

/// 백엔드가 준비되기 전에 화면을 먼저 만들기 위한 가짜 구현.
///
/// `injector.dart` 에서 [QuestionRepositoryImpl] 대신 이걸 등록하면
/// **화면 코드는 한 줄도 바꾸지 않고** 서버 없이 개발할 수 있습니다.
/// 클린 아키텍처를 쓰는 실질적인 이유가 이것입니다.
///
/// ```dart
/// // core/di/injector.dart
/// getIt.registerLazySingleton<QuestionRepository>(QuestionRepositoryMock.new);
/// ```
class QuestionRepositoryMock implements QuestionRepository {
  QuestionRepositoryMock({this.latency = const Duration(milliseconds: 400)});

  /// 로딩 상태가 실제로 보이도록 일부러 지연을 줍니다.
  final Duration latency;

  static final List<Question> _seed = List.generate(
    12,
    (i) => Question(
      id: i + 1,
      title: '좋은 질문이란 무엇일까? ${i + 1}',
      content:
          '질문의 품질은 답변의 품질을 결정합니다. '
          '무엇을 이미 시도했는지, 무엇을 기대했는지, 실제로 무슨 일이 일어났는지를 적으면 '
          '상대가 추측할 필요가 없어집니다.',
      authorName: '팀원${(i % 4) + 1}',
      createdAt: DateTime(2026, 8, 1).add(Duration(hours: i * 7)),
    ),
  );

  @override
  Future<List<Question>> getQuestions({int page = 1, int size = 20}) async {
    await Future<void>.delayed(latency);
    final start = (page - 1) * size;
    if (start >= _seed.length) return const [];
    return _seed.skip(start).take(size).toList(growable: false);
  }

  @override
  Future<Question> getQuestion(int id) async {
    await Future<void>.delayed(latency);
    return _seed.firstWhere((q) => q.id == id);
  }

  @override
  Future<Question> createQuestion({
    required String title,
    required String content,
  }) async {
    await Future<void>.delayed(latency);
    final created = Question(
      id: _seed.length + 1,
      title: title,
      content: content,
      authorName: '나',
      createdAt: DateTime.now(),
    );
    _seed.insert(0, created);
    return created;
  }
}
