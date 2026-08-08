import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// 앱 테마.
///
/// **위젯 안에서 색을 직접 쓰지 마세요.** `Colors.blue` 대신
/// `Theme.of(context).colorScheme.primary` 를 씁니다. 그래야 나중에
/// 브랜드 컬러가 바뀌어도 이 파일만 고치면 됩니다.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    // 로고에서 뽑은 시드 하나로 전체 팔레트가 생성됩니다.
    // 보조색(그린)은 secondary 로 고정해 워드마크의 두 색을 살립니다.
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    ).copyWith(secondary: AppColors.brandGreen);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dividerTheme: DividerThemeData(space: 1, color: scheme.outlineVariant),
    );
  }
}
