import 'package:flutter/material.dart';

import '../constants/app_assets.dart';

/// 로고 전체 (Q마크 + "Good Question" 워드마크).
///
/// 로고는 이미지라서 다크 모드에서 색이 바뀌지 않습니다. 파스텔 톤이라
/// 어두운 배경에서도 읽히지만, 대비가 부족한 화면에서는 [AppLogoMark] 를
/// 쓰거나 배경을 밝게 잡으세요.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 28});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.logo,
      height: height,
      // 스크린리더가 이미지를 "GoodQuestion" 으로 읽도록 합니다.
      semanticLabel: 'GoodQuestion',
      // 이미지 원본이 1024px 라 축소해서 쓰는 경우가 대부분입니다.
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Q마크만. 정사각형이라 좁은 공간·아바타 자리에 씁니다.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.logoMark,
      width: size,
      height: size,
      semanticLabel: 'GoodQuestion',
      filterQuality: FilterQuality.medium,
    );
  }
}
