import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:goodquestion/features/auth/data/repositories/auth_repository_mock.dart';
import 'package:goodquestion/features/auth/domain/entities/auth_options.dart';
import 'package:goodquestion/features/auth/domain/entities/auth_outcome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AuthRepositoryMock repositoryOf() =>
      AuthRepositoryMock(const AuthLocalDataSource(), latency: Duration.zero);

  test('인증 더미가 로그인 수단·동의·나이로 파싱된다', () async {
    final AuthOptions options = await repositoryOf().getOptions();

    expect(options.providers, hasLength(2));
    expect(options.ages, isNotEmpty);
    for (final SocialProvider p in options.providers) {
      expect(p.label, isNotEmpty);
    }
  });

  test('아동 개인정보 동의가 약관과 별도의 필수 항목이다', () async {
    final AuthOptions options = await repositoryOf().getOptions();

    // 하나로 묶으면 별도 동의를 받았다는 기록이 안 남습니다. (PRD F-01)
    expect(options.requiredConsentIds, hasLength(2));
    expect(options.requiredConsentIds, contains('terms'));
    expect(options.requiredConsentIds, contains('child_privacy'));
    // 마케팅은 선택이어야 합니다 — 필수로 묶으면 법적으로 문제가 됩니다.
    final ConsentItem marketing = options.consents.firstWhere(
      (ConsentItem c) => c.id == 'marketing',
    );
    expect(marketing.required, isFalse);
  });

  test('필수 항목이 선택 항목보다 위에 있다', () async {
    final AuthOptions options = await repositoryOf().getOptions();
    final int firstOptional = options.consents.indexWhere(
      (ConsentItem c) => !c.required,
    );
    final int lastRequired = options.consents.lastIndexWhere(
      (ConsentItem c) => c.required,
    );

    expect(lastRequired, lessThan(firstOptional));
  });

  test('프로필 없는 계정은 프로필 등록으로, 있는 계정은 홈으로', () async {
    final AuthRepositoryMock repository = repositoryOf();

    expect(
      await repository.signInWithEmail(
        email: 'parent@test.com',
        password: '1234',
      ),
      AuthOutcome.needsChild,
    );
    expect(
      await repository.signInWithEmail(
        email: 'parent2@test.com',
        password: '1234',
      ),
      AuthOutcome.ready,
    );
  });

  test('자격이 안 맞으면 실패한다', () async {
    expect(
      () => repositoryOf().signInWithEmail(
        email: 'parent@test.com',
        password: 'wrong',
      ),
      throwsA(isA<Object>()),
    );
  });

  test('소셜 로그인은 동의 스텝으로 간다', () async {
    expect(
      await repositoryOf().signInWithSocial('kakao'),
      AuthOutcome.needsConsent,
    );
  });

  test('동의는 항목과 시각을 함께 남긴다', () async {
    final AuthRepositoryMock repository = repositoryOf();

    await repository.saveConsents(<String>{'terms', 'child_privacy'});

    expect(repository.agreedConsents, contains('terms'));
    // 시각은 화면에 안 보이지만 법적으로 필요합니다.
    expect(repository.consentAt, isNotNull);
  });

  test('프로필을 만들면 hasChild 가 된다', () async {
    final AuthRepositoryMock repository = repositoryOf();

    await repository.createChild(name: '하늘이', age: 8);

    expect(repository.hasChild, isTrue);
  });
}
