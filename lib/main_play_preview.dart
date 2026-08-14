import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/play/presentation/views/play_view.dart';

/// 백엔드·로그인 없이 대화 화면만 빠르게 확인하는 개발용 진입점입니다.
///
/// 실행:
/// flutter run -d chrome -t lib/main_play_preview.dart
void main() {
  runApp(const _PlayPreviewApp());
}

class _PlayPreviewApp extends StatelessWidget {
  const _PlayPreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GoodQuestion 대화 화면 미리보기',
      theme: AppTheme.light,
      home: const PlayPage(sessionId: 'dialogue-ui-preview'),
    );
  }
}
