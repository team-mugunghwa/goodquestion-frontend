import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'core/di/injector.dart';

Future<void> main() async {
  // DI 등록 등 비동기 초기화를 하기 전에 반드시 호출해야 합니다.
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) usePathUrlStrategy();

  // 태블릿/iPad 가 주 타겟이라 가로 방향을 모두 허용합니다.
  // 폰에서도 가로를 허용해 두면 레이아웃이 깨지는 걸 개발 중에 바로 발견합니다.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  await configureDependencies();

  runApp(const GoodQuestionApp());
}
