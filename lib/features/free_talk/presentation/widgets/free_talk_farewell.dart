import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_canvas.dart';
import '../../../../core/widgets/kid_button.dart';
import '../../../play/presentation/character/dialogue_character_stage.dart';
import '../../../play/presentation/character/dialogue_character_state_machine.dart';

/// "또 만나자" — 자유 대화가 닫힌 뒤 마지막으로 남는 화면.
///
/// **뒤가 비치지 않는 한 장입니다.** 대화 화면 위에 반투명 막을 덮으면 아래의
/// 마이크 안내("이제 말할 차례예요")가 그대로 읽히는데, 대화가 끝난 시점이라
/// 사실이 아닙니다. (`play_view.dart` 의 전환 화면과 같은 이유)
///
/// 나가는 문을 **두 개** 둡니다. 아이 화면에서 선택지는 보통 하나지만, 여기는
/// 막다른 길이 아니라 갈림길입니다 — 다른 인물과 더 이야기하고 싶으면 이야기로,
/// 오늘은 그만하고 싶으면 홈으로 갑니다.
class FreeTalkFarewellScreen extends StatelessWidget {
  const FreeTalkFarewellScreen({
    required this.characterName,
    required this.closingText,
    required this.onHome,
    required this.onStory,
    this.character,
    super.key,
  });

  final String characterName;

  /// 캐릭터가 마지막으로 한 말. 서버가 준 문장을 그대로 씁니다.
  final String closingText;

  /// 표정 무대. 없으면 글자만 남습니다.
  final DialogueCharacterStateMachine? character;

  final VoidCallback onHome;
  final VoidCallback onStory;

  @override
  Widget build(BuildContext context) {
    final DialogueCharacterStateMachine? stage = character;
    // **탭을 흘려보내지 않습니다.** 그림만 덮으면 아래 대화 화면의 상단
    // 버튼(나가기·다시 듣기·소리)이 안 보이는 채로 그대로 눌립니다 -
    // DecoratedBox 는 자기 면으로 히트테스트를 받지 않기 때문입니다.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: AppCanvas.day(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (stage != null)
                    SizedBox(
                      height: AppSizes.illustration,
                      child: DialogueCharacterStage(
                        scene: stage.scene,
                        state: stage.current,
                        activity: DialogueActivity.idle,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    FreeTalkStrings.farewellTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.kidTitle,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppSizes.bubbleMaxWidth,
                    ),
                    child: Semantics(
                      liveRegion: true,
                      label: '$characterName: $closingText',
                      child: Text(
                        closingText,
                        textAlign: TextAlign.center,
                        style: AppTypography.kidBody,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      KidPrimaryButton(
                        icon: AppIcons.home,
                        label: FreeTalkStrings.farewellHome,
                        onPressed: onHome,
                      ),
                      KidSecondaryButton(
                        icon: AppIcons.stories,
                        label: FreeTalkStrings.farewellStory,
                        onPressed: onStory,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "이야기를 그만할까?" — 나가기(X)를 눌렀을 때의 확인 카드.
///
/// 곧바로 닫지 않고 한 번 묻습니다. 잘못 눌렀을 때 되돌릴 틈이 있어야 하고,
/// 나가는 쪽을 고르면 **친구가 인사를 하고 보내 준다**는 것을 미리 알려 줍니다 —
/// 그래야 나가기가 "대화를 끊는 일"이 아니라 "인사하고 헤어지는 일"이 됩니다.
class FreeTalkExitPrompt extends StatelessWidget {
  const FreeTalkExitPrompt({
    required this.onKeep,
    required this.onLeave,
    super.key,
  });

  final VoidCallback onKeep;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    // 카드 바깥을 눌러도 아래 화면이 반응하지 않아야 합니다(모달).
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: const Color(0xD10C1C2F),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      AppIcons.characterSpeaking,
                      color: AppColors.brandBlueDeep,
                      size: 48,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      FreeTalkStrings.exitTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      FreeTalkStrings.exitMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.ink500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: onKeep,
                      icon: const Icon(AppIcons.characterSpeaking),
                      label: const Text(FreeTalkStrings.exitKeep),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: onLeave,
                      child: const Text(FreeTalkStrings.exitLeave),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
