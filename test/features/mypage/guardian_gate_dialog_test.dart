import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/constants/app_strings.dart';
import 'package:goodquestion/core/error/exceptions.dart';
import 'package:goodquestion/core/network/dio_client.dart';
import 'package:goodquestion/core/theme/app_theme.dart';
import 'package:goodquestion/features/mypage/data/datasources/settings_remote_data_source.dart';
import 'package:goodquestion/features/mypage/presentation/widgets/guardian_gate_dialog.dart';

/// 보호자 확인 게이트. **통과 여부가 이 화면의 전부**라, 계정 종류별로
/// 무엇을 묻고 무엇을 안 묻는지만 봅니다.
void main() {
  testWidgets('소셜 계정은 아무것도 묻지 않고 통과시킨다', (WidgetTester tester) async {
    final _Remote remote = _Remote(provider: 'KAKAO');
    final _Opened opened = await _openGate(tester, remote);

    // 소셜 계정에는 비밀번호 자체가 없어 물어볼 수 없습니다.
    expect(opened.passed, isTrue);
    expect(find.text(MyPageStrings.gateTitle), findsNothing);
    expect(remote.verifiedPasswords, isEmpty);
  });

  testWidgets('이메일 계정은 비밀번호를 묻고, 맞으면 통과시킨다', (WidgetTester tester) async {
    final _Remote remote = _Remote();
    final _Opened opened = await _openGate(tester, remote);

    expect(find.text(MyPageStrings.gateTitle), findsOneWidget);
    expect(find.text(MyPageStrings.gatePasswordLabel), findsOneWidget);
    // 어깨너머로 보이면 안 됩니다.
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, true);

    await tester.enterText(find.byType(TextField), 'hunter2');
    await tester.tap(find.text(MyPageStrings.gateConfirm));
    await tester.pumpAndSettle();

    expect(remote.verifiedPasswords, <String>['hunter2']);
    expect(opened.passed, isTrue);
  });

  testWidgets('비밀번호가 틀리면 다이얼로그를 닫지 않고 다시 받는다', (WidgetTester tester) async {
    final _Remote remote = _Remote(wrongPassword: true);
    final _Opened opened = await _openGate(tester, remote);

    await tester.enterText(find.byType(TextField), 'nope');
    await tester.tap(find.text(MyPageStrings.gateConfirm));
    await tester.pumpAndSettle();

    // 닫아 버리면 보호자가 리포트 메뉴부터 다시 눌러야 합니다.
    expect(find.text(MyPageStrings.gateWrongPassword), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(opened.passed, isNull, reason: '아직 아무 답도 돌려주지 않았어야 합니다');

    // 횟수 제한이 없으니 그 자리에서 다시 시도할 수 있습니다.
    remote.wrongPassword = false;
    await tester.enterText(find.byType(TextField), 'hunter2');
    await tester.tap(find.text(MyPageStrings.gateConfirm));
    await tester.pumpAndSettle();

    expect(opened.passed, isTrue);
    expect(remote.verifiedPasswords, <String>['nope', 'hunter2']);
  });

  testWidgets('취소하면 통과시키지 않는다', (WidgetTester tester) async {
    final _Remote remote = _Remote();
    final _Opened opened = await _openGate(tester, remote);
    await tester.tap(find.text(MyPageStrings.gateCancel));
    await tester.pumpAndSettle();

    expect(opened.passed, isFalse);
    expect(remote.verifiedPasswords, isEmpty);
  });

  testWidgets('보호자 조회가 실패하면 통과시키지 않고 다시 시도를 준다', (WidgetTester tester) async {
    final _Remote remote = _Remote(parentFailure: const NetworkException());
    final _Opened opened = await _openGate(tester, remote);

    // 통과시키면 연결이 끊긴 상태에서 게이트가 그대로 뚫립니다.
    expect(find.text(MyPageStrings.gateNetworkError), findsOneWidget);
    expect(find.text(MyPageStrings.gateRetry), findsOneWidget);
    expect(opened.passed, isNull);

    // 다시 시도하면 이번에는 물어봅니다.
    remote.parentFailure = null;
    await tester.tap(find.text(MyPageStrings.gateRetry));
    await tester.pumpAndSettle();
    expect(find.text(MyPageStrings.gatePasswordLabel), findsOneWidget);

    await tester.tap(find.text(MyPageStrings.gateCancel));
    await tester.pumpAndSettle();
    expect(opened.passed, isFalse);
  });

  testWidgets('비밀번호 확인이 네트워크로 실패하면 통과시키지 않는다', (WidgetTester tester) async {
    final _Remote remote = _Remote(verifyFailure: const NetworkException());
    final _Opened opened = await _openGate(tester, remote);

    await tester.enterText(find.byType(TextField), 'hunter2');
    await tester.tap(find.text(MyPageStrings.gateConfirm));
    await tester.pumpAndSettle();

    expect(find.text(MyPageStrings.gateNetworkError), findsOneWidget);
    expect(opened.passed, isNull, reason: '답을 못 받았으면 막습니다');
  });
}

/// 게이트를 여는 버튼 하나짜리 화면. 실제 호출부처럼 **화면 위에서** 엽니다 -
/// 곧바로 부르면 다이얼로그가 뜰 자리가 없습니다.
Future<_Opened> _openGate(WidgetTester tester, _Remote remote) async {
  final _Opened opened = _Opened();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              opened.passed = await showGuardianGateDialog(
                context,
                remote: remote,
              );
            },
            child: const Text('열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
  return opened;
}

/// 게이트가 아직 답을 안 준 상태를 `null` 로 구분하려고 상자에 담습니다.
class _Opened {
  bool? passed;
}

class _Remote extends SettingsRemoteDataSource {
  _Remote({
    this.provider,
    this.wrongPassword = false,
    this.parentFailure,
    this.verifyFailure,
  }) : super(DioClient());

  /// null 이면 이메일 계정입니다. (`docs/API.md` ParentResponse — 서버가
  /// LOCAL 을 null 로 바꿔 내립니다)
  final String? provider;

  bool wrongPassword;
  AppException? parentFailure;
  AppException? verifyFailure;

  final List<String> verifiedPasswords = <String>[];

  @override
  Future<Map<String, dynamic>> getParent() async {
    final AppException? failure = parentFailure;
    if (failure != null) throw failure;
    return <String, dynamic>{
      'id': 'parent-1',
      'email': 'a@b.com',
      'name': '보호자',
      'provider': provider,
    };
  }

  @override
  Future<void> verifyPassword(String password) async {
    verifiedPasswords.add(password);
    final AppException? failure = verifyFailure;
    if (failure != null) throw failure;
    // 서버는 틀린 비밀번호에 401 을 줍니다.
    if (wrongPassword) throw const UnauthorizedException('비밀번호가 다릅니다.');
  }
}
