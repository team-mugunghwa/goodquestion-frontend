import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_canvas.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../domain/entities/auth_options.dart';
import '../../domain/usecases/auth_use_cases.dart';
import '../../../mypage/domain/usecases/my_page_use_cases.dart';
import '../viewmodels/auth_view_model.dart';
import '../widgets/auth_step_indicator.dart';
import '../widgets/child_profile_step.dart';
import '../widgets/consent_step.dart';
import '../widgets/sign_in_step.dart';

/// 보호자 인증 — 서비스의 유일한 관문.
///
/// ## 세 가지를 한 라우트 안에서 끝냅니다
///
/// ① 로그인/가입 → ② 약관·아동 개인정보·마케팅 동의 → ③ 최초 아이 프로필.
/// 스텝을 별도 라우트로 쪼개지 않은 건, 중간에 이탈했다가 돌아와도 어디서든
/// `/auth` 하나로 수렴하게 하기 위해서입니다. (PRD F-01)
///
/// **"프로필 없으면 통과 불가"가 이 화면의 정체성입니다.** 스텝 3을 건너뛰거나
/// 나중으로 미루는 경로를 만들지 마세요 — 아이 프로필이 없으면 발화·단어장·
/// 리포트를 귀속시킬 데가 없습니다.
///
/// 사용자는 **보호자**입니다. 아이 화면의 그림·음성 우선 원칙이 적용되지 않고
/// 일반 성인용 인증 UX 를 씁니다. 나이 선택만 버튼형으로 두어 마찰을 줄입니다.
class AuthPage extends StatelessWidget {
  const AuthPage({super.key, this.startAtChildProfile = false});

  /// 로그인은 됐지만 프로필이 없는 계정으로 들어온 경우.
  /// (`/auth?step=child` — 홈·이야기 상세의 프로필 게이트가 이리로 보냅니다)
  final bool startAtChildProfile;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthViewModel>(
      create: (_) => AuthViewModel(
        getIt<GetAuthOptionsUseCase>(),
        getIt<SignInWithSocialUseCase>(),
        getIt<SignInWithEmailUseCase>(),
        getIt<SaveConsentsUseCase>(),
        getIt<CreateChildUseCase>(),
        getIt<SignOutUseCase>(),
        loadCurrentChildName: () async =>
            (await getIt<GetMyPageSummaryUseCase>()()).child?.name,
        startAtChildProfile: startAtChildProfile,
      )..load(),
      child: const AuthView(),
    );
  }
}

/// ViewModel 이 이미 위에 있다고 가정하는 본체. (테스트에서 직접 씁니다)
class AuthView extends StatefulWidget {
  const AuthView({super.key});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  /// 흔들림을 한 번만 트리거하기 위한 카운터.
  int _shakeCount = 0;

  /// 완료 직후의 짧은 환영. 끝나면 홈으로 갑니다.
  bool _welcoming = false;

  @override
  Widget build(BuildContext context) {
    final AuthViewModel vm = context.watch<AuthViewModel>();

    if (vm.takeConsentShake()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _shakeCount++);
      });
    }

    if (vm.completed && !_welcoming) {
      _welcoming = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish(vm));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppCanvas.guardian(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              // 태블릿에서 폼을 화면 끝까지 늘리면 입력 필드가 우스꽝스럽게
              // 길어집니다. 인증 폼은 좁을수록 읽기 쉽습니다.
              constraints: BoxConstraints(
                maxWidth: vm.step == AuthStep.signIn
                    ? 980
                    : AppSizes.bubbleMaxWidth,
              ),
              child: _body(context, vm),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AuthViewModel vm) {
    if (_welcoming) return _Welcome(name: vm.childName.trim());
    if (vm.state.isError) {
      return AppErrorView(
        message: vm.errorMessage ?? AuthStrings.loadFailed,
        onRetry: vm.load,
      );
    }
    final AuthOptions? options = vm.options;
    if (options == null) return const AppLoadingView();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 스텝 1 은 인디케이터를 달지 않습니다 — 로그인만 하러 온 기존
        // 사용자에게 "3단계 가입"으로 보이면 부담스럽습니다.
        if (vm.step != AuthStep.signIn)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => _back(context, vm),
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: AppStrings.back,
                ),
                const Spacer(),
                AuthStepIndicator(current: vm.stepNumber),
                const Spacer(),
                // 뒤로가기 버튼과 좌우 균형을 맞춥니다.
                const SizedBox(width: AppSizes.tapGuardian),
              ],
            ),
          ),
        Expanded(
          child: AnimatedSwitcher(
            duration: respect(context, AppDurations.normal),
            switchInCurve: AppCurves.standard,
            switchOutCurve: AppCurves.exit,
            layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
              fit: StackFit.expand,
              alignment: Alignment.topCenter,
              children: <Widget>[...previous, if (current != null) current],
            ),
            child: switch (vm.step) {
              AuthStep.signIn => SignInStep(
                key: const ValueKey<String>('auth-sign-in'),
                vm: vm,
                options: options,
              ),
              AuthStep.consent => ConsentStep(
                key: const ValueKey<String>('auth-consent'),
                vm: vm,
                options: options,
                shakeTrigger: _shakeCount,
                onOpenDocument: (ConsentItem item) =>
                    _openDocument(context, item),
              ),
              AuthStep.childProfile => ChildProfileStep(
                key: const ValueKey<String>('auth-child'),
                vm: vm,
                options: options,
              ),
            },
          ),
        ),
      ],
    );
  }

  /// 프로필 없는 기존 계정이 스텝 3 에서 뒤로 가려 할 때는 **로그아웃**입니다.
  ///
  /// 허용하지 않으면 사용자가 갇히고, 홈으로 보내면 게이트 원칙이 깨집니다.
  /// 남는 선택지가 로그아웃뿐이라 확인을 받고 처리합니다.
  Future<void> _back(BuildContext context, AuthViewModel vm) async {
    if (!vm.backMeansSignOut) {
      vm.goBack();
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        content: const Text(AuthStrings.signOutConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AuthStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AuthStrings.signOutConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed == true) await vm.signOut();
  }

  /// 약관 본문. 실제 문서가 들어오면 이 시트 안쪽만 채우면 됩니다.
  void _openDocument(BuildContext context, ConsentItem item) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                item.title,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AuthStrings.documentPlaceholder,
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 환영 문구를 잠깐 보여 준 뒤 홈으로. 여기가 이 화면의 유일한 출구입니다.
  Future<void> _finish(AuthViewModel vm) async {
    await Future<void>.delayed(AppDurations.turn);
    if (!mounted) return;
    context.go(AppRoutes.home);
  }
}

/// 완료 직후의 짧은 환영.
///
/// 곧바로 화면이 바뀌면 "내가 뭘 한 거지?" 싶습니다. 한 박자만 둡니다.
class _Welcome extends StatelessWidget {
  const _Welcome({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        AuthStrings.welcome(name),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineLarge,
      ),
    );
  }
}
