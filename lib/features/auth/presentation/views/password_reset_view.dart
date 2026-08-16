import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_canvas.dart';
import '../../../../core/widgets/cosmic_backdrop.dart';
import '../../data/datasources/account_recovery_remote_data_source.dart';

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({
    super.key,
    required this.token,
    this.confirmPasswordReset,
  });

  final String token;
  final Future<void> Function(String token, String password)?
  confirmPasswordReset;

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();
  String? _error;
  bool _submitting = false;
  bool _completed = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: AppCanvas.guardian(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const CosmicBackdrop(seed: 5, planetCenterX: 0.38),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: _completed ? _done() : _form(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _form() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(
        AuthRecoveryStrings.newPasswordTitle,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: AppSpacing.xl),
      TextField(
        controller: _password,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: AuthRecoveryStrings.newPassword,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      TextField(
        controller: _confirmation,
        obscureText: true,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: AuthRecoveryStrings.confirmPassword,
        ),
      ),
      if (_error != null) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      FilledButton(
        onPressed: _submitting ? null : _submit,
        child: _submitting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(AuthRecoveryStrings.changePassword),
      ),
    ],
  );

  Widget _done() => Column(
    children: <Widget>[
      const Icon(Icons.check_circle_rounded, size: 72, color: Colors.green),
      const SizedBox(height: AppSpacing.md),
      const Text(AuthRecoveryStrings.passwordChanged),
      const SizedBox(height: AppSpacing.lg),
      FilledButton(
        onPressed: () => context.go(AppRoutes.auth),
        child: const Text(AuthRecoveryStrings.backToLogin),
      ),
    ],
  );

  Future<void> _submit() async {
    if (widget.token.isEmpty) {
      return _setError(AuthRecoveryStrings.invalidResetLink);
    }
    if (_password.text.length < 8) {
      return _setError(AuthRecoveryStrings.passwordRule);
    }
    if (_password.text != _confirmation.text) {
      return _setError(AuthRecoveryStrings.passwordMismatch);
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      final confirm =
          widget.confirmPasswordReset ??
          (String token, String password) =>
              getIt<AccountRecoveryRemoteDataSource>().confirmPasswordReset(
                token: token,
                newPassword: password,
              );
      await confirm(widget.token, _password.text);
      if (mounted) {
        setState(() => _completed = true);
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = Failure.fromException(error).message);
      }
    } on Object {
      if (mounted) setState(() => _error = AuthRecoveryStrings.requestFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _setError(String message) => setState(() => _error = message);
}
