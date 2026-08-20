import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/storage/selected_child_store.dart';
import '../../domain/entities/auth_options.dart';
import '../../domain/entities/auth_outcome.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/auth_token_store.dart';
import '../datasources/oauth_code_provider.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._local,
    this._remote,
    this._tokens,
    this._oauth,
    this._selectedChild,
  );

  final AuthLocalDataSource _local;
  final AuthRemoteDataSource _remote;
  final AuthTokenStore _tokens;
  final OAuthCodeProvider _oauth;

  /// 로그아웃하면 고른 아이도 지웁니다. **안 지우면 다음 사용자가 남의 아이를
  /// 봅니다** - 토큰과 같은 시점에 사라져야 하는 값이라 여기서 함께 지웁니다.
  final SelectedChildStore _selectedChild;
  Set<String> _agreedIds = <String>{};

  @override
  Future<AuthOptions> getOptions() async {
    try {
      return (await _local.fetchOptions()).toEntity();
    } on AppException catch (error) {
      throw Failure.fromException(error);
    }
  }

  @override
  Future<AuthOutcome> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = false,
  }) => _authenticate(
    () => _remote.login(email: email, password: password),
    rememberMe: rememberMe,
  );

  @override
  Future<AuthOutcome> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      final Map<String, dynamic> response = await _remote.signUp(
        name: name,
        email: email,
        password: password,
      );
      await _saveToken(response, rememberMe: rememberMe);
      return AuthOutcome.needsConsent;
    } on AppException catch (error) {
      throw Failure.fromException(error);
    }
  }

  @override
  Future<AuthOutcome> signInWithSocial(
    String provider, {
    bool rememberMe = false,
  }) async {
    if (AppConfig.mockSocialLogin) {
      // 공급자 콘솔 키가 준비되기 전 UI/라우팅 확인용입니다. 서버 토큰이
      // 없으므로 신규 가입 단계 대신 기존 회원처럼 홈으로 이동합니다.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return AuthOutcome.ready;
    }
    try {
      final OAuthAuthorization authorization = await _oauth.authorize(provider);
      final Map<String, dynamic> response = await _remote.socialLogin(
        provider: provider,
        authorizationCode: authorization.code,
        redirectUri: authorization.redirectUri,
      );
      await _saveToken(response, rememberMe: rememberMe);
      if (response['isNewUser'] == true) return AuthOutcome.needsConsent;
      return await _hasChild() ? AuthOutcome.ready : AuthOutcome.needsChild;
    } on Failure {
      rethrow;
    } on AppException catch (error) {
      throw Failure.fromException(error);
    }
  }

  Future<AuthOutcome> _authenticate(
    Future<Map<String, dynamic>> Function() request, {
    required bool rememberMe,
  }) async {
    try {
      final Map<String, dynamic> response = await request();
      await _saveToken(response, rememberMe: rememberMe);
      return await _hasChild() ? AuthOutcome.ready : AuthOutcome.needsChild;
    } on AppException catch (error) {
      throw Failure.fromException(error);
    }
  }

  Future<void> _saveToken(
    Map<String, dynamic> response, {
    required bool rememberMe,
  }) async {
    final Object? tokens = response['tokens'];
    final Map<String, dynamic>? tokenMap = tokens is Map<String, dynamic>
        ? tokens
        : null;
    final String? token = tokenMap?['accessToken'] as String?;
    if (token == null || token.isEmpty) {
      throw const ParseException('로그인 토큰이 없습니다.');
    }
    await _tokens.save(
      token,
      tokenMap?['refreshToken'] as String?,
      persistent: rememberMe,
    );
  }

  Future<bool> _hasChild() async => (await _remote.children()).isNotEmpty;

  @override
  Future<void> saveConsents(Set<String> agreedIds) async {
    _agreedIds = Set<String>.of(agreedIds);
  }

  @override
  Future<void> createChild({required String name, required int age}) async {
    try {
      final String childId = await _remote.createChild(name: name, age: age);
      if (childId.isEmpty) throw const ParseException('아이 ID가 없습니다.');
      if (_agreedIds.isNotEmpty) await _remote.saveConsent(childId);
    } on AppException catch (error) {
      throw Failure.fromException(error);
    }
  }

  @override
  Future<void> signOut() async {
    // 서버에 리프레시 토큰을 무효화해 둡니다 — 안 해도 로컬 로그아웃은
    // 되지만, 빼놓은 토큰이 그대로 남아 있으면 유출 시 계속 재발급됩니다.
    // 네트워크 실패로 이 호출이 막혀도 로그아웃 자체는 진행합니다.
    final String? refreshToken = await _tokens.readRefresh();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _remote.logout(refreshToken);
      } on AppException {
        // 로컬 로그아웃은 아래에서 계속 진행합니다.
      }
    }
    await _tokens.clear();
    await _selectedChild.clear();
  }
}
