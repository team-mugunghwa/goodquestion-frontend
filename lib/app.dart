import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// 앱의 루트 위젯.
///
/// 여기 `MultiProvider` 를 두게 되면 **정말 앱 전체 수명 동안 살아 있어야 하는
/// 상태만** 올리세요. (예: 로그인 세션) 화면 단위 ViewModel 은 각 화면에서
/// `ChangeNotifierProvider` 로 만듭니다. → `docs/ARCHITECTURE.md`
///
/// 화면 전환은 `MaterialApp.router` + go_router 가 담당합니다. 라우트는
/// `core/router/app_router.dart` 에만 등록하세요. → `docs/DECISIONS.md` 013
class GoodQuestionApp extends StatelessWidget {
  const GoodQuestionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GoodQuestion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
