import 'package:flutter/material.dart';

import '../constants/app_icons.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// 아이 얼굴 자리. 홈 상단·단어장 헤더·프로필 전환 시트가 같은 것을 씁니다.
///
/// 아바타를 아직 고르지 않았으면 **이름 첫 글자를 쓰지 않습니다.** "하"
/// 한 글자는 글을 배우는 중인 아이에게 아무 그림도 아니고, 어른 눈에도
/// 미완성으로 보입니다. 대신 파스텔 면 위의 아이 아이콘으로 채웁니다 —
/// 아바타 에셋이 들어오면 그 자리에 그림이 그대로 들어갑니다.
class ChildAvatar extends StatelessWidget {
  const ChildAvatar({
    super.key,
    required this.name,
    required this.image,
    this.diameter = AppSizes.tapChildSecondary,
  });

  /// 스크린리더에 읽히는 이름. 화면에는 그리지 않습니다.
  final String? name;

  /// 아바타 이미지 경로. 없으면 아이콘으로 대체합니다.
  final String? image;

  final double diameter;

  @override
  Widget build(BuildContext context) {
    final String? avatar = image;
    return Semantics(
      label: name,
      image: true,
      child: ClipOval(
        child: SizedBox.square(
          dimension: diameter,
          child: avatar == null
              ? _Fallback(diameter: diameter)
              : Image.asset(
                  avatar,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder:
                      (BuildContext context, Object error, StackTrace? _) =>
                          _Fallback(diameter: diameter),
                ),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.brandMint, AppColors.brandBlue],
        ),
      ),
      child: Center(
        child: Icon(
          AppIcons.childProfile,
          // 아이콘이 원 안에서 뜨지 않게 지름에 비례시킵니다.
          size: diameter * 0.5,
          color: AppColors.surface,
        ),
      ),
    );
  }
}
