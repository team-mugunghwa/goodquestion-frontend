import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/guardian_list.dart';
import '../../../../core/widgets/guardian_scaffold.dart';
import '../../../../core/widgets/skeleton_box.dart';
import '../../../auth/domain/usecases/auth_use_cases.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/guardian_gate.dart';
import '../../domain/usecases/my_page_use_cases.dart';
import '../viewmodels/settings_view_model.dart';

/// 설정 — 보호자 전용 운영·계정 관리.
///
/// 아이 화면 문법(그림·음성 우선, 큰 글씨)을 따르지 않는 화면입니다.
/// 성인용 설정 UI 관행(그룹 리스트 + 토글 + chevron)을 그대로 씁니다.
///
/// **게이트를 두지 않습니다** — 아이가 열어도 유해한 정보가 없습니다.
/// 게이트는 리포트 전용입니다.
///
/// | 섹션 | 내용 |
/// |---|---|
/// | 1 | 헤더 — 뒤로 · "설정" |
/// | 2 | 알림 — 리포트 도착 · 마케팅 수신 |
/// | 3 | 안내 — 공지 · 이용 안내 · 고객센터 |
/// | 4 | 약관·정책 |
/// | 5 | 계정 — 로그인 수단 · 로그아웃 |
/// | 6 | 앱 버전 |
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SettingsViewModel>(
      create: (_) => SettingsViewModel(
        getIt<GetSettingsUseCase>(),
        getIt<SetReportNotificationUseCase>(),
        getIt<SetMarketingConsentUseCase>(),
      )..load(),
      child: const SettingsView(),
    );
  }
}

/// ViewModel 이 이미 위에 있다고 가정하는 본체. (테스트에서 직접 씁니다)
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsViewModel vm = context.watch<SettingsViewModel>();

    // 마케팅 동의는 법적 의미가 있어서 바뀐 걸 알립니다.
    final bool? toast = vm.takeMarketingToast();
    if (toast != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              toast
                  ? SettingsStrings.marketingOn
                  : SettingsStrings.marketingOff,
            ),
          ),
        );
      });
    }

    return GuardianScaffold(
      title: SettingsStrings.title,
      onBack: () =>
          context.canPop() ? context.pop() : context.go(AppRoutes.myPage),
      child: _body(context, vm),
    );
  }

  Widget _body(BuildContext context, SettingsViewModel vm) {
    if (vm.state.isError) {
      return AppErrorView(
        message: vm.errorMessage ?? SettingsStrings.loadFailed,
        onRetry: vm.load,
      );
    }
    final AppSettings? settings = vm.settings;
    if (settings == null) return const _Skeleton();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: <Widget>[
        // 알림이 최상단입니다 — 보호자가 이 화면에 오는 가장 잦은 목적입니다.
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

  /// 약관·공지 본문은 이 화면에 담지 않습니다. 문서가 준비되면 이 시트
  /// 안쪽만 채우면 됩니다 — 라우트를 늘리지 않는 이유는 화면 12개 지도를
  /// 벗어나지 않기 위해서입니다. (`docs/ARCHITECTURE.md`)
  void _openDocument(BuildContext context, String title) {
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
              Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              Text(
                SettingsStrings.documentPlaceholder,
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
            ],
          ),
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
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(SettingsStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(SettingsStrings.signOut),
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

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      children: <Widget>[
        for (int i = 0; i < 4; i++) ...<Widget>[
          const SkeletonBox(width: 80, height: AppSpacing.md),
          const SizedBox(height: AppSpacing.sm),
          const SkeletonBox(height: 96, borderRadius: AppRadius.md),
          const SizedBox(height: AppSpacing.xl),
        ],
      ],
    );
  }
}
