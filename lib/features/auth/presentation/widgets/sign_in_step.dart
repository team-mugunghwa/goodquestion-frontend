import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/auth_options.dart';
import '../viewmodels/auth_view_model.dart';

class SignInStep extends StatelessWidget {
  const SignInStep({super.key, required this.vm, required this.options});

  final AuthViewModel vm;
  final AuthOptions options;

  @override
  Widget build(BuildContext context) {
    // 소셜 우선의 단일 카드. 태블릿에서 카드 두 장을 나란히 두면 시선이
    // 갈라지고 폼이 낮게 눌립니다 — 가운데 한 장이 읽는 순서를 만듭니다.
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      children: <Widget>[
        Image.asset(AppAssets.logo, height: 62, fit: BoxFit.contain),
        const SizedBox(height: 10),
        Text(
          AuthStrings.tagline,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.ink500),
        ),
        const SizedBox(height: 28),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _SocialPanel(vm: vm, options: options),
                  const SizedBox(height: 24),
                  // "또는 이메일로" 구분선. 이메일은 보조 경로입니다.
                  Row(
                    children: <Widget>[
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          AuthStrings.emailSignIn,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.ink500),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _EmailPanel(vm: vm),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      // 우주 배경이 살짝 비치도록 아주 옅게 투명합니다.
      // 테두리 없이 그림자만으로 띄워야 카드가 종이가 아니라 면으로 보입니다.
      color: AppColors.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      boxShadow: AppShadows.lift,
    ),
    child: child,
  );
}

class _SocialPanel extends StatelessWidget {
  const _SocialPanel({required this.vm, required this.options});

  final AuthViewModel vm;
  final AuthOptions options;

  @override
  Widget build(BuildContext context) {
    final Set<String> enabledProviders = options.providers
        .map((SocialProvider item) => item.provider)
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SocialButton(
          label: AuthStrings.googleSignIn,
          icon: AppAssets.googleLogo,
          onPressed: vm.isSubmitting || !enabledProviders.contains('google')
              ? null
              : () => vm.signInWithSocial('google'),
        ),
        const SizedBox(height: 14),
        _SocialButton(
          label: AuthStrings.kakaoSignIn,
          icon: AppAssets.kakaoLogo,
          backgroundColor: const Color(0xFFFEE500),
          foregroundColor: const Color(0xFF191919),
          borderColor: const Color(0xFFF2D900),
          onPressed: vm.isSubmitting || !enabledProviders.contains('kakao')
              ? null
              : () => vm.signInWithSocial('kakao'),
        ),
        const SizedBox(height: 18),
        Text(
          '간편하고 안전하게 시작하세요',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.ink500),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor = AppColors.surface,
    this.foregroundColor = AppColors.ink900,
    this.borderColor = AppColors.ink300,
  });

  final String label;
  final String icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 58,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: SvgPicture.asset(icon, width: 26, height: 26),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _EmailPanel extends StatelessWidget {
  const _EmailPanel({required this.vm});

  final AuthViewModel vm;

  @override
  Widget build(BuildContext context) {
    final bool busy = vm.isSubmitting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (vm.isSignUpMode) ...<Widget>[
          TextField(
            decoration: const InputDecoration(
              labelText: AuthStrings.name,
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            enabled: !busy,
            onChanged: vm.setGuardianName,
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          decoration: const InputDecoration(
            labelText: AuthStrings.email,
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const <String>[AutofillHints.email],
          enabled: !busy,
          onChanged: vm.setEmail,
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: AuthStrings.password,
            prefixIcon: Icon(Icons.lock_outline_rounded),
          ),
          obscureText: true,
          autofillHints: const <String>[AutofillHints.password],
          enabled: !busy,
          onChanged: vm.setPassword,
          onSubmitted: busy ? null : (_) => vm.submitEmail(),
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            Checkbox(
              value: vm.rememberMe,
              onChanged: busy
                  ? null
                  : (bool? value) => vm.setRememberMe(value ?? false),
            ),
            const Text(AuthStrings.keepSignedIn),
          ],
        ),
        if (vm.formError != null) ...<Widget>[
          Text(
            vm.formError!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: busy ? null : vm.submitEmail,
            child: busy
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    vm.isSignUpMode ? AuthStrings.signUp : AuthStrings.signIn,
                  ),
          ),
        ),
        const SizedBox(height: 12),
        // 가운뎃점으로 잇던 세 링크를 간격만으로 나란히 둡니다.
        // 문자 구분자는 버튼 사이에서 눌리지 않는 글자로 남아 지저분합니다.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          children: <Widget>[
            TextButton(
              onPressed: busy ? null : vm.toggleSignUpMode,
              child: Text(
                vm.isSignUpMode
                    ? AuthStrings.backToSignIn
                    : AuthStrings.signUpWithEmail,
              ),
            ),
            TextButton(
              onPressed: busy ? null : () => context.go(AppRoutes.findId),
              child: const Text(AuthStrings.findId),
            ),
            TextButton(
              onPressed: busy ? null : () => context.go(AppRoutes.findPassword),
              child: const Text(AuthStrings.findPassword),
            ),
          ],
        ),
      ],
    );
  }
}
