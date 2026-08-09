import 'package:get_it/get_it.dart';

import '../../features/home/data/datasources/home_local_data_source.dart';
import '../../features/home/data/repositories/home_repository_mock.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/home/domain/usecases/get_home_summary_use_case.dart';
import '../../features/question/data/datasources/question_remote_data_source.dart';
import '../../features/question/data/repositories/question_repository_impl.dart';
import '../../features/question/data/repositories/question_repository_mock.dart';
import '../../features/question/domain/repositories/question_repository.dart';
import '../../features/question/domain/usecases/get_questions_use_case.dart';
import '../../features/story/data/datasources/story_local_data_source.dart';
import '../../features/story/data/repositories/story_repository_mock.dart';
import '../../features/story/domain/repositories/story_repository.dart';
import '../../features/story/domain/usecases/get_story_catalog_use_case.dart';
import '../../features/story/domain/usecases/get_story_detail_use_case.dart';
import '../../features/story/domain/usecases/start_story_session_use_case.dart';
import '../../features/word/data/datasources/word_local_data_source.dart';
import '../../features/word/data/repositories/word_repository_mock.dart';
import '../../features/word/domain/repositories/word_repository.dart';
import '../../features/word/domain/usecases/get_word_book_use_case.dart';
import '../../features/word/domain/usecases/toggle_word_like_use_case.dart';
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

  // ---- home ----
  // 서버가 나오면 HomeRepositoryImpl 로 바꾸면 됩니다. 화면은 그대로입니다.
  getIt
    ..registerLazySingleton<HomeLocalDataSource>(HomeLocalDataSource.new)
    ..registerLazySingleton<HomeRepository>(
      () => HomeRepositoryMock(getIt<HomeLocalDataSource>()),
    )
    ..registerLazySingleton<GetHomeSummaryUseCase>(
      () => GetHomeSummaryUseCase(getIt<HomeRepository>()),
    );

  // ---- story ----
  getIt
    ..registerLazySingleton<StoryLocalDataSource>(StoryLocalDataSource.new)
    ..registerLazySingleton<StoryRepository>(
      () => StoryRepositoryMock(getIt<StoryLocalDataSource>()),
    )
    ..registerLazySingleton<GetStoryCatalogUseCase>(
      () => GetStoryCatalogUseCase(getIt<StoryRepository>()),
    )
    ..registerLazySingleton<GetStoryDetailUseCase>(
      () => GetStoryDetailUseCase(getIt<StoryRepository>()),
    )
    ..registerLazySingleton<StartStorySessionUseCase>(
      () => StartStorySessionUseCase(getIt<StoryRepository>()),
    );

  // ---- word ----
  // 좋아요를 메모리에 들고 있어서 lazySingleton 이어야 합니다.
  // factory 로 바꾸면 화면을 나갔다 올 때마다 좋아요가 초기화됩니다.
  getIt
    ..registerLazySingleton<WordLocalDataSource>(WordLocalDataSource.new)
    ..registerLazySingleton<WordRepository>(
      () => WordRepositoryMock(getIt<WordLocalDataSource>()),
    )
    ..registerLazySingleton<GetWordBookUseCase>(
      () => GetWordBookUseCase(getIt<WordRepository>()),
    )
    ..registerLazySingleton<ToggleWordLikeUseCase>(
      () => ToggleWordLikeUseCase(getIt<WordRepository>()),
    );
}
