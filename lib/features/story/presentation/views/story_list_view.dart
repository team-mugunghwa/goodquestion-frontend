import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/route_placeholder_view.dart';

/// 이야기 목록 — 주제별 필터로 이야기 탐색.
class StoryListPage extends StatelessWidget {
  const StoryListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoutePlaceholderView(path: AppRoutes.stories, title: '이야기 목록');
  }
}
