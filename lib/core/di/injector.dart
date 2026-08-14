import 'dart:async';

import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/account_recovery_remote_data_source.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/datasources/auth_token_store.dart';
import '../../features/auth/data/datasources/oauth_code_provider.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/auth_use_cases.dart';
import '../../features/home/data/datasources/home_local_data_source.dart';
import '../../features/home/data/datasources/home_remote_data_source.dart';
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../../features/home/data/repositories/home_repository_mock.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/home/domain/usecases/get_home_summary_use_case.dart';
import '../../features/mypage/data/datasources/child_profile_remote_data_source.dart';
import '../../features/mypage/data/datasources/my_page_local_data_source.dart';
import '../../features/mypage/data/datasources/settings_remote_data_source.dart';
import '../../features/mypage/data/repositories/child_profile_repository_mock.dart';
import '../../features/mypage/data/repositories/my_page_repository_impl.dart';
import '../../features/mypage/data/repositories/my_page_repository_mock.dart';
import '../../features/mypage/data/repositories/settings_repository_impl.dart';
import '../../features/mypage/domain/guardian_gate.dart';
import '../../features/mypage/domain/repositories/my_page_repository.dart';
import '../../features/mypage/domain/usecases/my_page_use_cases.dart';
import '../../features/play/data/datasources/play_remote_data_source.dart';
import '../../features/play/data/repositories/play_repository_impl.dart';
import '../../features/play/data/repositories/play_repository_mock.dart';
import '../../features/play/domain/repositories/play_repository.dart';
import '../../features/question/data/datasources/question_remote_data_source.dart';
import '../../features/question/data/repositories/question_repository_mock.dart';
import '../../features/question/domain/repositories/question_repository.dart';
import '../../features/question/domain/usecases/get_questions_use_case.dart';
import '../../features/story/data/datasources/story_local_data_source.dart';
import '../../features/story/data/datasources/story_remote_data_source.dart';
import '../../features/story/data/repositories/story_repository_impl.dart';
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
import '../config/app_config.dart';
import '../network/dio_client.dart';
import '../router/app_router.dart';
import '../router/app_routes.dart';

