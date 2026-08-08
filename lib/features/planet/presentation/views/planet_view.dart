import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/route_placeholder_view.dart';

/// 내 행성 — 별가루 낙하 연출·아이템 배치·리포트 진입점. 아이 동선의 종착지.
class PlanetPage extends StatelessWidget {
  const PlanetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoutePlaceholderView(path: AppRoutes.planet, title: '내 행성');
  }
}
