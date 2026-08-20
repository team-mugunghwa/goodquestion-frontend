import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../constants/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';

/// 캐릭터 얼굴을 담는 **흰 원반**.
///
/// 역할 카드(`role_card.dart`)와 이야기 상세의 친구들 카드가 같은 원반을
/// 씁니다. 같은 인물이 화면마다 다른 모양으로 잘리면 아이는 다른 친구로
/// 읽습니다.
///
/// ## 그림은 세 갈래로 찾습니다
///
/// 1. 번들 에셋([assetImage]) — 대화 화면에서 쓰는 그것과 **같은 그림**입니다.
/// 2. 서버 썸네일([thumbnailUrl]) — 번들에 없는 새 인물.
/// 3. 둘 다 없으면 로고 마크. **빈 회색 원을 두지 않습니다** — 고장 난
///    화면으로 보입니다. (`story_thumbnail.dart` 와 같은 원칙)
///
/// 그림만 덩그러니 두면 배경이 옅어서 카드에 얹힌 게 아니라 얼룩처럼
/// 보입니다. 원반 + `soft` 그림자면 메달처럼 읽혀서, 캐릭터가 아직 없어
/// 로고 마크가 뜨는 이야기에서도 "자리를 비워 둔 것"이 아니라 "그렇게
/// 생긴 것"이 됩니다.
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    super.key,
    required this.size,
    this.assetImage,
    this.thumbnailUrl,
    this.borderColor,
  });

  final double size;

  /// 번들 캐릭터 에셋 경로. 세로 3:4 전신 그림을 전제합니다. → [_CharacterBust]
  final String? assetImage;

  /// 서버가 준 인물 썸네일. 번들 에셋이 없을 때만 씁니다.
  final String? thumbnailUrl;

  /// 원반 테두리. 파스텔 면 위에 흰 원반을 얹으면 경계가 흐려지는 자리에서만
  /// 씁니다. `null` 이면 테두리를 안 그립니다.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final String? asset = assetImage;
    final String? thumbnail = thumbnailUrl;
    final Color? border = borderColor;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: AppShadows.soft,
        border: border == null ? null : Border.all(color: border, width: 2),
      ),
      // 원 밖으로 나간 어깨는 잘립니다. 잘린 자리가 곧 원반의 테두리라
      // 인물 사진을 끼운 메달처럼 보입니다.
      clipBehavior: Clip.antiAlias,
      child: switch ((asset, thumbnail)) {
        (final String path, _) => _CharacterBust(image: AssetImage(path)),
        (_, final String url) => _CharacterBust(
          image: NetworkImage(_resolved(url)),
        ),
        _ => const _LogoMark(),
      },
    );
  }

  /// 서버 썸네일이 `/files/...` 처럼 경로만 오면 API 주소에 붙입니다.
  static String _resolved(String url) => url.startsWith('/')
      ? Uri.parse(AppConfig.apiBaseUrl).resolve(url).toString()
      : url;
}

/// 캐릭터가 없는 이야기의 대체 그림. 로고는 원반 안쪽에 여백을 두고 앉습니다.
class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Image(
        image: AssetImage(AppAssets.logoMark),
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    );
  }
}

/// 전신 캐릭터에서 **머리~어깨만** 잘라 원반에 담습니다.
///
/// 대화 화면용 에셋은 세로 3:4 전신이라 그대로 넣으면 치마가 원반의 절반을
/// 차지하고 얼굴이 손톱만 해집니다. 자른 파일을 따로 만들지 않고 화면에서
/// 잘라 씁니다 — 표정이 바뀌면 파일만 갈아 끼우면 됩니다.
class _CharacterBust extends StatelessWidget {
  const _CharacterBust({required this.image});

  final ImageProvider<Object> image;

  /// 원본에서 실제로 쓰는 범위. 위 끝(머리 위 여백)에서 시작해 세로
  /// [_bustHeight] 까지가 머리~어깨이고, 가로는 얼굴을 가운데 두고
  /// [_bustWidth] 만 씁니다. 두 값의 비가 거의 1:1 이라 원반에 넣어도
  /// 얼굴이 옆으로 눌리지 않습니다.
  static const double _bustWidth = 0.5;
  static const double _bustHeight = 0.36;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.cover,
      child: Align(
        alignment: Alignment.topCenter,
        widthFactor: _bustWidth,
        heightFactor: _bustHeight,
        child: Image(
          image: image,
          excludeFromSemantics: true,
          // 에셋이 빠지면 **빈 흰 원반**이 남습니다. 로고 마크를 뒤에 깔면
          // 캐릭터의 투명한 배경 사이로 로고가 비쳐서 평소에도 보입니다.
          // 경로는 컴파일 타임 상수라 파일이 빠지면 골든 테스트에서 걸립니다.
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stack) =>
                  const SizedBox.shrink(),
        ),
      ),
    );
  }
}
