import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/auth_options.dart';
import '../viewmodels/auth_view_model.dart';

/// 스텝 1 — 로그인.
///
/// 소셜 버튼 두 개가 화면을 지배해야 합니다. 이메일은 아래에 두되 없애지는
/// 않습니다 — 소셜 계정이 없는 보호자가 갇힙니다.
class SignInStep extends StatelessWidget {
  const SignInStep({super.key, required this.vm, required this.options});

  final AuthViewModel vm;
  final AuthOptions options;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool busy = vm.isSubmitting;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: <Widget>[
        // 캐릭터 에셋이 나오면 이 이미지를 갈아 끼웁니다.
        Image.asset(
          AppAssets.logo,
          height: AppSizes.illustration,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          AuthStrings.tagline,
          textAlign: TextAlign.center,
          style: text.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xxl),

        for (final SocialProvider provider in options.providers) ...<Widget>[
          _SocialButton(
            provider: provider,
            onPressed: busy
                ? null
                : () => vm.signInWithSocial(provider.provider),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        const SizedBox(height: AppSpacing.md),
        const _OrDivider(),
        const SizedBox(height: AppSpacing.md),

        TextField(
          decoration: const InputDecoration(labelText: AuthStrings.email),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const <String>[AutofillHints.email],
          enabled: !busy,
          onChanged: vm.setEmail,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          decoration: const InputDecoration(labelText: AuthStrings.password),
          obscureText: true,
          autofillHints: const <String>[AutofillHints.password],
          enabled: !busy,
          onChanged: vm.setPassword,
          onSubmitted: busy ? null : (_) => vm.submitEmail(),
        ),

        if (vm.formError != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            vm.formError!,
            style: text.bodySmall?.copyWith(color: AppColors.danger),
          ),
        ],

        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: busy ? null : vm.submitEmail,
          child: busy
              ? const _ButtonSpinner()
              : Text(vm.isSignUpMode ? AuthStrings.signUp : AuthStrings.signIn),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: busy ? null : vm.toggleSignUpMode,
          child: Text(
            vm.isSignUpMode
                ? AuthStrings.backToSignIn
                : AuthStrings.signUpWithEmail,
          ),
        ),
      ],
    );
  }
}

/// 소셜 로그인 버튼. 브랜드 색을 쓰지 않고 **흰 면 + 테두리**로 통일합니다.
///
/// 카카오 노랑을 그대로 쓰면 이 앱에서 노랑이 갖는 뜻(별가루)과 충돌합니다.
/// 실제 배포 전에는 각 제공자의 브랜드 가이드를 확인해야 합니다.
class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.provider, required this.onPressed});

  final SocialProvider provider;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSizes.tapChildSecondary),
      ),
      child: Text(provider.label),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            AuthStrings.orDivider,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// 버튼 안에서 도는 스피너. 크기를 글자 높이에 맞춥니다.
class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: AppSpacing.lg,
    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.surface),
  );
}
