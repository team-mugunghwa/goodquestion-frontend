import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/route_placeholder_view.dart';

/// 설정 — 공지사항·고객센터·이용 안내·알림·약관·개인정보, 로그아웃.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoutePlaceholderView(path: AppRoutes.settings, title: '설정');
  }
}
