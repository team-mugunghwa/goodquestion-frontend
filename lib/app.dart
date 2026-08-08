import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/question/presentation/views/question_list_view.dart';

/// 앱의 루트 위젯.
///
/// 여기 `MultiProvider` 를 두게 되면 **정말 앱 전체 수명 동안 살아 있어야 하는
/// 상태만** 올리세요. (예: 로그인 세션) 화면 단위 ViewModel 은 각 화면에서
/// `ChangeNotifierProvider` 로 만듭니다. → `docs/ARCHITECTURE.md`
class GoodQuestionApp extends StatelessWidget {
  const GoodQuestionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoodQuestion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const QuestionListPage(),
    );
  }
}
