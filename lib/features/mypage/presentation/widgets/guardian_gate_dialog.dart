import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/confirm_actions.dart';
import '../../data/datasources/settings_remote_data_source.dart';

/// 보호자 확인 게이트. **통과하면 true** 입니다.
///
/// 아이에게 "여긴 어른 것"이라는 신호를 주는 게 게이트의 절반입니다 —
/// 그래서 방패 아이콘과 문구를 그대로 둡니다.
///
/// ## 계정에 따라 묻는 것이 다릅니다
///
/// 먼저 `GET /parents/me` 로 보호자를 조회합니다.
///
/// - **소셜 계정**(`provider` 에 값이 있음): 비밀번호 자체가 없어 물어볼 수
///   없습니다. 다이얼로그를 띄우지 않고 그대로 통과시킵니다(서버도 소셜
///   계정이 확인 API 를 부르면 403 으로 거절합니다).
/// - **이메일 계정**(`provider` 가 null): 비밀번호를 받아
///   `POST /parents/me/verify-password` 로 확인합니다.
///
/// 미리 받아 캐시하지 않습니다 — [GuardianGate] 덕에 세션당 한 번만 열리므로
/// 그때 부르면 충분하고, 캐시는 계정이 바뀌었을 때 틀린 답을 줍니다.
///
/// ## 시도 횟수는 제한하지 않습니다
///
/// 이미 로그인한 사용자이고, 아이가 우연히 들어가는 것을 막는 것이 목적이라
/// 위험도가 낮습니다. 틀리면 다이얼로그를 닫지 않고 그 자리에서 다시 받습니다.
///
/// ## 실패하면 통과시키지 않습니다
///
/// 조회든 확인이든 네트워크 문제로 답을 못 받으면 막습니다. 통과시키면
/// 연결이 끊긴 상태에서 게이트가 그대로 뚫립니다 — 막았을 때의 손해는
/// 보호자가 잠깐 못 보는 것뿐이고 다시 시도하면 됩니다.
Future<bool> showGuardianGateDialog(
  BuildContext context, {
  SettingsRemoteDataSource? remote,
}) async {
  final SettingsRemoteDataSource dataSource =
      remote ?? getIt<SettingsRemoteDataSource>();

  while (true) {
    final Map<String, dynamic> parent;
    try {
      parent = await dataSource.getParent();
    } on Object {
      if (!context.mounted) return false;
      final bool retry = await _showRetryDialog(context);
      if (retry) continue;
      return false;
    }
    if (!context.mounted) return false;

    // 값이 있으면 소셜입니다. 서버가 LOCAL 을 null 로 바꿔 내리므로
    // "값이 있으면 소셜"로만 판단하면 됩니다. (`docs/API.md` ParentResponse)
    if (parent['provider'] != null) return true;

    final bool? passed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) =>
          _PasswordGateDialog(remote: dataSource),
    );
    return passed ?? false;
  }
}

/// 보호자 조회부터 실패했을 때. 아직 물어볼 것도 못 정한 상태라 비밀번호
/// 칸 대신 다시 시도만 내밉니다.
Future<bool> _showRetryDialog(BuildContext context) async {
  final TextTheme text = Theme.of(context).textTheme;
  final bool? retry = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      icon: const Icon(
        AppIcons.guardianGate,
        size: AppSizes.iconGuardian,
        color: AppColors.brandBlueDeep,
      ),
      title: Text(MyPageStrings.gateTitle, style: text.titleLarge),
      content: Text(MyPageStrings.gateNetworkError, style: text.bodyMedium),
      actionsPadding: ConfirmActions.dialogPadding,
      actions: <Widget>[
        ConfirmActions(
          cancelLabel: MyPageStrings.gateCancel,
          confirmLabel: MyPageStrings.gateRetry,
          onCancel: () => Navigator.of(context).pop(false),
          onConfirm: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return retry ?? false;
}

/// 비밀번호를 받는 게이트. **틀려도 닫지 않습니다** — 안내만 이 안에 띄우고
/// 그대로 다시 받습니다.
class _PasswordGateDialog extends StatefulWidget {
  const _PasswordGateDialog({required this.remote});

  final SettingsRemoteDataSource remote;

  @override
  State<_PasswordGateDialog> createState() => _PasswordGateDialogState();
}

class _PasswordGateDialogState extends State<_PasswordGateDialog> {
  final TextEditingController _password = TextEditingController();
  bool _verifying = false;

  /// 틀린 비밀번호·네트워크 실패 안내. 두 경우 모두 이 자리에만 뜹니다.
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final String password = _password.text;
    if (password.isEmpty || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await widget.remote.verifyPassword(password);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on UnauthorizedException {
      // 세션 만료가 아니라 "틀렸다" 입니다. 시도 횟수는 세지 않습니다.
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = MyPageStrings.gateWrongPassword;
      });
      _password.clear();
    } on Object {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = MyPageStrings.gateNetworkError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return AlertDialog(
      icon: const Icon(
        AppIcons.guardianGate,
        size: AppSizes.iconGuardian,
        color: AppColors.brandBlueDeep,
      ),
      title: Text(MyPageStrings.gateTitle, style: text.titleLarge),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(MyPageStrings.gateBody, style: text.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _password,
            obscureText: true,
            autofocus: true,
            enabled: !_verifying,
            onChanged: (_) {
              // 다시 입력하기 시작하면 지난 안내는 치웁니다.
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _verify(),
            decoration: InputDecoration(
              labelText: MyPageStrings.gatePasswordLabel,
              errorText: _error,
            ),
          ),
        ],
      ),
      actionsPadding: ConfirmActions.dialogPadding,
      actions: <Widget>[
        ConfirmActions(
          cancelLabel: MyPageStrings.gateCancel,
          confirmLabel: MyPageStrings.gateConfirm,
          onCancel: _verifying ? null : () => Navigator.of(context).pop(false),
          onConfirm: _verifying ? null : _verify,
        ),
      ],
    );
  }
}
