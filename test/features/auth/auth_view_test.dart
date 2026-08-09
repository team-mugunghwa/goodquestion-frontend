import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/features/auth/domain/entities/auth_options.dart';
import 'package:goodquestion/features/auth/domain/entities/auth_outcome.dart';
import 'package:goodquestion/features/auth/domain/repositories/auth_repository.dart';
import 'package:goodquestion/features/auth/domain/usecases/auth_use_cases.dart';
import 'package:goodquestion/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:goodquestion/features/auth/presentation/views/auth_view.dart';
import 'package:provider/provider.dart';

class _Stub implements AuthRepository {
  _Stub();

  final AuthOutcome outcome = AuthOutcome.needsConsent;
  Set<String>? savedConsents;

  @override
  Future<AuthOptions> getOptions() async => const AuthOptions(
    providers: <SocialProvider>[
      SocialProvider(provider: 'kakao', label: '카카오로 시작하기'),
      SocialProvider(provider: 'google', label: '구글로 시작하기'),
    ],
    consents: <ConsentItem>[
      ConsentItem(
        id: 'terms',
        title: '서비스 이용약관',
        required: true,
        docUrl: 'https://example.com/terms',
      ),
      ConsentItem(id: 'child_privacy', title: '아동 개인정보 수집·이용', required: true),
      ConsentItem(id: 'marketing', title: '마케팅 수신', required: false),
    ],
    ages: <int>[7, 8, 9, 10],
  );

  @override
  Future<AuthOutcome> signInWithSocial(String provider) async => outcome;

  @override
  Future<AuthOutcome> signInWithEmail({
    required String email,
    required String password,
  }) async => outcome;

  @override
  Future<AuthOutcome> signUpWithEmail({
    required String email,
    required String password,
  }) async => AuthOutcome.needsConsent;

  @override
  Future<void> saveConsents(Set<String> agreedIds) async =>
      savedConsents = agreedIds;

  @override
  Future<void> createChild({required String name, required int age}) async {}

  @override
  Future<void> signOut() async {}
}

void main() {
  Future<AuthViewModel> pump(
    WidgetTester tester,
    _Stub stub, {
    bool startAtChildProfile = false,
    Size size = const Size(600, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final AuthViewModel vm = AuthViewModel(
      GetAuthOptionsUseCase(stub),
      SignInWithSocialUseCase(stub),
      SignInWithEmailUseCase(stub),
      SaveConsentsUseCase(stub),
      CreateChildUseCase(stub),
      SignOutUseCase(stub),
      startAtChildProfile: startAtChildProfile,
    );
    unawaited(vm.load());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ChangeNotifierProvider<AuthViewModel>.value(
          value: vm,
          child: const AuthView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return vm;
  }

  testWidgets('스텝1 은 소셜 버튼이 지배하고 인디케이터가 없다', (WidgetTester tester) async {
    await pump(tester, _Stub());

    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.text('구글로 시작하기'), findsOneWidget);
    expect(find.text(AuthStrings.signIn), findsOneWidget);
    // 로그인만 하러 온 사람에게 "3단계 가입"으로 보이면 부담스럽습니다.
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('이메일 가입으로 전환된다', (WidgetTester tester) async {
    await pump(tester, _Stub());

    await tester.tap(find.text(AuthStrings.signUpWithEmail));
    await tester.pumpAndSettle();

    expect(find.text(AuthStrings.signUp), findsOneWidget);
    expect(find.text(AuthStrings.backToSignIn), findsOneWidget);
  });

  testWidgets('소셜 로그인을 누르면 동의 스텝으로 간다', (WidgetTester tester) async {
    await pump(tester, _Stub());

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text(AuthStrings.consentTitle), findsOneWidget);
    expect(find.text(AuthStrings.consentAll), findsOneWidget);
    expect(find.textContaining('아동 개인정보'), findsOneWidget);
  });

  testWidgets('필수를 안 채우면 동의 스텝에 머문다', (WidgetTester tester) async {
    final _Stub stub = _Stub();
    await pump(tester, stub);
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AuthStrings.consentContinue));
    await tester.pumpAndSettle();

    expect(find.text(AuthStrings.consentTitle), findsOneWidget);
    expect(stub.savedConsents, isNull);
  });

  testWidgets('전체 동의 후 넘어가면 프로필 스텝이 뜬다', (WidgetTester tester) async {
    await pump(tester, _Stub());
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AuthStrings.consentAll));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AuthStrings.consentContinue));
    await tester.pumpAndSettle();

    expect(find.text(AuthStrings.childTitle), findsOneWidget);
    expect(find.text(AuthStrings.ageLabel(7)), findsOneWidget);
  });

  testWidgets('시작하기는 이름·나이가 다 있어야 눌린다', (WidgetTester tester) async {
    await pump(tester, _Stub(), startAtChildProfile: true);

    Finder startButton() =>
        find.widgetWithText(FilledButton, AuthStrings.start);
    expect(tester.widget<FilledButton>(startButton()).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '하늘이');
    await tester.pumpAndSettle();
    // 이름만으로는 아직 안 됩니다.
    expect(tester.widget<FilledButton>(startButton()).onPressed, isNull);

    await tester.tap(find.text(AuthStrings.ageLabel(8)));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(startButton()).onPressed, isNotNull);
  });

  testWidgets('프로필 없이 들어오면 뒤로가기가 로그아웃 확인이다', (WidgetTester tester) async {
    await pump(tester, _Stub(), startAtChildProfile: true);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // 홈으로 보내면 게이트 원칙이 깨지므로 남는 선택지는 로그아웃뿐입니다.
    expect(find.text(AuthStrings.signOutConfirm), findsOneWidget);
  });

  testWidgets('약관 보기를 누르면 문서 시트가 열린다', (WidgetTester tester) async {
    await pump(tester, _Stub());
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AuthStrings.consentView).first);
    await tester.pumpAndSettle();

    expect(find.text(AuthStrings.documentPlaceholder), findsOneWidget);
  });
}
