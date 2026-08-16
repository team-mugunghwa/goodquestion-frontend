import 'package:flutter/material.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../domain/entities/story_detail.dart';

/// 섹션5 — 내 역할 카드. **이 화면에서 가장 중요한 정보입니다.**
///
/// 별도 카드로 승격한 이유: 아이가 아무 정보 없이 장면에 던져지면 "무슨
/// 역할로 무엇을 말해야 하는지" 모른 채 위축됩니다. 도입문 아래 한 문단으로
/// 묻어 두면 아무도 안 읽습니다. 완주율에 직결되는 정보라 카드로 뺐습니다.
///
/// ## 서버가 주는 건 이름 하나뿐입니다
///
/// `StoryDetailResponse.childRole` 이 전부이고, 역할 설명문은 기획에도 API
/// 에도 없습니다. 그래서 **이름 자체가 카드의 무게를 지도록** 그립니다 —
/// 작은 눈길잡이 한 줄 위에 크고 진한 이름 한 줄. 설명 두 줄이 채우던
/// 면적을 글자를 늘려서가 아니라 **위계와 색으로** 대신합니다.
///
/// 이름이 비어 있으면(시드 미완) 이 카드를 아예 그리지 않습니다. 빈 파스텔
/// 상자는 "고장 난 화면"으로 보입니다. → `story_detail_view.dart`
class RoleCard extends StatelessWidget {
  const RoleCard({
    super.key,
    required this.role,
    required this.storyId,
    required this.metrics,
  });

  /// 이야기별 역할 캐릭터 그림.
  ///
  /// **대화 화면(`/play`)에 이미 있는 캐릭터 에셋을 그대로 씁니다.** 서버가
  /// 주는 값이 아니라 로컬 매핑이고, 이야기 목록 표지를 제목으로 찾는
  /// [StoryThumbnail] 과 같은 방식입니다. play 의 매니페스트 로더는 async
  /// 라서 정적인 그림 한 장에 끌어 쓰기엔 무겁고, story 가 play 내부에
  /// 의존하게 됩니다 — 여기서는 경로 한 줄이면 충분합니다.
  ///
  /// **지금 캐릭터가 있는 건 방귀 뀌는 며느리 한 편뿐**이고, 나머지 이야기는
  /// 매핑이 없어 로고 마크로 폴백됩니다. 캐릭터가 그려지면 한 줄씩 추가하세요.
  ///
  /// 표정을 이걸로 고른 이유: 같은 캐릭터의 다른 표정은 전부 **이야기 안의
  /// 감정**입니다 — `opening` 은 눈썹을 내리고 손을 모은 걱정, `hurt_confused`
  /// 는 속상함, `considering` 은 생각 중. 이야기를 시작하기도 전에 아이를
  /// 맞이하는 자리에 걸면 "무슨 안 좋은 일이 있나" 로 읽힙니다.
  /// `purposeful_hopeful` 만 아이를 마주 보고 웃으며 손을 내밀고 있습니다.
  static const Map<String, String> _characterByStoryId = <String, String>{
    '11111111-1111-1111-1111-111111111111':
        'assets/images/dialogue/banggui/scene_09/character_purposeful_hopeful.webp',
  };

  final StoryRole role;

  /// 서버 storyId(UUID). [_characterByStoryId] 매칭에만 씁니다.
  final String storyId;

  final ScreenMetrics metrics;

  /// 서버가 언젠가 그림을 내려주면 그게 먼저입니다. 그 다음이 로컬 매핑.
  String? get _characterImage =>
      role.characterImage ?? _characterByStoryId[storyId];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        // 흰 카드가 아니라 파스텔 면입니다. 주변 섹션과 달라 보여야
        // 아이 눈이 여기 한 번 멈춥니다.
        color: AppColors.brandBlueSurface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.soft,
      ),
      child: MergeSemantics(
        // 좁으면 카드를 줄이는 게 아니라 **레이아웃을 바꿉니다.** 폰에서
        // 160 짜리 그림 옆에 남는 폭은 120 남짓이고, 거기서 역할 이름이
        // 세 줄로 쪼개지면 이 카드가 가진 유일한 정보가 읽히지 않습니다.
        child: metrics.isWide
            ? Row(
                // 그림과 이름을 **한 덩어리로 가운데**에 둡니다. 이름 한 줄만
                // 남아서, 왼쪽에 붙이면 태블릿 폭(1200+)에서 오른쪽 절반이
                // "빠진 자리"처럼 보입니다. 가운데 배지처럼 놓으면 짧은 것이
                // 모자란 게 아니라 의도한 것으로 읽힙니다.
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _Avatar(image: _characterImage, size: AppSizes.illustration),
                  const SizedBox(width: AppSpacing.lg),
                  Flexible(
                    child: _RoleLabel(
                      role: role,
                      metrics: metrics,
                      centered: false,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _Avatar(image: _characterImage, size: AppSizes.mic),
                  const SizedBox(height: AppSpacing.md),
                  _RoleLabel(role: role, metrics: metrics, centered: true),
                ],
              ),
      ),
    );
  }
}

/// 역할 캐릭터. 파스텔 면 위에 **흰 원반**으로 얹습니다.
///
/// 그림만 덩그러니 두면 배경이 옅어서 카드에 얹힌 게 아니라 얼룩처럼
/// 보입니다. 원반 + `soft` 그림자면 메달처럼 읽혀서, 캐릭터가 아직 없어
/// 로고 마크가 뜨는 이야기에서도 "자리를 비워 둔 것"이 아니라 "그렇게
/// 생긴 것"이 됩니다.
class _Avatar extends StatelessWidget {
  const _Avatar({this.image, required this.size});

  /// 역할 캐릭터 에셋. 없으면 로고 마크로 갑니다. → [RoleCard]
  final String? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String? path = image;
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: AppShadows.soft,
      ),
      // 원 밖으로 나간 어깨는 잘립니다. 잘린 자리가 곧 원반의 테두리라
      // 인물 사진을 끼운 메달처럼 보입니다.
      clipBehavior: Clip.antiAlias,
      child: path == null ? const _LogoMark() : _CharacterBust(image: path),
    );
  }
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

  final String image;

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
          image: AssetImage(image),
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

class _RoleLabel extends StatelessWidget {
  const _RoleLabel({
    required this.role,
    required this.metrics,
    required this.centered,
  });

  final StoryRole role;
  final ScreenMetrics metrics;

  /// 폰(세로 배치)에서는 가운데, 태블릿(가로 배치)에서는 왼쪽 정렬.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          StoryDetailStrings.roleIntro,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: metrics.text(AppTypography.kidLabel),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          StoryDetailStrings.roleName(role.name),
          textAlign: centered ? TextAlign.center : TextAlign.start,
          // 이 화면에서 가장 진한 글자입니다. 파스텔은 면으로만 쓰고 글자에는
          // `Deep` 을 쓰라는 규칙 그대로. (`docs/DESIGN_SYSTEM.md` 3장)
          style: metrics
              .text(AppTypography.kidTitle)
              .copyWith(color: AppColors.brandBlueDeep),
        ),
      ],
    );
  }
}
