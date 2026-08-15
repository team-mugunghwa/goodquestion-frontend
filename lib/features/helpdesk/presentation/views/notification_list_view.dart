import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/di/injector.dart';
import '../../../../core/state/view_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../../../core/widgets/guardian_scaffold.dart';
import '../../domain/entities/helpdesk.dart';
import '../../domain/usecases/helpdesk_use_cases.dart';
import '../viewmodels/helpdesk_view_models.dart';
import '../widgets/helpdesk_widgets.dart';

/// 알림함.
///
/// **푸시가 도착하지 않아도 여기 남습니다.** 알림 권한을 거부했거나 기기 토큰이
/// 만료됐을 수 있는데, 그때도 답변을 확인할 수 있어야 합니다. 푸시는 알리는
/// 수단이지 전달 경로가 아닙니다.
class NotificationListPage extends StatelessWidget {
  const NotificationListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NotificationListViewModel>(
      create: (_) => NotificationListViewModel(
        getNotifications: getIt<GetNotificationsUseCase>(),
        markRead: getIt<MarkNotificationReadUseCase>(),
        markAllRead: getIt<MarkAllNotificationsReadUseCase>(),
      )..load(),
      child: const NotificationListView(),
    );
  }
}

class NotificationListView extends StatelessWidget {
  const NotificationListView({super.key});

  @override
  Widget build(BuildContext context) {
    final NotificationListViewModel vm = context
        .watch<NotificationListViewModel>();

    return GuardianScaffold(
      title: '알림',
      onBack: () => context.pop(),
      trailing: vm.unreadCount == 0
          ? null
          : TextButton(
              onPressed: () =>
                  context.read<NotificationListViewModel>().markAllRead(),
              child: const Text('모두 읽음'),
            ),
      child: switch (vm.state) {
        ViewState.idle || ViewState.loading => const AppLoadingView(),
        ViewState.error => AppErrorView(
          message: vm.errorMessage,
          onRetry: () => context.read<NotificationListViewModel>().load(),
        ),
        ViewState.success =>
          vm.notifications.isEmpty
              ? const AppEmptyView(
                  message: '아직 알림이 없습니다.',
                  icon: AppIcons.notification,
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  itemCount: vm.notifications.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int index) =>
                      _NotificationRow(notification: vm.notifications[index]),
                ),
      },
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return InkWell(
      onTap: () async {
        await context.read<NotificationListViewModel>().markRead(notification);
        if (!context.mounted) return;
        final String? path = notification.linkPath;
        // 관리자 콘솔이 넣어 준 앱 안의 경로입니다. 외부 주소는 오지 않습니다.
        if (path != null && path.startsWith('/')) {
          await context.push(path);
        }
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          // 안 읽은 알림에 옅은 면을 깝니다. 점 하나만 두면 목록에서 눈에 안 띕니다.
          color: notification.read
              ? AppColors.surface
              : AppColors.brandBlueSurface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.ink100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(notification.title, style: text.titleMedium),
                ),
                Text(
                  formatDate(notification.createdAt),
                  style: text.bodySmall?.copyWith(color: AppColors.ink500),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              notification.body,
              style: text.bodyMedium?.copyWith(color: AppColors.ink700),
            ),
          ],
        ),
      ),
    );
  }
}
