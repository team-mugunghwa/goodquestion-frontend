import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/route_placeholder_view.dart';

/// 말하기 후 활동 — 장면 카드 순서 맞추기 → 핵심 단어 → 이야기 전체 재구성.
class PlayRecapPage extends StatelessWidget {
  const PlayRecapPage({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return RoutePlaceholderView(
      path: AppRoutes.playRecapOf(sessionId),
      title: '말하기 후 활동',
    );
  }
}
