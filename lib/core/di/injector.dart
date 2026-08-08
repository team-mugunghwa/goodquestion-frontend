import 'package:get_it/get_it.dart';

import '../../features/question/data/datasources/question_remote_data_source.dart';
import '../../features/question/data/repositories/question_repository_impl.dart';
import '../../features/question/data/repositories/question_repository_mock.dart';
import '../../features/question/domain/repositories/question_repository.dart';
import '../../features/question/domain/usecases/get_questions_use_case.dart';
import '../network/dio_client.dart';

/// 앱 전역 서비스 로케이터.
///
/// ## 여기에 등록하는 것 / 안 하는 것
/// - ✅ Repository, UseCase, DataSource, DioClient — 위젯 트리와 무관한 객체
/// - ❌ ViewModel — 화면 생명주기를 따라야 하므로 `ChangeNotifierProvider` 로 만듭니다
///
/// ⚠️ **이 파일은 4명이 동시에 건드리기 쉬운 파일입니다.**
/// 수정 전에 팀 채널에 알리세요. → `docs/CONVENTIONS.md`
final GetIt getIt = GetIt.instance;

/// 백엔드가 준비되기 전까지 목업 Repository 를 씁니다.
///
/// 서버 연동이 시작되면 `false` 로 바꾸기만 하면 됩니다.
/// 화면·ViewModel 코드는 전혀 손대지 않습니다.
const bool _useMockRepository = true;

Future<void> configureDependencies() async {
  // ---- core ----
  getIt.registerLazySingleton<DioClient>(DioClient.new);

  // ---- question ----
  getIt
    ..registerLazySingleton<QuestionRemoteDataSource>(
      () => QuestionRemoteDataSource(getIt<DioClient>()),
    )
    ..registerLazySingleton<QuestionRepository>(
      () => _useMockRepository
          ? QuestionRepositoryMock()
          : QuestionRepositoryImpl(getIt<QuestionRemoteDataSource>()),
    )
    ..registerLazySingleton<GetQuestionsUseCase>(
      () => GetQuestionsUseCase(getIt<QuestionRepository>()),
    );
}
