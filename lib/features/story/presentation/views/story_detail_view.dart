import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/route_placeholder_view.dart';

/// 이야기 상세 — 요약·난이도·상황·아이 역할 확인.
///
/// 시작하기를 누르면 세션을 만든 뒤 `AppRoutes.playOf(sessionId)` 로 이동합니다.
class StoryDetailPage extends StatelessWidget {
  const StoryDetailPage({required this.storyId, super.key});

  final String storyId;

  @override
  Widget build(BuildContext context) {
    return RoutePlaceholderView(
      path: AppRoutes.storyDetailOf(storyId),
      title: '이야기 상세',
    );
  }
}
