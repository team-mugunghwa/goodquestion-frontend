import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/route_placeholder_view.dart';

/// 장면 진행 — 도입 내레이션 → 어려운 단어 미리보기 → 장면 반복.
///
/// 장면 안의 단계(내레이션·미션·음성 대화 루프)는 **화면 내부 상태**입니다.
/// 라우트를 더 쪼개지 마세요. 다음 장면은 아이가 직접 넘깁니다.
class PlayPage extends StatelessWidget {
  const PlayPage({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return RoutePlaceholderView(
      path: AppRoutes.playOf(sessionId),
      title: '장면 진행',
    );
  }
}
