import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// 앱 테마.
///
/// **위젯 안에서 색을 직접 쓰지 마세요.** `Colors.blue` 대신
/// `Theme.of(context).colorScheme.primary` 를 씁니다. 그래야 나중에
/// 브랜드 컬러가 바뀌어도 이 파일만 고치면 됩니다.
///
/// ## 이 테마는 "보호자·시스템 화면" 기준입니다
///
/// 아이가 보는 화면(홈·이야기·장면·활동·행성·단어장)은 배경이 그라디언트고
/// 글자와 터치 타겟이 훨씬 큽니다. 그 화면들은 `AppCanvas` 로 감싸고
/// `AppTypography.kid*` / `AppSizes.tapChild*` 를 직접 쓰세요.
/// 두 세계의 차이는 `docs/DESIGN_SYSTEM.md` 에 정리돼 있습니다.
///
/// ## 다크 모드는 만들지 않습니다 (MVP)
///
/// 이야기 장면 이미지와 캐릭터 에셋이 밝은 배경 전제로 그려지고, 아이 화면
/// 절반은 이미 밤 배경입니다. 화면마다 두 벌을 검수할 여력이 없어
/// `ThemeMode.light` 로 고정했습니다. → `docs/DECISIONS.md` 014
abstract final class AppTheme {
  static ThemeData get light => _build();

  static ThemeData _build() {
    // 로고에서 뽑은 시드로 팔레트를 만들고, 대비가 중요한 자리는
    // 직접 지정한 토큰으로 덮어씁니다.
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.seed).copyWith(
      primary: AppColors.brandBlueDeep,
      onPrimary: AppColors.surface,
      primaryContainer: const Color(0xFFDCEBF6),
      onPrimaryContainer: AppColors.ink900,
      secondary: AppColors.brandGreenDeep,
      onSecondary: AppColors.surface,
      secondaryContainer: const Color(0xFFE3F0DF),
      onSecondaryContainer: AppColors.ink900,
      tertiary: AppColors.stardustDeep,
      onTertiary: AppColors.ink900,
      tertiaryContainer: AppColors.stardustGlow,
      onTertiaryContainer: AppColors.ink900,
      surface: AppColors.surface,
      onSurface: AppColors.ink900,
      onSurfaceVariant: AppColors.ink500,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainer: AppColors.guardianCanvas,
      surfaceContainerHighest: AppColors.ink100,
      error: AppColors.danger,
      onError: AppColors.surface,
      outline: AppColors.ink300,
      outlineVariant: AppColors.ink100,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: AppTypography.textTheme,
      scaffoldBackgroundColor: AppColors.guardianCanvas,
      focusColor: AppColors.focus,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink900,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTypography.textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.ink100),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.tapGuardian),
          textStyle: AppTypography.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.tapGuardian),
          textStyle: AppTypography.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          side: const BorderSide(color: AppColors.ink300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppSizes.tapGuardian, AppSizes.tapGuardian),
          textStyle: AppTypography.textTheme.labelLarge,
        ),
      ),
      // 흰 카드 위에 옅은 잉크빛 면을 깐 테두리 없는 입력 필드.
      // 테두리 상자보다 조용하고, 포커스가 오면 그때 링이 생깁니다.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.guardianCanvas,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTypography.textTheme.bodyMedium?.copyWith(
          color: AppColors.ink500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.focus, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.ink300),
        labelStyle: AppTypography.textTheme.labelMedium,
        shape: const StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSizes.bottomNav,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.stardustGlow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink900,
        contentTextStyle: AppTypography.textTheme.bodyMedium?.copyWith(
          color: AppColors.surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dividerTheme: const DividerThemeData(
        space: 1,
        thickness: 1,
        color: AppColors.ink100,
      ),
    );
  }
}
