import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/datasources/auth_token_store.dart';
import '../../features/auth/data/datasources/oauth_code_provider.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/auth_use_cases.dart';
import '../../features/home/data/datasources/home_local_data_source.dart';
import '../../features/home/data/repositories/home_repository_mock.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/home/domain/usecases/get_home_summary_use_case.dart';
import '../../features/mypage/data/datasources/child_profile_remote_data_source.dart';
import '../../features/mypage/data/datasources/my_page_local_data_source.dart';
import '../../features/mypage/data/datasources/settings_remote_data_source.dart';
import '../../features/mypage/data/repositories/my_page_repository_impl.dart';
import '../../features/mypage/data/repositories/my_page_repository_mock.dart';
import '../../features/mypage/data/repositories/settings_repository_impl.dart';
import '../../features/mypage/domain/guardian_gate.dart';
import '../../features/mypage/domain/repositories/my_page_repository.dart';
import '../../features/mypage/domain/usecases/my_page_use_cases.dart';
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
  getIt
    ..registerLazySingleton<AuthTokenStore>(AuthTokenStore.new)
    ..registerLazySingleton<DioClient>(
      () => DioClient(tokenProvider: getIt<AuthTokenStore>().read),
    );

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

  // ---- auth ----
  // 동의 기록과 "프로필 있음" 상태를 메모리에 들고 있어서 싱글턴이어야
  // 합니다. 화면을 나갔다 오면 방금 한 동의가 사라지면 안 됩니다.
  getIt
    ..registerLazySingleton<AuthLocalDataSource>(AuthLocalDataSource.new)
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSource(getIt<DioClient>()),
    )
    ..registerLazySingleton<OAuthCodeProvider>(OAuthCodeProvider.new)
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        getIt<AuthLocalDataSource>(),
        getIt<AuthRemoteDataSource>(),
        getIt<AuthTokenStore>(),
        getIt<OAuthCodeProvider>(),
      ),
    )
    ..registerLazySingleton<GetAuthOptionsUseCase>(
      () => GetAuthOptionsUseCase(getIt<AuthRepository>()),
    )
    ..registerLazySingleton<SignInWithSocialUseCase>(
      () => SignInWithSocialUseCase(getIt<AuthRepository>()),
    )
    ..registerLazySingleton<SignInWithEmailUseCase>(
      () => SignInWithEmailUseCase(getIt<AuthRepository>()),
    )
    ..registerLazySingleton<SaveConsentsUseCase>(
      () => SaveConsentsUseCase(getIt<AuthRepository>()),
    )
    ..registerLazySingleton<CreateChildUseCase>(
      () => CreateChildUseCase(getIt<AuthRepository>()),
    )
    ..registerLazySingleton<SignOutUseCase>(
      () => SignOutUseCase(getIt<AuthRepository>()),
    );

  // ---- home ----
  // 서버가 나오면 HomeRepositoryImpl 로 바꾸면 됩니다. 화면은 그대로입니다.
  getIt
    ..registerLazySingleton<HomeLocalDataSource>(HomeLocalDataSource.new)
    ..registerLazySingleton<HomeRepository>(
      () => HomeRepositoryMock(
        getIt<HomeLocalDataSource>(),
        childProfileRepository: getIt<ChildProfileRepository>(),
      ),
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

  // ---- mypage (마이페이지 · 리포트 · 설정) ----
  //
  // Mock 하나가 세 Repository 를 구현합니다. 열람 처리·토글 상태를 한 곳에서
  // 들고 있어야 화면 간에 어긋나지 않기 때문입니다. 서버가 붙으면 셋으로
  // 쪼개도 화면 코드는 그대로입니다.
  // 세 인터페이스가 **같은 인스턴스**를 가리켜야 합니다. 각각 새로 만들면
  // 리포트를 읽어도 마이페이지의 빨간 점이 안 사라집니다.
  final MyPageRepositoryMock myPageMock = MyPageRepositoryMock(
    const MyPageLocalDataSource(),
  );
  final ChildProfileRemoteDataSource childProfileRemote =
      ChildProfileRemoteDataSource(getIt<DioClient>());
  final MyPageRepositoryImpl myPageRepository = MyPageRepositoryImpl(
    childProfileRemote,
  );
  final SettingsRemoteDataSource settingsRemote = SettingsRemoteDataSource(
    getIt<DioClient>(),
  );
  final SettingsRepositoryImpl settingsRepository = SettingsRepositoryImpl(
    const MyPageLocalDataSource(),
    settingsRemote,
    myPageRepository,
  );
  getIt
    ..registerLazySingleton<GuardianGate>(GuardianGate.new)
    ..registerSingleton<ChildProfileRemoteDataSource>(childProfileRemote)
    ..registerSingleton<MyPageRepository>(myPageRepository)
    ..registerSingleton<ChildProfileRepository>(myPageRepository)
    ..registerSingleton<ReportRepository>(myPageMock)
    ..registerSingleton<SettingsRemoteDataSource>(settingsRemote)
    ..registerSingleton<SettingsRepository>(settingsRepository)
    ..registerLazySingleton<GetMyPageSummaryUseCase>(
      () => GetMyPageSummaryUseCase(getIt<MyPageRepository>()),
    )
    ..registerLazySingleton<CreateMyPageChildUseCase>(
      () => CreateMyPageChildUseCase(getIt<ChildProfileRepository>()),
    )
    ..registerLazySingleton<GetMyPageChildrenUseCase>(
      () => GetMyPageChildrenUseCase(getIt<ChildProfileRepository>()),
    )
    ..registerLazySingleton<SelectMyPageChildUseCase>(
      () => SelectMyPageChildUseCase(getIt<ChildProfileRepository>()),
    )
    ..registerLazySingleton<GetReportListUseCase>(
      () => GetReportListUseCase(getIt<ReportRepository>()),
    )
    ..registerLazySingleton<GetReportDetailUseCase>(
      () => GetReportDetailUseCase(getIt<ReportRepository>()),
    )
    ..registerLazySingleton<MarkReportAsReadUseCase>(
      () => MarkReportAsReadUseCase(getIt<ReportRepository>()),
    )
    ..registerLazySingleton<GetSettingsUseCase>(
      () => GetSettingsUseCase(getIt<SettingsRepository>()),
    )
    ..registerLazySingleton<SetReportNotificationUseCase>(
      () => SetReportNotificationUseCase(getIt<SettingsRepository>()),
    )
    ..registerLazySingleton<SetMarketingConsentUseCase>(
      () => SetMarketingConsentUseCase(getIt<SettingsRepository>()),
    );
}
