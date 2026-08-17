import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/confirm_actions.dart';
import '../../../../core/widgets/guardian_list.dart';
import '../../../../core/widgets/policy_document_view.dart';
import '../../../auth/domain/usecases/auth_use_cases.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/guardian_gate.dart';
import '../viewmodels/settings_view_model.dart';

/// 설정 항목 묶음. **마이페이지 안에서** 펼쳐집니다.
///
/// 예전에는 `/settings` 라는 별도 화면이었는데, 알림 토글 하나 바꾸거나
/// 로그아웃 한 번 하려고 마이페이지에서 한 뎁스를 더 들어가야 했습니다.
/// 보호자가 이 앱에 오래 머무는 화면이 아니라서, 들어갔다 나오는 왕복이
/// 그대로 마찰이 됩니다. 그래서 화면을 합치고 **묶음으로 구분**합니다.
///
/// | 묶음 | 내용 |
/// |---|---|
/// | 알림 | 리포트 도착 · 마케팅 수신 |
/// | 안내 | 알림함 · 공지 · 이용 안내 · 고객센터 |
/// | 약관·정책 | 이용약관 · 아동 개인정보 · 개인정보 |
/// | 계정 | 로그인 수단 · 로그아웃 |
///
/// 마이페이지가 이미 쓰고 있는 [GuardianSection] 을 그대로 써서, 합쳐도
/// 한 화면이 두 가지 문법으로 갈리지 않게 합니다.
class SettingsSections extends StatelessWidget {
  const SettingsSections({super.key, required this.vm});

  final SettingsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final AppSettings? settings = vm.settings;
    // 설정이 아직 안 왔어도 마이페이지 위쪽(프로필·리포트)은 이미 보입니다.
    // 여기만 조용히 비워 두는 편이 화면 전체를 스켈레톤으로 덮는 것보다 낫습니다.
    if (settings == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 알림이 가장 위입니다 — 보호자가 설정을 여는 가장 잦은 목적입니다.
        GuardianSection(
          title: SettingsStrings.notificationGroup,
          children: <Widget>[
            GuardianSwitchTile(
              label: SettingsStrings.reportNotification,
              description: SettingsStrings.reportNotificationDesc,
              value: settings.reportNotification,
              onChanged: (bool value) =>
                  vm.setReportNotification(enabled: value),
            ),
            GuardianSwitchTile(
              label: SettingsStrings.marketingConsent,
              value: settings.marketingConsent,
              onChanged: (bool value) => vm.setMarketingConsent(enabled: value),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        GuardianSection(
          title: SettingsStrings.infoGroup,
          children: <Widget>[
            GuardianTile(
              icon: AppIcons.notification,
              label: SettingsStrings.notifications,
              onTap: () => context.push(AppRoutes.notifications),
            ),
            GuardianTile(
              icon: AppIcons.notice,
              label: SettingsStrings.notice,
              showBadge: settings.hasNewNotice,
              onTap: () => context.push(AppRoutes.notices),
            ),
            GuardianTile(
              icon: AppIcons.guide,
              label: SettingsStrings.guide,
              onTap: () => context.push(AppRoutes.guides),
            ),
            GuardianTile(
              icon: AppIcons.support,
              label: SettingsStrings.support,
              onTap: () => context.push(AppRoutes.support),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        GuardianSection(
          title: SettingsStrings.policyGroup,
          children: <Widget>[
            GuardianTile(
              icon: AppIcons.terms,
              label: SettingsStrings.terms,
              onTap: () => _openDocument(context, SettingsStrings.terms),
            ),
            // 아동 개인정보 동의는 가입 시 별도로 받으므로 행도 별도입니다.
            GuardianTile(
              icon: AppIcons.privacy,
              label: SettingsStrings.childPrivacy,
              trailingText: settings.consentAt == null
                  ? SettingsStrings.consentRequired
                  : SettingsStrings.consentComplete,
              onTap: () => _openDocument(context, SettingsStrings.childPrivacy),
            ),
            GuardianTile(
              icon: AppIcons.privacy,
              label: SettingsStrings.privacy,
              onTap: () => _openDocument(context, SettingsStrings.privacy),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        GuardianSection(
          title: SettingsStrings.accountGroup,
          children: <Widget>[
            GuardianTile(
              icon: AppIcons.account,
              label: _accountLabel(settings),
              trailingText: settings.accountLabel,
              showChevron: false,
            ),
            GuardianTile(
              icon: AppIcons.signOut,
              label: SettingsStrings.signOut,
              showChevron: false,
              onTap: () => _confirmSignOut(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Text(
            SettingsStrings.appVersion(settings.appVersion),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.ink500),
          ),
        ),
      ],
    );
  }

  String _accountLabel(AppSettings settings) => switch (settings.accountType) {
    'kakao' => '카카오 계정',
    'google' => '구글 계정',
    'email' => '이메일 계정',
    _ => '로그인 계정',
  };

  /// 약관·정책 본문을 번들 문서(assets/policies)에서 읽어 시트로 보여줍니다.
  /// 라우트를 늘리지 않는 이유는 화면 12개 지도를 벗어나지 않기 위해서입니다.
  /// (`docs/ARCHITECTURE.md`)
  ///
  /// 문서 파일은 법무 검토 전 초안입니다 - 파일만 바꾸면 화면은 그대로
  /// 따라갑니다.
  void _openDocument(BuildContext context, String title) {
    final String? asset = switch (title) {
      SettingsStrings.terms => 'assets/policies/terms.md',
      SettingsStrings.privacy => 'assets/policies/privacy.md',
      SettingsStrings.childPrivacy => 'assets/policies/child_privacy.md',
      _ => null,
    };
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .82,
          child: asset == null
              ? Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    SettingsStrings.documentPlaceholder,
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                )
              : PolicyDocumentView(title: title, assetPath: asset),
        ),
      ),
    );
  }

  /// 로그아웃은 되돌리기 어려운 동작이라 확인을 한 번 받습니다.
  Future<void> _confirmSignOut(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text(SettingsStrings.signOutConfirm),
        actionsPadding: ConfirmActions.dialogPadding,
        actions: <Widget>[
          ConfirmActions(
            cancelLabel: SettingsStrings.cancel,
            confirmLabel: SettingsStrings.signOut,
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onConfirm: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await getIt<SignOutUseCase>()();
    if (!context.mounted) return;
    // 보호자 세션이 끊기므로 리포트 게이트도 다시 잠급니다.
    getIt<GuardianGate>().reset();
    context.go(AppRoutes.auth);
  }
}
