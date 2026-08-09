import '../entities/auth_options.dart';
import '../entities/auth_outcome.dart';
import '../repositories/auth_repository.dart';

/// 로그인 화면의 선택지를 가져옵니다.
class GetAuthOptionsUseCase {
  const GetAuthOptionsUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthOptions> call() => _repository.getOptions();
}

/// 소셜 로그인.
class SignInWithSocialUseCase {
  const SignInWithSocialUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthOutcome> call(String provider) =>
      _repository.signInWithSocial(provider);
}

/// 이메일 로그인 / 가입. 둘의 분기만 다르고 나머지는 같습니다.
class SignInWithEmailUseCase {
  const SignInWithEmailUseCase(this._repository);

  final AuthRepository _repository;

  Future<AuthOutcome> call({
    required String email,
    required String password,
    required bool isSignUp,
  }) => isSignUp
      ? _repository.signUpWithEmail(email: email, password: password)
      : _repository.signInWithEmail(email: email, password: password);
}

/// 동의 확정.
class SaveConsentsUseCase {
  const SaveConsentsUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call(Set<String> agreedIds) =>
      _repository.saveConsents(agreedIds);
}

/// 최초 아이 프로필 생성.
class CreateChildUseCase {
  const CreateChildUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call({required String name, required int age}) =>
      _repository.createChild(name: name, age: age);
}

/// 로그아웃.
class SignOutUseCase {
  const SignOutUseCase(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.signOut();
}
