import 'dart:async';

import 'package:flutter/material.dart';

import 'core/di/injector.dart';
import 'core/push/push_service.dart';
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
class GoodQuestionApp extends StatefulWidget {
  const GoodQuestionApp({super.key});

  @override
  State<GoodQuestionApp> createState() => _GoodQuestionAppState();
}

class _GoodQuestionAppState extends State<GoodQuestionApp> {
  StreamSubscription<String>? _pushTapSubscription;

  @override
  void initState() {
    super.initState();
    // 알림을 눌러 앱이 열렸을 때 그 화면으로 보냅니다. 경로는 관리자 콘솔이
    // 알림에 실어 보낸 값입니다(예: /support/{inquiryId}).
    //
    // 여기서 받는 이유: 라우터는 앱 수명 내내 하나이고, 화면 안에서 구독하면
    // 그 화면이 떠 있을 때만 알림이 동작합니다.
    _pushTapSubscription = getIt<PushService>().notificationTaps.listen(
      appRouter.push<void>,
    );
  }

  @override
  void dispose() {
    _pushTapSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GoodQuestion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // 다크 모드는 MVP 범위 밖입니다. 기기 설정이 다크여도 밝은 화면으로
      // 고정합니다. → docs/DECISIONS.md 014
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
    );
  }
}
