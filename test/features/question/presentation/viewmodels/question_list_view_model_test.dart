import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/state/view_state.dart';
import 'package:goodquestion/features/question/domain/entities/question.dart';
import 'package:goodquestion/features/question/domain/repositories/question_repository.dart';
import 'package:goodquestion/features/question/domain/usecases/get_questions_use_case.dart';
import 'package:goodquestion/features/question/presentation/viewmodels/question_list_view_model.dart';
import 'package:mocktail/mocktail.dart';

/// ViewModel 테스트가 이렇게 간단한 이유:
/// ViewModel 이 `BuildContext` 를 몰라서 위젯 없이 그냥 만들 수 있기 때문입니다.
/// 이게 "ViewModel 에 BuildContext 를 넣지 않는다" 규칙의 실질적 이득입니다.
class _MockQuestionRepository extends Mock implements QuestionRepository {}

void main() {
  late _MockQuestionRepository repository;
  late QuestionListViewModel viewModel;

  final questions = [
    Question(
      id: 1,
      title: '첫 질문',
      content: '내용',
      authorName: '예슬',
      createdAt: DateTime(2026, 8, 8),
    ),
  ];

  setUp(() {
    repository = _MockQuestionRepository();
    viewModel = QuestionListViewModel(GetQuestionsUseCase(repository));
  });

  group('QuestionListViewModel', () {
    test('초기 상태는 idle 이다', () {
      expect(viewModel.state, ViewState.idle);
      expect(viewModel.questions, isEmpty);
    });

    test('load 성공 시 success 상태가 되고 목록이 채워진다', () async {
      when(
        () => repository.getQuestions(page: 1, size: 20),
      ).thenAnswer((_) async => questions);

      await viewModel.load();

      expect(viewModel.state, ViewState.success);
      expect(viewModel.questions, questions);
      expect(viewModel.errorMessage, isNull);
    });

    test('load 성공 시 첫 항목이 자동 선택된다 (태블릿 2단 레이아웃용)', () async {
      when(
        () => repository.getQuestions(page: 1, size: 20),
      ).thenAnswer((_) async => questions);

      await viewModel.load();

      expect(viewModel.selected, questions.first);
    });

    test('load 실패 시 error 상태가 되고 메시지가 담긴다', () async {
      when(
        () => repository.getQuestions(page: 1, size: 20),
      ).thenThrow(const NetworkFailure());

      await viewModel.load();

      expect(viewModel.state, ViewState.error);
      expect(viewModel.errorMessage, '네트워크에 연결할 수 없습니다.');
    });

    test('결과가 비어 있으면 isEmpty 가 true 다', () async {
      when(
        () => repository.getQuestions(page: 1, size: 20),
      ).thenAnswer((_) async => const []);

      await viewModel.load();

      expect(viewModel.isEmpty, isTrue);
    });
  });
}
