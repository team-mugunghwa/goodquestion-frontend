import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/auth_options.dart';
import '../../domain/entities/auth_outcome.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_data_source.dart';
import '../dtos/auth_dto.dart';

/// 서버가 준비되기 전까지의 가짜 인증.
///
/// ## 실제 OAuth 를 붙이지 않았습니다
///
/// 카카오·구글 SDK 는 앱 키 발급과 플랫폼별 설정이 선행돼야 하고, 그게 없으면
/// 버튼을 눌러도 아무 일도 안 일어납니다. 목업에서 검증할 건 **로그인 이후의
/// 분기**(동의 → 프로필 → 홈)이지 OAuth 자체가 아닙니다.
/// 소셜 버튼은 1.5초 지연 후 "신규 가입"으로 처리합니다.
///
/// 이메일은 `auth_screen.json` 의 `demoAccounts` 와 대조합니다.
/// - `parent@test.com` — 기존 계정, **프로필 없음** → 프로필 등록 스텝
/// - `parent2@test.com` — 기존 계정, 프로필 있음 → 홈
///
/// 세 갈래를 전부 눌러 볼 수 있어야 이 화면의 설계가 검증됩니다.
class AuthRepositoryMock implements AuthRepository {
  AuthRepositoryMock(
    this._localDataSource, {
    this.latency = const Duration(milliseconds: 1500),
  });

  final AuthLocalDataSource _localDataSource;

  /// 소셜 로그인의 체감 지연. 명세가 1.5초를 지정했습니다.
  final Duration latency;

  /// 동의한 항목과 시각. 메모리에만 남습니다.
  Set<String>? _agreedConsents;
  DateTime? _consentAt;

  /// 목업이 기억하는 "지금 프로필이 있는가".
  bool _hasChild = false;

  @override
  Future<AuthOptions> getOptions() async {
    try {
      return (await _localDataSource.fetchOptions()).toEntity();
    } on AppException catch (e) {
      throw Failure.fromException(e);
    } on Object catch (e) {
      throw Failure.fromException(ParseException('$e'));
    }
  }

  @override
  Future<AuthOutcome> signInWithSocial(
    String provider, {
    bool rememberMe = false,
  }) async {
    await Future<void>.delayed(latency);
    // 목업에서는 소셜을 언제나 신규 가입으로 봅니다 — 동의부터 프로필까지
    // 전체 흐름을 한 번에 시연할 수 있는 경로가 하나는 있어야 합니다.
    _hasChild = false;
    return AuthOutcome.needsConsent;
  }

  @override
  Future<AuthOutcome> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    await Future<void>.delayed(latency);
    final AuthOptionsDto dto = await _localDataSource.fetchOptions();
    for (final DemoAccountDto account in dto.demoAccounts) {
      if (account.email == email && account.password == password) {
        _hasChild = account.hasChild;
        return account.hasChild ? AuthOutcome.ready : AuthOutcome.needsChild;
      }
    }
    // 어느 쪽이 틀렸는지 알려주지 않습니다 — 계정 존재 여부가 새어 나갑니다.
    throw const UnauthorizedFailure('이메일 또는 비밀번호를 다시 확인해 주세요.');
  }

  @override
  Future<AuthOutcome> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    await Future<void>.delayed(latency);
    _hasChild = false;
    return AuthOutcome.needsConsent;
  }

  @override
  Future<void> saveConsents(Set<String> agreedIds) async {
    _agreedConsents = agreedIds;
    // 동의 "시각"은 법적으로 필요합니다. 화면에 보여 주지 않아도 남깁니다.
    _consentAt = DateTime.now();
  }

  @override
  Future<void> createChild({required String name, required int age}) async {
    await Future<void>.delayed(latency);
    _hasChild = true;
  }

  @override
  Future<void> signOut() async {
    _agreedConsents = null;
    _consentAt = null;
    _hasChild = false;
  }

  /// 테스트·디버그용. 동의 기록이 실제로 남았는지 확인합니다.
  Set<String>? get agreedConsents => _agreedConsents;
  DateTime? get consentAt => _consentAt;
  bool get hasChild => _hasChild;
}
