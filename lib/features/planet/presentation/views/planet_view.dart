import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../auth/data/datasources/auth_token_store.dart';
import '../../../mypage/domain/repositories/my_page_repository.dart';
import '../viewmodels/planet_view_model.dart';
import '../widgets/planet_frame.dart';

/// 내 행성 — 별가루로 산 아이템으로 자기 섬을 꾸미는 화면. 아이 동선의 종착지.
///
/// 3D 화면 자체는 본체와 **별도로 렌더되는 행성 웹앱**(`web/planet_app/`,
/// 별도 저장소의 빌드 산출물)이고, 이 페이지는 신원(부모 토큰 + childId)을
/// 넘기고 신호(나가기 등)를 받는 껍데기입니다.
/// 규약 전문: 팀원공유 `행성_연동규약.md` · 행성앱 README
class PlanetPage extends StatelessWidget {
  const PlanetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PlanetViewModel>(
      create: (_) => PlanetViewModel(
        getIt<AuthTokenStore>(),
        getIt<ChildProfileRepository>(),
      )..load(),
      child: const _PlanetView(),
    );
  }
}

class _PlanetView extends StatelessWidget {
  const _PlanetView();

  @override
  Widget build(BuildContext context) {
    final PlanetViewModel viewModel = context.watch<PlanetViewModel>();

    return Scaffold(
      body: switch (viewModel.state) {
        ViewState.idle || ViewState.loading => const AppLoadingView(),
        ViewState.error => AppKidErrorView(onRetry: viewModel.load),
        // 아이 프로필이 아직 없는 계정. 서버 API 가 childId 없이는 행성을
        // 못 주므로, 프로필부터 만들도록 홈으로 돌려보냅니다.
        ViewState.success when !viewModel.hasChild => AppKidMessageView(
          message: '아이 프로필을 만들면 나만의 행성이 생겨요',
          actionIcon: AppIcons.home,
          actionLabel: '홈으로',
          onAction: () => context.go(AppRoutes.home),
        ),
        ViewState.success => PlanetFrame(
          token: viewModel.token ?? '',
          childId: viewModel.childId!,
          // 이탈 목적지는 본체가 정하기로 한 규약입니다. 행성은 홈에서 들어오는
          // 화면이므로 홈으로 돌려보냅니다. 홈은 재진입 시 별가루를 다시 읽습니다.
          onExit: () => context.go(AppRoutes.home),
        ),
      },
    );
  }
}
