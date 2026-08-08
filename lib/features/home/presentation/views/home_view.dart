import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/route_placeholder_view.dart';

/// 홈 — 이어하기 · 추천 이야기 · 행성 위젯 · 하단 내비 허브.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoutePlaceholderView(path: AppRoutes.home, title: '홈');
  }
}
