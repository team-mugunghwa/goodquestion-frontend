import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/route_placeholder_view.dart';

/// 보호자 리포트 목록 — 보호자 확인 게이트를 통과해야 진입합니다.
class ReportListPage extends StatelessWidget {
  const ReportListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoutePlaceholderView(
      path: AppRoutes.report,
      title: '보호자 리포트 목록',
    );
  }
}
