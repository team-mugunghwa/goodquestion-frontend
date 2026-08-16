import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_canvas.dart';
import '../../data/datasources/account_recovery_remote_data_source.dart';

enum AccountRecoveryMode { findId, resetPassword }

class AccountRecoveryPage extends StatefulWidget {
  const AccountRecoveryPage({
    super.key,
    required this.mode,
    this.requestPasswordReset,
    this.findEmails,
  });

  final AccountRecoveryMode mode;
  final Future<void> Function(String email)? requestPasswordReset;

  /// 가입 이메일 찾기. null 이면 DI 의 데이터소스를 씁니다(테스트용 주입구).
  final Future<List<String>> Function({
    required String parentName,
    String? childName,
    int? childBirthYear,
  })?
  findEmails;

  @override
  State<AccountRecoveryPage> createState() => _AccountRecoveryPageState();
}

class _AccountRecoveryPageState extends State<AccountRecoveryPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _childNameController = TextEditingController();
  final TextEditingController _childBirthYearController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String? _error;
  bool _completed = false;
  bool _submitting = false;

  /// 서버가 찾아 준 가입 이메일. **이미 가려진 채로** 옵니다(`de***@...`).
  /// 비어 있으면 "못 찾았어요" - 오류가 아닙니다.
  List<String> _emails = const <String>[];

  bool get _findId => widget.mode == AccountRecoveryMode.findId;

  @override
  void dispose() {
    _nameController.dispose();
    _childNameController.dispose();
    _childBirthYearController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: AppCanvas.guardian(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            _TopBar(onBack: () => context.go(AppRoutes.login)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      children: <Widget>[
                        Image.asset(
                          AppAssets.logo,
                          height: 54,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _ModeTabs(mode: widget.mode),
                        const SizedBox(height: AppSpacing.md),
                        _RecoveryCard(
                          mode: widget.mode,
                          completed: _completed,
                          submitting: _submitting,
                          error: _error,
                          nameController: _nameController,
                          childNameController: _childNameController,
                          childBirthYearController: _childBirthYearController,
                          emailController: _emailController,
                          emails: _emails,
                          onSubmit: _submit,
                          onReset: _reset,
                          onLogin: () => context.go(AppRoutes.login),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    final String? validation = _findId ? _validateFindId() : _validateEmail();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      if (_findId) {
        final find =
            widget.findEmails ??
            getIt<AccountRecoveryRemoteDataSource>().findEmails;
        final List<String> emails = await find(
          parentName: _nameController.text.trim(),
          childName: _childNameController.text.trim(),
          childBirthYear: int.parse(_childBirthYearController.text.trim()),
        );
        if (mounted) {
          setState(() {
            _emails = emails;
            _completed = true;
          });
        }
        return;
      }
      final request =
          widget.requestPasswordReset ??
          getIt<AccountRecoveryRemoteDataSource>().requestPasswordReset;
      await request(_emailController.text.trim());
      if (mounted) setState(() => _completed = true);
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

  /// 아이 정보는 스키마상 선택이지만 **여기서는 필수로 받습니다.**
  ///
  /// 하나라도 비면 서버가 보호자 이름만으로 찾고 그때는 아이가 등록된 계정을
  /// 결과에서 뺍니다. 이 앱은 가입 마지막 단계에서 아이 프로필을 반드시
  /// 받으므로(`auth_view` 스텝 3) 실사용자는 전원 아이가 있습니다 - 즉 비워
  /// 두면 "항상 못 찾음"이고, 그건 사용자가 이해할 수 없는 실패입니다.
  /// 보내기 전에 막고 이유를 말해 주는 편이 낫습니다.
  String? _validateFindId() {
    final String year = _childBirthYearController.text.trim();
    if (_nameController.text.trim().isEmpty ||
        _childNameController.text.trim().isEmpty ||
        year.isEmpty) {
      return AuthRecoveryStrings.requiredFields;
    }
    final int? parsed = int.tryParse(year);
    if (!RegExp(r'^\d{4}$').hasMatch(year) ||
        parsed == null ||
        parsed < 1900 ||
        parsed > DateTime.now().year) {
      return AuthRecoveryStrings.invalidBirthYear;
    }
    return null;
  }

  String? _validateEmail() {
    final String email = _emailController.text.trim();
    if (email.isEmpty) return AuthRecoveryStrings.requiredFields;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return AuthRecoveryStrings.invalidEmail;
    }
    return null;
  }

  void _reset() => setState(() {
    _completed = false;
    _error = null;
    _submitting = false;
    _emails = const <String>[];
  });
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    child: Row(
      children: <Widget>[
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: AuthRecoveryStrings.backToLogin,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          AuthRecoveryStrings.backToLogin,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    ),
  );
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.mode});

  final AccountRecoveryMode mode;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xs),
    decoration: BoxDecoration(
      color: AppColors.ink100,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: _ModeTab(
            label: AuthRecoveryStrings.findIdTab,
            selected: mode == AccountRecoveryMode.findId,
            onTap: () => context.go(AppRoutes.findId),
          ),
        ),
        Expanded(
          child: _ModeTab(
            label: AuthRecoveryStrings.resetPasswordTab,
            selected: mode == AccountRecoveryMode.resetPassword,
            onTap: () => context.go(AppRoutes.findPassword),
          ),
        ),
      ],
    ),
  );
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? Colors.white : Colors.transparent,
    borderRadius: BorderRadius.circular(AppRadius.sm),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? AppColors.brandBlueDeep : AppColors.ink500,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ),
  );
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard({
    required this.mode,
    required this.completed,
    required this.submitting,
    required this.error,
    required this.nameController,
    required this.childNameController,
    required this.childBirthYearController,
    required this.emailController,
    required this.emails,
    required this.onSubmit,
    required this.onReset,
    required this.onLogin,
  });

  final AccountRecoveryMode mode;
  final bool completed;
  final bool submitting;
  final String? error;
  final TextEditingController nameController;
  final TextEditingController childNameController;
  final TextEditingController childBirthYearController;
  final TextEditingController emailController;

  /// 서버가 가려서 준 가입 이메일. 비어 있으면 못 찾은 것입니다.
  final List<String> emails;
  final VoidCallback onSubmit;
  final VoidCallback onReset;
  final VoidCallback onLogin;

  bool get _findId => mode == AccountRecoveryMode.findId;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xl),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: AppColors.ink100),
      boxShadow: const <BoxShadow>[
        BoxShadow(
          color: Color(0x120D0820),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: completed ? _done(context) : _form(context),
  );

  Widget _form(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Align(
        child: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.brandBlueSurface,
            shape: BoxShape.circle,
          ),
          child: Icon(
            _findId
                ? Icons.manage_search_rounded
                : Icons.mark_email_read_outlined,
            color: AppColors.brandBlueDeep,
            size: 32,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        _findId
            ? AuthRecoveryStrings.findIdTitle
            : AuthRecoveryStrings.resetTitle,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        _findId
            ? AuthRecoveryStrings.findIdDescription
            : AuthRecoveryStrings.resetDescription,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.ink500),
      ),
      const SizedBox(height: AppSpacing.xl),
      if (_findId) ...<Widget>[
        TextField(
          controller: nameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: AuthRecoveryStrings.guardianName,
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: childNameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: AuthRecoveryStrings.childName,
            hintText: AuthRecoveryStrings.childNameHint,
            prefixIcon: Icon(Icons.child_care_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: childBirthYearController,
          keyboardType: TextInputType.number,
          onSubmitted: (_) => onSubmit(),
          decoration: const InputDecoration(
            labelText: AuthRecoveryStrings.childBirthYear,
            hintText: AuthRecoveryStrings.childBirthYearHint,
            prefixIcon: Icon(Icons.cake_outlined),
          ),
        ),
      ] else
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const <String>[AutofillHints.email],
          onSubmitted: (_) => onSubmit(),
          decoration: const InputDecoration(
            labelText: AuthRecoveryStrings.email,
            hintText: AuthRecoveryStrings.emailHint,
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
        ),
      if (error != null) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        Text(
          error!,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      SizedBox(
        height: 54,
        child: FilledButton.icon(
          onPressed: submitting ? null : onSubmit,
          icon: submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_findId ? Icons.search_rounded : Icons.send_rounded),
          label: Text(
            _findId
                ? AuthRecoveryStrings.findIdAction
                : AuthRecoveryStrings.resetAction,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.shield_outlined, size: 18, color: AppColors.ink500),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              // ID 찾기는 목적 자체가 이메일을 알려 주는 것이라 결과가
              // 갈립니다 - "가입 여부와 관계없이 같은 안내"는 PW 찾기의 말입니다.
              _findId
                  ? AuthRecoveryStrings.childInfoNotice
                  : AuthRecoveryStrings.securityNotice,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.ink500),
            ),
          ),
        ],
      ),
    ],
  );

  /// ID 찾기인데 결과가 비었는가. **오류가 아니라 결과입니다** - 서버도
  /// 404 가 아니라 200 + 빈 목록을 줍니다.
  bool get _foundNothing => _findId && emails.isEmpty;

  String get _doneTitle {
    if (!_findId) return AuthRecoveryStrings.resetDoneTitle;
    return _foundNothing
        ? AuthRecoveryStrings.findIdEmptyTitle
        : AuthRecoveryStrings.findIdDoneTitle;
  }

  String get _doneBody {
    if (!_findId) return AuthRecoveryStrings.resetDoneBody;
    return _foundNothing
        ? AuthRecoveryStrings.findIdEmptyBody
        : AuthRecoveryStrings.findIdDoneBody;
  }

  Widget _done(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Icon(
        _foundNothing ? Icons.search_off_rounded : Icons.check_circle_rounded,
        size: 72,
        color: _foundNothing ? AppColors.ink300 : AppColors.success,
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        _doneTitle,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: AppSpacing.sm),
      Text(
        _doneBody,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.ink500),
      ),
      // 형제가 있거나 동명이인이면 여러 개가 옵니다. 하나로 가정하지 않습니다.
      for (final String email in emails) ...<Widget>[
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.brandBlueSurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            email,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.brandBlueDeep,
            ),
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.xl),
      FilledButton(
        onPressed: onLogin,
        child: const Text(AuthRecoveryStrings.backToLogin),
      ),
      TextButton(
        onPressed: onReset,
        child: Text(
          _findId
              ? AuthRecoveryStrings.findIdRetry
              : AuthRecoveryStrings.resend,
        ),
      ),
    ],
  );
}
