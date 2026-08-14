import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/play/presentation/views/play_recap_view.dart';

/// 백엔드·로그인 없이 말하기 후 활동 UI만 확인하는 개발용 진입점입니다.
/// flutter run -d chrome -t lib/main_recap_preview.dart
void main() {
  runApp(const _RecapPreviewApp());
}

class _RecapPreviewApp extends StatelessWidget {
  const _RecapPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GoodQuestion 말하기 후 활동 미리보기',
      theme: AppTheme.light,
      home: const PlayRecapPage(sessionId: 'recap-ui-preview'),
    );
  }
}
