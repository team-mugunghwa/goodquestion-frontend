import '../../../../core/presentation/base_view_model.dart';
import '../../domain/entities/question.dart';
import '../../domain/usecases/get_questions_use_case.dart';

/// 질문 목록 화면의 상태를 들고 있습니다.
///
/// ViewModel 이 아는 것: UseCase, Entity, 자기 상태.
/// ViewModel 이 모르는 것: `BuildContext`, 위젯, Dio, JSON.
class QuestionListViewModel extends BaseViewModel {
  QuestionListViewModel(this._getQuestions);

  final GetQuestionsUseCase _getQuestions;

  List<Question> _questions = const [];
  List<Question> get questions => _questions;

  Question? _selected;

  /// 태블릿 2단 레이아웃에서 오른쪽에 띄울 항목.
  Question? get selected => _selected;

  bool get isEmpty => state.isSuccess && _questions.isEmpty;

  Future<void> load() => guard(() async {
    _questions = await _getQuestions();
    // 태블릿에서는 상세가 비어 있으면 어색하므로 첫 항목을 미리 선택합니다.
    _selected ??= _questions.isNotEmpty ? _questions.first : null;
  });

  Future<void> refresh() => load();

  void select(Question question) {
    _selected = question;
    safeNotify();
  }
}
