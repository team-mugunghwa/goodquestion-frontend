import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/press_scale.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../../play/presentation/character/dialogue_character_manifest.dart';
import '../../domain/entities/free_talk.dart';

/// 인물 카드 한 장 — 표정 그림 + 이름 + 마지막으로 이야기한 날.
///
/// ## 그림은 세 갈래로 찾습니다
///
/// 1. 번들 표정 에셋([scene]) — 대화 화면에서 쓰는 그것과 **같은 그림**입니다.
///    카드에서 본 얼굴이 대화 화면에서 그대로 나와야 같은 친구로 읽힙니다.
/// 2. 서버 썸네일([FreeTalkCharacter.thumbnailUrl]) — 번들에 없는 새 인물.
/// 3. 둘 다 없으면 브랜드 색 판 + 아이콘. **빈 회색 사각형을 두지 않습니다** —
///    고장난 카드로 보입니다. (`story_thumbnail.dart` 와 같은 원칙)
class FreeTalkCharacterCard extends StatelessWidget {
  const FreeTalkCharacterCard({
    required this.character,
    required this.metrics,
    required this.onTap,
    this.scene,
    super.key,
  });

  final FreeTalkCharacter character;
  final ScreenMetrics metrics;

  /// 번들 표정 에셋이 있는 인물에만 값이 있습니다.
  final DialogueSceneStates? scene;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? lastTalked = _lastTalkedLabel();
    return PressScale(
      onTap: onTap,
      borderRadius: AppRadius.lg,
      semanticLabel: <String>[
        character.name,
        if (lastTalked != null) lastTalked,
      ].join(', '),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.soft,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            Expanded(
              child: _CharacterPortrait(character: character, scene: scene),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    character.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: metrics.text(AppTypography.kidLabel),
                  ),
                  // 한 번도 안 걸었으면 줄 자체를 그리지 않습니다 - "없음"이라
                  // 적으면 안 한 것이 못 한 것처럼 보입니다.
                  if (lastTalked != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      lastTalked,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: metrics
                          .text(AppTypography.kidCaption)
                          .copyWith(color: AppColors.ink500),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 며칠 전에 이야기했는지. **시각이 아니라 날짜 차이**로 셉니다 - 어젯밤
  /// 11시와 오늘 새벽 1시는 두 시간 차이지만 아이에게는 "어제"와 "오늘"입니다.
  String? _lastTalkedLabel() {
    final DateTime? last = character.lastTalkedAt;
    if (last == null) return null;
    final DateTime now = DateTime.now();
    final int days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(last.year, last.month, last.day)).inDays;
    return FreeTalkStrings.lastTalked(days < 0 ? 0 : days);
  }
}

class _CharacterPortrait extends StatelessWidget {
  const _CharacterPortrait({required this.character, this.scene});

  final FreeTalkCharacter character;
  final DialogueSceneStates? scene;

  @override
  Widget build(BuildContext context) {
    final String? asset = scene?.assetOf(scene!.openingState);
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => const _PortraitFallback(),
      );
    }
    final String? thumbnail = character.thumbnailUrl;
    if (thumbnail != null) {
      final String resolved = thumbnail.startsWith('/')
          ? Uri.parse(AppConfig.apiBaseUrl).resolve(thumbnail).toString()
          : thumbnail;
      return Image.network(
        resolved,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => const _PortraitFallback(),
      );
    }
    return const _PortraitFallback();
  }
}

class _PortraitFallback extends StatelessWidget {
  const _PortraitFallback();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[AppColors.brandMint, AppColors.brandBlue],
      ),
    ),
    child: Center(
      child: Icon(
        AppIcons.characterSpeaking,
        size: AppSizes.iconChild,
        color: AppColors.surface,
      ),
    ),
  );
}
