import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../constants/app_icons.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'kid_button.dart';

/// 로딩 화면. 전 화면 공통.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// 에러 화면. `ViewState.error` 일 때 씁니다.
///
/// **재시도 버튼을 반드시 주세요.** 에러 메시지만 띄우고 끝내면 사용자는
/// 앱을 껐다 켜는 수밖에 없습니다.
///
/// 아이가 보는 화면에는 [AppKidErrorView] 를 쓰세요 — 이건 보호자용입니다.
class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              message ?? '문제가 발생했습니다.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 아이 화면의 "여기서 막혔어" 화면. 에러와 빈 상태가 같은 뼈대를 씁니다.
///
/// 보호자 화면의 에러는 빨간 아이콘 + "문제가 발생했습니다"면 됩니다.
/// 아이에게는 그게 "네가 뭔가 잘못했다"로 읽힙니다. 그래서
/// **캐릭터가 말을 거는 형태 + 큰 버튼 하나**로 바꿉니다.
/// 빨강([AppColors.danger])을 쓰지 않습니다. (PRD §6)
///
/// **선택지는 항상 하나입니다.** 아이에게 "취소"는 막다른 길입니다 —
/// 빈 화면에도 반드시 나갈 문을 하나 주세요.
class AppKidMessageView extends StatelessWidget {
  const AppKidMessageView({
    super.key,
    required this.message,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
    this.messageStyle,
  });

  final String message;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback onAction;
  final TextStyle? messageStyle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 캐릭터 에셋이 나오기 전까지는 로고의 말풍선 Q 가 대신 말합니다.
            // 캐릭터가 준비되면 이 한 줄만 바꾸면 됩니다.
            Image.asset(
              AppAssets.logoMark,
              width: AppSizes.illustration,
              height: AppSizes.illustration,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.bubbleMaxWidth,
              ),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: messageStyle ?? AppTypography.kidBody,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            KidPrimaryButton(
              icon: actionIcon,
              label: actionLabel,
              onPressed: onAction,
            ),
          ],
        ),
      ),
    );
  }
}

/// 아이 화면의 에러. 다시 불러오기 버튼 하나.
class AppKidErrorView extends StatelessWidget {
  const AppKidErrorView({
    super.key,
    required this.onRetry,
    this.message = AppStrings.loadFailedKid,
    this.retryLabel = AppStrings.retryKid,
    this.messageStyle,
  });

  final VoidCallback onRetry;
  final String message;
  final String retryLabel;
  final TextStyle? messageStyle;

  @override
  Widget build(BuildContext context) => AppKidMessageView(
    message: message,
    actionIcon: AppIcons.retry,
    actionLabel: retryLabel,
    onAction: onRetry,
    messageStyle: messageStyle,
  );
}

/// 아이 화면의 빈 상태. **나가는 문을 반드시 함께 줍니다.**
///
/// 필터 결과가 0건이거나 아직 아무것도 담지 않았을 때. 에러가 아니므로
/// 문구가 사과조가 되면 안 됩니다.
class AppKidEmptyView extends StatelessWidget {
  const AppKidEmptyView({
    super.key,
    required this.message,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
    this.messageStyle,
  });

  final String message;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback onAction;
  final TextStyle? messageStyle;

  @override
  Widget build(BuildContext context) => AppKidMessageView(
    message: message,
    actionIcon: actionIcon,
    actionLabel: actionLabel,
    onAction: onAction,
    messageStyle: messageStyle,
  );
}

/// 데이터가 0건일 때. 에러와 구분해서 보여줍니다. (보호자 화면용)
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.inbox_outlined,
              size: 40,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
