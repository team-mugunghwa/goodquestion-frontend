import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/route_placeholder_view.dart';

/// 마이페이지 — 현재 아이 프로필, 메뉴 허브, 프로필 관리·전환.
class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoutePlaceholderView(path: AppRoutes.myPage, title: '마이페이지');
  }
}
