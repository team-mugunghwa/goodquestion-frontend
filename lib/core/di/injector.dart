import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/account_recovery_remote_data_source.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/datasources/auth_token_store.dart';
import '../../features/auth/data/datasources/oauth_code_provider.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/auth_use_cases.dart';
import '../../features/helpdesk/data/datasources/helpdesk_remote_data_source.dart';
import '../../features/helpdesk/data/repositories/helpdesk_repository_impl.dart';
import '../../features/helpdesk/domain/repositories/helpdesk_repository.dart';
import '../../features/helpdesk/domain/usecases/helpdesk_use_cases.dart';
import '../../features/home/data/datasources/home_remote_data_source.dart';
import '../../features/home/data/repositories/home_repository_impl.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/home/domain/usecases/get_home_summary_use_case.dart';
import '../../features/mypage/data/datasources/child_profile_remote_data_source.dart';
import '../../features/mypage/data/datasources/my_page_local_data_source.dart';
import '../../features/mypage/data/datasources/report_remote_data_source.dart';
import '../../features/mypage/data/datasources/settings_remote_data_source.dart';
import '../../features/mypage/data/repositories/my_page_repository_impl.dart';
import '../../features/mypage/data/repositories/report_repository_impl.dart';
import '../../features/mypage/data/repositories/settings_repository_impl.dart';
import '../../features/mypage/domain/guardian_gate.dart';
import '../../features/mypage/domain/repositories/my_page_repository.dart';
import '../../features/mypage/domain/usecases/my_page_use_cases.dart';
import '../../features/play/data/datasources/play_remote_data_source.dart';
import '../../features/play/data/repositories/play_repository_impl.dart';
import '../../features/play/domain/repositories/play_repository.dart';
import '../../features/question/data/datasources/question_remote_data_source.dart';
import '../../features/question/data/repositories/question_repository_impl.dart';
import '../../features/question/data/repositories/question_repository_mock.dart';
import '../../features/question/domain/repositories/question_repository.dart';
import '../../features/question/domain/usecases/get_questions_use_case.dart';
import '../../features/story/data/datasources/story_remote_data_source.dart';
import '../../features/story/data/repositories/story_repository_impl.dart';
import '../../features/story/domain/repositories/story_repository.dart';
import '../../features/story/domain/usecases/get_story_catalog_use_case.dart';
import '../../features/story/domain/usecases/get_story_detail_use_case.dart';
import '../../features/story/domain/usecases/start_story_session_use_case.dart';
import '../../features/word/data/datasources/word_local_data_source.dart';
import '../../features/word/data/datasources/word_remote_data_source.dart';
import '../../features/word/data/repositories/word_repository_impl.dart';
import '../../features/word/data/repositories/word_repository_mock.dart';
import '../../features/word/domain/repositories/word_repository.dart';
import '../../features/word/domain/usecases/get_word_book_use_case.dart';
import '../../features/word/domain/usecases/toggle_word_like_use_case.dart';
import '../network/dio_client.dart';
import '../push/fcm_push_service.dart';
import '../push/push_registrar.dart';
import '../push/push_service.dart';
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

/// 백엔드가 준비되기 전까지 목업 Repository 를 씁니다.
///
/// 서버 연동이 시작되면 `false` 로 바꾸기만 하면 됩니다.
/// 화면·ViewModel 코드는 전혀 손대지 않습니다.
/// question 과 word 가 이 플래그를 봅니다. 단어장이 서버에 붙으면서 `false`.
const bool _useMockRepository = false;

