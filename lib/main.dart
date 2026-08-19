import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app.dart';
import 'core/audio/speech_service.dart';
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

  // 번들한 폰트의 라이선스(OFL 1.1). 에셋 폰트는 showLicensePage 가 자동으로
  // 잡아 주지 않으므로 직접 등록합니다. → assets/fonts/README.md 3
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Pretendard',
    ], await rootBundle.loadString('assets/fonts/Pretendard-OFL.txt'));
    yield LicenseEntryWithLineBreaks(const [
      'NanumSquareRound',
    ], await rootBundle.loadString('assets/fonts/NanumSquareRound-OFL.txt'));
  });

  // 기기에 한국어 목소리가 있는지 여기서 한 번 확인해 둡니다. 없으면 스피커
  // 버튼이 비활성될 뿐, 앱은 그대로 뜹니다 — 소리 때문에 화면을 막지 않습니다.
  await SpeechService.instance.init();

  runApp(const GoodQuestionApp());
}
