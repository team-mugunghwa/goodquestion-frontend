import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/error/failure.dart';
import 'package:goodquestion/core/state/view_state.dart';
import 'package:goodquestion/features/auth/domain/entities/auth_options.dart';
import 'package:goodquestion/features/auth/domain/entities/auth_outcome.dart';
import 'package:goodquestion/features/auth/domain/repositories/auth_repository.dart';
import 'package:goodquestion/features/auth/domain/usecases/auth_use_cases.dart';
import 'package:goodquestion/features/auth/presentation/viewmodels/auth_view_model.dart';

class _Stub implements AuthRepository {
  _Stub({this.outcome = AuthOutcome.needsConsent, this.signInError});

  final AuthOutcome outcome;
  final Object? signInError;

  Set<String>? savedConsents;
  String? createdName;
  int? createdAge;
  bool signedOut = false;

  @override
  Future<AuthOptions> getOptions() async => const AuthOptions(
    providers: <SocialProvider>[
      SocialProvider(provider: 'kakao', label: '카카오로 시작하기'),
    ],
    consents: <ConsentItem>[
      ConsentItem(id: 'terms', title: '서비스 이용약관', required: true),
      ConsentItem(id: 'child_privacy', title: '아동 개인정보 수집·이용', required: true),
      ConsentItem(id: 'marketing', title: '마케팅 수신', required: false),
    ],
    ages: <int>[7, 8, 9, 10],
  );

  @override
  Future<AuthOutcome> signInWithSocial(
    String provider, {
    bool rememberMe = false,
  }) async {
    if (signInError != null) throw signInError!;
    return outcome;
  }

  @override
  Future<AuthOutcome> signInWithEmail({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    if (signInError != null) throw signInError!;
    return outcome;
  }

  @override
  Future<AuthOutcome> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    bool rememberMe = false,
  }) async => AuthOutcome.needsConsent;

  @override
  Future<void> saveConsents(Set<String> agreedIds) async =>
      savedConsents = agreedIds;

  @override
  Future<void> createChild({required String name, required int age}) async {
    createdName = name;
    createdAge = age;
  }

  @override
  Future<void> signOut() async => signedOut = true;
}

AuthViewModel _viewModelOf(_Stub stub, {bool startAtChildProfile = false}) =>
    AuthViewModel(
      GetAuthOptionsUseCase(stub),
      SignInWithSocialUseCase(stub),
      SignInWithEmailUseCase(stub),
      SaveConsentsUseCase(stub),
      CreateChildUseCase(stub),
      SignOutUseCase(stub),
      startAtChildProfile: startAtChildProfile,
    );

