import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/route_placeholder_view.dart';

/// 보호자 리포트 상세 — 세션 단위 역량 분석·대표 발화·가정 연계 대화 가이드.
///
/// 알림 딥링크로 들어와도 보호자 확인 게이트를 통과해야 합니다.
class ReportDetailPage extends StatelessWidget {
  const ReportDetailPage({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return RoutePlaceholderView(
      path: AppRoutes.reportDetailOf(sessionId),
      title: '보호자 리포트 상세',
    );
  }
}
