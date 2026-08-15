import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/widgets/app_state_views.dart';

/// 웹이 아닌 플랫폼의 대체 화면.
///
/// 행성 웹앱은 WebGL 로 그리는 별도 웹앱이라 지금은 웹 빌드에서만 열립니다.
/// 네이티브에서 열려면 webview_flutter 를 붙여 같은 규약(쿼리로 토큰·childId,
/// postMessage 신호)을 구현하면 됩니다. → 팀원공유 `행성_연동규약.md`
class PlanetFrame extends StatelessWidget {
  const PlanetFrame({
    required this.token,
    required this.childId,
    required this.onExit,
    super.key,
  });

  /// 부모 accessToken. 행성이 Authorization 헤더에 싣습니다.
  final String token;

  /// 어느 아이의 행성인지. 서버 경로(`/api/children/{childId}/...`)에 들어갑니다.
  final String childId;

  /// 행성이 "나가기" 신호를 보냈을 때. 목적지는 본체가 정합니다.
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return AppKidMessageView(
      message: '행성은 웹 화면에서 열 수 있어요',
      actionIcon: AppIcons.home,
      actionLabel: '홈으로',
      onAction: onExit,
    );
  }
}