void main() {
  test('처음에는 로그인 스텝이다', () async {
    final vm = _viewModelOf(_Stub());
    await vm.load();

    expect(vm.state, ViewState.success);
    expect(vm.step, AuthStep.signIn);
    expect(vm.backMeansSignOut, isFalse);
  });

  test('소셜 로그인은 동의 스텝으로 넘어간다', () async {
    final vm = _viewModelOf(_Stub());
    await vm.load();

    await vm.signInWithSocial('kakao');

    expect(vm.step, AuthStep.consent);
  });

  test('프로필 없는 계정은 프로필 스텝으로 바로 간다', () async {
    final vm = _viewModelOf(_Stub(outcome: AuthOutcome.needsChild));
    await vm.load();
    vm.setEmail('parent@test.com');
    vm.setPassword('1234');

    await vm.submitEmail();

    expect(vm.step, AuthStep.childProfile);
    expect(vm.completed, isFalse);
  });

  test('프로필까지 있는 계정은 바로 완료된다', () async {
    final vm = _viewModelOf(_Stub(outcome: AuthOutcome.ready));
    await vm.load();
    vm.setEmail('parent2@test.com');
    vm.setPassword('1234');

    await vm.submitEmail();

    expect(vm.completed, isTrue);
  });

  test('빈 입력은 서버에 보내기 전에 잡는다', () async {
    final vm = _viewModelOf(_Stub());
    await vm.load();

    await vm.submitEmail();

    expect(vm.formError, isNotNull);
    expect(vm.step, AuthStep.signIn);
  });

  test('로그인 실패는 화면이 아니라 폼에 인라인으로 남는다', () async {
    final vm = _viewModelOf(
      _Stub(signInError: const UnauthorizedFailure('다시 확인해 주세요.')),
    );
    await vm.load();
    vm.setEmail('a@b.com');
    vm.setPassword('x');

    await vm.submitEmail();

    expect(vm.formError, '다시 확인해 주세요.');
    // 화면 전체가 에러로 바뀌면 다시 입력할 자리가 사라집니다.
    expect(vm.state, ViewState.success);
    expect(vm.step, AuthStep.signIn);
  });

  test('다시 입력하면 에러 메시지가 사라진다', () async {
    final vm = _viewModelOf(
      _Stub(signInError: const UnauthorizedFailure('다시 확인해 주세요.')),
    );
    await vm.load();
    vm.setEmail('a@b.com');
    vm.setPassword('x');
    await vm.submitEmail();

    vm.setEmail('a@b.co');

    expect(vm.formError, isNull);
  });

  group('동의 스텝', () {
    Future<AuthViewModel> atConsent(_Stub stub) async {
      final vm = _viewModelOf(stub);
      await vm.load();
      await vm.signInWithSocial('kakao');
      return vm;
    }

    test('필수를 안 채우면 넘어가지 않고 흔들림만 요청한다', () async {
      final _Stub stub = _Stub();
      final vm = await atConsent(stub);

      vm.toggleConsent('terms');
      await vm.submitConsents();

      expect(vm.step, AuthStep.consent);
      expect(vm.takeConsentShake(), isTrue);
      // 한 번 읽으면 사라집니다 — 리빌드마다 흔들리면 안 됩니다.
      expect(vm.takeConsentShake(), isFalse);
      expect(stub.savedConsents, isNull);
    });

    test('필수를 채우면 선택 없이도 넘어간다', () async {
      final _Stub stub = _Stub();
      final vm = await atConsent(stub);

      vm.toggleConsent('terms');
      vm.toggleConsent('child_privacy');
      await vm.submitConsents();

      expect(vm.step, AuthStep.childProfile);
      expect(stub.savedConsents, <String>{'terms', 'child_privacy'});
      expect(stub.savedConsents, isNot(contains('marketing')));
    });

    test('전체 동의는 켜고 끄기를 반복한다', () async {
      final vm = await atConsent(_Stub());

      vm.toggleAll();
      expect(vm.isAllAgreed, isTrue);
      expect(vm.canContinueConsent, isTrue);

      vm.toggleAll();
      expect(vm.isAllAgreed, isFalse);
      expect(vm.agreed, isEmpty);
    });
  });

  group('프로필 스텝', () {
    test('이름과 나이가 다 있어야 시작할 수 있다', () async {
      final vm = _viewModelOf(_Stub(), startAtChildProfile: true);
      await vm.load();

      expect(vm.canStart, isFalse);
      vm.setChildName('하늘이');
      expect(vm.canStart, isFalse, reason: '나이가 아직 없습니다');
      vm.setChildAge(8);
      expect(vm.canStart, isTrue);
    });

    test('공백만 넣은 이름은 통과하지 않는다', () async {
      final vm = _viewModelOf(_Stub(), startAtChildProfile: true);
      await vm.load();
      vm.setChildName('   ');
      vm.setChildAge(8);

      expect(vm.canStart, isFalse);
    });

    test('프로필을 만들면 완료된다', () async {
      final _Stub stub = _Stub();
      final vm = _viewModelOf(stub, startAtChildProfile: true);
      await vm.load();
      vm.setChildName(' 하늘이 ');
      vm.setChildAge(8);

      await vm.submitChild();

      expect(stub.createdName, '하늘이', reason: '앞뒤 공백은 잘라서 보냅니다');
      expect(stub.createdAge, 8);
      expect(vm.completed, isTrue);
    });

    test('프로필 없이 들어왔으면 뒤로가기가 로그아웃이다', () async {
      final _Stub stub = _Stub();
      final vm = _viewModelOf(stub, startAtChildProfile: true);
      await vm.load();

      // 홈으로 보내면 게이트 원칙이 깨지고, 막으면 사용자가 갇힙니다.
      expect(vm.backMeansSignOut, isTrue);

      await vm.signOut();

      expect(stub.signedOut, isTrue);
      expect(vm.step, AuthStep.signIn);
    });

    test('가입 흐름으로 온 경우 뒤로가기는 동의 스텝이다', () async {
      final vm = _viewModelOf(_Stub());
      await vm.load();
      await vm.signInWithSocial('kakao');
      vm.toggleAll();
      await vm.submitConsents();

      expect(vm.step, AuthStep.childProfile);
      expect(vm.backMeansSignOut, isFalse);

      vm.goBack();

      expect(vm.step, AuthStep.consent);
    });
  });
}
