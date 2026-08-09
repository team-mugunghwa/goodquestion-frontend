import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// 이야기·행성의 대표 이미지 자리.
///
/// 아이는 글을 읽지 않고 **이미지로 카드의 뜻을 구분**합니다. 그래서 이미지가
/// 아직 없더라도 자리를 비워 두지 않고 브랜드 그라디언트 + 아이콘으로 채웁니다.
/// 빈 회색 사각형을 두면 "고장난 카드"로 보입니다.
class StoryThumbnail extends StatelessWidget {
  const StoryThumbnail({
    super.key,
    required this.image,
    required this.fallbackIcon,
    this.aspectRatio = wide,
  });

  /// 16:9 — 이야기 카드의 기본. (`docs/DESIGN_SYSTEM.md` 10장)
  static const double wide = 16 / 9;

  /// 정사각. 행성 썸네일처럼 원으로 잘라 쓰는 자리.
  static const double square = 1;

  /// 에셋 경로. `null` 이면 그라디언트로 대체합니다.
  /// 서버가 URL 을 내려주기 시작하면 이 위젯 안에서만 바꾸면 됩니다.
  final String? image;

  /// 이미지가 없을 때 대신 보여 줄 아이콘. `AppIcons` 에서 가져오세요.
  final IconData fallbackIcon;

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final String? path = image;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: path == null
          ? _ThumbnailFallback(icon: fallbackIcon)
          : Image.asset(
              path,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              // 파일이 빠졌을 때 빨간 에러 상자 대신 그라디언트가 뜹니다.
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? _) =>
                      _ThumbnailFallback(icon: fallbackIcon),
            ),
    );
  }
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: Center(
        child: Icon(
          icon,
          size: AppSizes.iconChild,
          color: AppColors.brandBlueDeep,
        ),
      ),
    );
  }
}