Future<void> configureDependencies() async {
  // ---- core ----
  getIt
    ..registerLazySingleton<AuthTokenStore>(AuthTokenStore.new)
    ..registerLazySingleton<DioClient>(
      () => DioClient(
        tokenProvider: getIt<AuthTokenStore>().read,
        tokenRefresher: _refreshTokens,
        onUnauthorized: _handleUnauthorized,
      ),
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
  // `HomeRepositoryMock`/`HomeLocalDataSource`(+ `home.json`)는 테스트용으로
  // 남겨 두고 여기서는 참조하지 않습니다. `ChildProfileRepository` 는 아래
  // mypage 블록에서 등록되지만, lazySingleton 은 첫 접근 시점에 팩토리를
  // 실행하므로 등록 순서와 무관합니다.
  getIt
    ..registerLazySingleton<HomeRemoteDataSource>(
      () => HomeRemoteDataSource(getIt<DioClient>()),
    )
    ..registerLazySingleton<HomeRepository>(
      () => HomeRepositoryImpl(
        getIt<HomeRemoteDataSource>(),
        getIt<ChildProfileRepository>(),
      ),
    )
    ..registerLazySingleton<GetHomeSummaryUseCase>(
      () => GetHomeSummaryUseCase(getIt<HomeRepository>()),
    );

  // ---- story ----
  // `StoryRepositoryMock`/`StoryLocalDataSource`(+ 더미 JSON)도 테스트용으로
  // 남겨 두고 여기서는 참조하지 않습니다.
  getIt
    ..registerLazySingleton<StoryRemoteDataSource>(
      () => StoryRemoteDataSource(getIt<DioClient>()),
    )
    ..registerLazySingleton<StoryRepository>(
      () => StoryRepositoryImpl(
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
      // 진행 중 세션은 홈 응답에만 있어서 HomeRepository 를 함께 봅니다.
      () => StartStorySessionUseCase(
        getIt<StoryRepository>(),
        getIt<HomeRepository>(),
      ),
    );

  // ---- play ----
  getIt
    ..registerLazySingleton<PlayRemoteDataSource>(
      () => PlayRemoteDataSource(getIt<DioClient>()),
    )
    ..registerLazySingleton<PlayRepository>(
      () => PlayRepositoryImpl(getIt<PlayRemoteDataSource>()),
    );

  // ---- word ----
  // 목업은 좋아요와 보상 이력을 메모리에 들고 있어서 lazySingleton 이어야
  // 합니다. factory 로 바꾸면 화면을 나갔다 올 때마다 초기화됩니다.
  getIt
    ..registerLazySingleton<WordLocalDataSource>(WordLocalDataSource.new)
    ..registerLazySingleton<WordRemoteDataSource>(
      () => WordRemoteDataSource(getIt<DioClient>()),
    )
    ..registerLazySingleton<WordRepository>(
      () => _useMockRepository
          ? WordRepositoryMock(getIt<WordLocalDataSource>())
          : WordRepositoryImpl(
              getIt<WordRemoteDataSource>(),
              getIt<ChildProfileRepository>(),
            ),
    )
    ..registerLazySingleton<GetWordBookUseCase>(
      () => GetWordBookUseCase(getIt<WordRepository>()),
    )
    ..registerLazySingleton<ToggleWordLikeUseCase>(
      () => ToggleWordLikeUseCase(getIt<WordRepository>()),
    );

  // ---- helpdesk (공지 / 이용 안내 / 문의 / 알림) ----
  //
  // 목업 저장소가 없습니다. 이 데이터는 관리자 콘솔이 만들고 서버가 내려주는
  // 것이라 화면만 먼저 만들 이유가 없었습니다.
  getIt
    ..registerLazySingleton<HelpdeskRemoteDataSource>(
      () => HelpdeskRemoteDataSource(getIt<DioClient>()),
    )
    ..registerLazySingleton<HelpdeskRepository>(
      () => HelpdeskRepositoryImpl(getIt<HelpdeskRemoteDataSource>()),
    )
    ..registerLazySingleton<GetNoticesUseCase>(
      () => GetNoticesUseCase(getIt<HelpdeskRepository>()),
    )
    ..registerLazySingleton<GetNoticeUseCase>(
      () => GetNoticeUseCase(getIt<HelpdeskRepository>()),
    )
    ..registerLazySingleton<GetGuidesUseCase>(
      () => GetGuidesUseCase(getIt<HelpdeskRepository>()),
    )
    ..registerLazySingleton<GetInquiriesUseCase>(
      () => GetInquiriesUseCase(getIt<HelpdeskRepository>()),
    )
    ..registerLazySingleton<GetInquiryUseCase>(
      () => GetInquiryUseCase(getIt<HelpdeskRepository>()),
    )
    ..registerLazySingleton<CreateInquiryUseCase>(
      () => CreateInquiryUseCase(getIt<HelpdeskRepository>()),
    )
    ..registerLazySingleton<GetNotificationsUseCase>(
      () => GetNotificationsUseCase(getIt<HelpdeskRepository>()),
    )
    ..registerLazySingleton<GetUnreadNotificationCountUseCase>(
      () => GetUnreadNotificationCountUseCase(getIt<HelpdeskRepository>()),
    )
    ..registerLazySingleton<MarkNotificationReadUseCase>(
      () => MarkNotificationReadUseCase(getIt<HelpdeskRepository>()),
    )
    ..registerLazySingleton<MarkAllNotificationsReadUseCase>(
      () => MarkAllNotificationsReadUseCase(getIt<HelpdeskRepository>()),
    )
    ..registerLazySingleton<RegisterDeviceUseCase>(
      () => RegisterDeviceUseCase(getIt<HelpdeskRepository>()),
    )
    ..registerLazySingleton<UnregisterDeviceUseCase>(
      () => UnregisterDeviceUseCase(getIt<HelpdeskRepository>()),
    );

  // ---- push ----
  //
  // Firebase 설정이 없으면 NoopPushService 가 등록됩니다. 로컬과 CI 에 키를
  // 두지 않기 위해서이고, 그때도 알림은 서버에 쌓여 알림함에서 볼 수 있습니다.
  final PushService pushService =
      await FcmPushService.create() ?? const NoopPushService();
  getIt
    ..registerSingleton<PushService>(pushService)
    ..registerLazySingleton<PushRegistrar>(
      () => PushRegistrar(
        pushService: getIt<PushService>(),
        registerDevice: getIt<RegisterDeviceUseCase>(),
        unregisterDevice: getIt<UnregisterDeviceUseCase>(),
      ),
    );

  // ---- mypage (마이페이지 · 리포트 · 설정) ----
  //
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
  final ReportRemoteDataSource reportRemote = ReportRemoteDataSource(
    getIt<DioClient>(),
  );
  final ReportRepositoryImpl reportRepository = ReportRepositoryImpl(
    reportRemote,
    myPageRepository,
  );
  getIt
    ..registerLazySingleton<GuardianGate>(GuardianGate.new)
    ..registerSingleton<ChildProfileRemoteDataSource>(childProfileRemote)
    ..registerSingleton<MyPageRepository>(myPageRepository)
    ..registerSingleton<ChildProfileRepository>(myPageRepository)
    ..registerSingleton<ReportRemoteDataSource>(reportRemote)
    ..registerSingleton<ReportRepository>(reportRepository)
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

/// 진행 중인 재발급. 여러 요청이 동시에 401 을 받아도 실제 `/auth/refresh`
/// 호출은 한 번만 나가야 합니다 — 리프레시 토큰은 1회용으로 회전되므로,
/// 두 번째 호출은 이미 못 쓰게 된 토큰으로 보내 실패합니다. 진행 중인
/// Future 가 있으면 새로 호출하지 않고 그 결과를 같이 기다립니다.
Future<bool>? _refreshFuture;

Future<bool> _refreshTokens() => _refreshFuture ??= _doRefreshTokens()
    .whenComplete(() => _refreshFuture = null);

/// `POST /auth/refresh` 로 액세스·리프레시 토큰을 재발급합니다.
///
/// 응답은 `AuthResponse` 의 `tokens` 처럼 감싸져 있지 않고 `TokenResponse`
/// 를 그대로 돌려줍니다 — `{accessToken, refreshToken, accessTokenExpiresIn}`.
///
/// **`DioException`(타임아웃·연결 끊김)은 여기서 삼키지 않고 그대로
/// 던집니다.** 이 함수는 `DioClient._request` 의 같은 try 블록 안에서
/// 호출되므로, 그대로 두면 그 블록의 `on DioException catch` 가 받아
/// `NetworkException` 으로 바뀝니다 - "리프레시 토큰이 서버에서 거절됨"과
/// "네트워크가 잠깐 끊겨서 물어보지도 못함"을 같은 실패로 묶어서 매번
/// 로그아웃시키면 안 됩니다. 후자는 토큰을 그대로 두고 이 요청 한 번만
/// 실패시켜야, 네트워크가 돌아왔을 때 같은 토큰으로 다시 시도할 수 있습니다.
/// 서버가 실제로 401/400 을 준 경우만 `false` 를 돌려줍니다.
Future<bool> _doRefreshTokens() async {
  final AuthTokenStore tokens = getIt<AuthTokenStore>();
  final String? refreshToken = await tokens.readRefresh();
  if (refreshToken == null || refreshToken.isEmpty) return false;
  final Response<dynamic> response = await getIt<DioClient>().raw.post<dynamic>(
    '/auth/refresh',
    data: <String, dynamic>{'refreshToken': refreshToken},
  );
  if ((response.statusCode ?? 0) != 200) return false;
  final Object? body = response.data;
  final Map<String, dynamic>? map = body is Map<String, dynamic> ? body : null;
  final String? newAccess = map?['accessToken'] as String?;
  final String? newRefresh = map?['refreshToken'] as String?;
  if (newAccess == null ||
      newAccess.isEmpty ||
      newRefresh == null ||
      newRefresh.isEmpty) {
    return false;
  }
  await tokens.saveRefreshed(accessToken: newAccess, refreshToken: newRefresh);
  return true;
}
