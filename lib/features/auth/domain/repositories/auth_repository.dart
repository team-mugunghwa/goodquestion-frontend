import '../entities/auth_options.dart';
import '../entities/auth_outcome.dart';

/// 보호자 인증의 출처.
abstract class AuthRepository {
  /// 로그인 수단 · 동의 항목 · 나이 선택지.
  Future<AuthOptions> getOptions();

  /// 소셜 로그인. 실패하면 [Failure] 를 던집니다.
  Future<AuthOutcome> signInWithSocial(
    String provider, {
    bool rememberMe = false,
  });

  /// 이메일 로그인. 자격이 안 맞으면 [Failure] 를 던집니다.
  Future<AuthOutcome> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = false,
  });

  /// 이메일 가입. 언제나 동의 스텝으로 이어집니다.
  Future<AuthOutcome> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    bool rememberMe = false,
  });

  /// 동의 확정. **동의한 시각을 함께 남깁니다** — 법적으로 필요합니다.
  Future<void> saveConsents(Set<String> agreedIds);

  /// 최초 아이 프로필 생성. 이 화면은 **1명까지만** 책임집니다.
  /// 이후 추가는 마이페이지의 프로필 모달이 맡습니다.
  Future<void> createChild({required String name, required int age});

  /// 로그아웃. 프로필 등록 스텝에서 뒤로 갈 때 씁니다.
  Future<void> signOut();
}
