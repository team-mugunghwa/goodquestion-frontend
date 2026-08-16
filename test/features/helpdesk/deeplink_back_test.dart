import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:goodquestion/core/router/pop_or_go.dart';

/// 딥링크 진입 후 뒤로 가기.
///
/// 알림 딥링크(`/support/{inquiryId}`)나 주소 직접 입력으로 들어오면 pop 할
/// 스택이 없다. 무조건 `context.pop()` 을 부르면 GoError가 나서 뒤로 버튼이
/// 죽은 것처럼 보인다(실서버에서 재현했던 버그). [popOrGo] 는 이때 지정된
/// 화면으로 보낸다.
void main() {
  GoRouter router(String initial) => GoRouter(
    initialLocation: initial,
    routes: <RouteBase>[
      GoRoute(
        path: '/settings',
        builder: (_, __) => const Scaffold(body: Text('설정 화면')),
      ),
      GoRoute(
        path: '/notices',
        builder: (BuildContext context, __) => Scaffold(
          body: TextButton(
            onPressed: () => popOrGo(context, '/settings'),
            child: const Text('뒤로'),
          ),
        ),
      ),
    ],
  );

  testWidgets('딥링크로 바로 들어와 스택이 없으면 지정된 화면으로 간다', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router('/notices')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('뒤로'));
    await tester.pumpAndSettle();

    expect(
      find.text('설정 화면'),
      findsOneWidget,
      reason: 'GoError 없이 폴백으로 가야 합니다',
    );
  });

  testWidgets('스택이 있으면 평소처럼 pop 한다', (WidgetTester tester) async {
    final GoRouter r = router('/settings');
    await tester.pumpWidget(MaterialApp.router(routerConfig: r));
    await tester.pumpAndSettle();
    r.push('/notices');
    await tester.pumpAndSettle();

    await tester.tap(find.text('뒤로'));
    await tester.pumpAndSettle();

    expect(find.text('설정 화면'), findsOneWidget);
  });
}