/// 앱 전역 서비스 로케이터.
///
/// ## 여기에 등록하는 것 / 안 하는 것
/// - ✅ Repository, UseCase, DataSource, DioClient — 위젯 트리와 무관한 객체
/// - ❌ ViewModel — 화면 생명주기를 따라야 하므로 `ChangeNotifierProvider` 로 만듭니다
///
/// ⚠️ **이 파일은 4명이 동시에 건드리기 쉬운 파일입니다.**
/// 수정 전에 팀 채널에 알리세요. → `docs/CONVENTIONS.md`
final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // ---- core ----
  getIt
    ..registerLazySingleton<AuthTokenStore>(AuthTokenStore.new)
    ..registerLazySingleton<DioClient>(
      () => DioClient(
        tokenProvider: getIt<AuthTokenStore>().read,
        onUnauthorized: _handleUnauthorized,
      ),
    );

  // ---- question ----
  // 이 기능은 서버 연동 전이라 항상 Mock 을 씁니다. `AppConfig.demoMode` 와는
  // 무관합니다 — demoMode 를 꺼도 여기는 그대로 Mock 입니다.
  getIt
    ..registerLazySingleton<QuestionRemoteDataSource>(
      () => QuestionRemoteDataSource(getIt<DioClient>()),
    )
    ..registerLazySingleton<QuestionRepository>(QuestionRepositoryMock.new)
    ..registerLazySingleton<GetQuestionsUseCase>(
      () => GetQuestionsUseCase(getIt<QuestionRepository>()),
    );

  // ---- auth ----
  // 동의 기록과 "프로필 있음" 상태를 메모리에 들고 있어서 싱글턴이어야
  // 합니다. 화면을 나갔다 오면 방금 한 동의가 사라지면 안 됩니다.
  getIt
    ..registerLazySingleton<AccountRecoveryRemoteDataSource>(
      () => AccountRecoveryRemoteDataSource(getIt<DioClient>()),
    )
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
  // `ChildProfileRepository` 는 아래 mypage 블록에서 등록되지만, lazySingleton
  // 은 첫 접근 시점에 팩토리를 실행하므로 등록 순서와 무관합니다.
  //
  // demoMode 에서는 `HomeRepositoryMock`(+ `home.json`)을 씁니다.
  // `tokenProvider` 를 안 넘기는 이유: 데모에는 진짜 토큰이 없으니, 토큰을
  // 확인하고 아이 없이 보여 주는 대신 곧장 mypage 블록의 데모 아이를 씁니다.
  getIt
    ..registerLazySingleton<HomeRemoteDataSource>(
      () => HomeRemoteDataSource(getIt<DioClient>()),
    )
    ..registerLazySingleton<HomeRepository>(
      () => AppConfig.demoMode
          ? HomeRepositoryMock(
              const HomeLocalDataSource(),
              childProfileRepository: getIt<ChildProfileRepository>(),
            )
          : HomeRepositoryImpl(
              getIt<HomeRemoteDataSource>(),
              getIt<ChildProfileRepository>(),
            ),
    )
    ..registerLazySingleton<GetHomeSummaryUseCase>(
      () => GetHomeSummaryUseCase(getIt<HomeRepository>()),
    );

  // ---- story ----
  // demoMode 에서는 `StoryRepositoryMock`(+ 더미 JSON)을 씁니다.
  getIt
    ..registerLazySingleton<StoryRemoteDataSource>(
      () => StoryRemoteDataSource(getIt<DioClient>()),
    )
    ..registerLazySingleton<StoryRepository>(
      () => AppConfig.demoMode
          ? const StoryRepositoryMock(StoryLocalDataSource())
          : StoryRepositoryImpl(
              getIt<StoryRemoteDataSource>(),
              getIt<ChildProfileRepository>(),
            ),
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

  // ---- play ----
  // demoMode 에서는 `PlayRepositoryMock`(장면 여러 개를 넘기는 목업)을 씁니다.
  getIt
    ..registerLazySingleton<PlayRemoteDataSource>(
      () => PlayRemoteDataSource(getIt<DioClient>()),
    )
    ..registerLazySingleton<PlayRepository>(
      () => AppConfig.demoMode
          ? PlayRepositoryMock()
          : PlayRepositoryImpl(getIt<PlayRemoteDataSource>()),
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
  //
  // `ChildProfileRepository` 는 서버 연동 때 새로 생긴 인터페이스라
  // `MyPageRepositoryMock` 은 구현하지 않습니다. demoMode 에서는
  // `ChildProfileRepositoryMock` 이 따로 그 역할을 맡습니다.
  final MyPageRepositoryMock myPageMock = MyPageRepositoryMock(
    const MyPageLocalDataSource(),
  );
  final MyPageRepository myPageRepository;
  final ChildProfileRepository childProfileRepository;
  final SettingsRepository settingsRepository;
  if (AppConfig.demoMode) {
    myPageRepository = myPageMock;
    childProfileRepository = ChildProfileRepositoryMock();
    settingsRepository = myPageMock;
  } else {
    final ChildProfileRemoteDataSource childProfileRemote =
        ChildProfileRemoteDataSource(getIt<DioClient>());
    final MyPageRepositoryImpl myPageImpl = MyPageRepositoryImpl(
      childProfileRemote,
    );
    final SettingsRemoteDataSource settingsRemote = SettingsRemoteDataSource(
      getIt<DioClient>(),
    );
    myPageRepository = myPageImpl;
    childProfileRepository = myPageImpl;
    settingsRepository = SettingsRepositoryImpl(
      const MyPageLocalDataSource(),
      settingsRemote,
      myPageImpl,
    );
    getIt
      ..registerSingleton<ChildProfileRemoteDataSource>(childProfileRemote)
      ..registerSingleton<SettingsRemoteDataSource>(settingsRemote);
  }
  getIt
    ..registerLazySingleton<GuardianGate>(GuardianGate.new)
    ..registerSingleton<MyPageRepository>(myPageRepository)
    ..registerSingleton<ChildProfileRepository>(childProfileRepository)
    ..registerSingleton<ReportRepository>(myPageMock)
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

/// [DioClient] 가 401 을 받았을 때 부르는 훅.
///
/// **로그인 화면으로 이미 가 있으면 아무것도 하지 않습니다** — 화면 하나가
/// 여러 요청을 동시에 보냈다가 한꺼번에 401 을 받으면 이 훅도 여러 번
/// 불리는데, 매번 로그아웃·이동을 반복할 이유가 없습니다.
/// 로그아웃·이동이 진행 중인지. 첫 401 이 토큰을 지우는 동안(await) 경로가
/// 아직 안 바뀌어, 동시에 온 다른 401 이 위 경로 가드를 통과해 버립니다.
/// 이 플래그로 한 번에 한 번만 이동하게 막습니다.
bool _redirectingToLogin = false;

void _handleUnauthorized() {
  // 데모 모드는 토큰 없이 로그인된 것처럼 돌아갑니다. 로그아웃·리다이렉트를
  // 태우면 화면 흐름을 보다가 느닷없이 로그인 화면으로 튕겨 나갑니다.
  if (AppConfig.demoMode) return;
  final String currentPath =
      appRouter.routerDelegate.currentConfiguration.uri.path;
  if (currentPath == AppRoutes.login || currentPath == AppRoutes.auth) return;
  if (_redirectingToLogin) return;
  _redirectingToLogin = true;
  unawaited(_signOutAndRedirectToLogin());
}

Future<void> _signOutAndRedirectToLogin() async {
  try {
    await getIt<AuthTokenStore>().clear();
    appRouter.go(AppRoutes.login);
  } finally {
    _redirectingToLogin = false;
  }
}
