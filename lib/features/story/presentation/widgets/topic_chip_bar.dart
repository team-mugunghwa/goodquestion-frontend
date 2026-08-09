import 'package:flutter/widgets.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/widgets/kid_chips.dart';
import '../../../../core/widgets/screen_metrics.dart';
import '../../domain/entities/story_topic.dart';

/// 섹션2 — 주제 필터 칩 바.
///
/// 도메인의 [TopicIcon] 을 실제 아이콘으로 바꾸는 것이 이 위젯의 일입니다.
/// 도메인이 `Icons.pets_rounded` 를 알면 안 되고, 서버가 Material 아이콘
/// 이름을 알아도 안 됩니다. 번역은 **presentation 한 곳**에서 합니다.
class TopicChipBar extends StatelessWidget {
  const TopicChipBar({
    super.key,
    required this.topics,
    required this.selectedId,
    required this.onSelected,
    required this.metrics,
  });

  final List<StoryTopic> topics;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final ScreenMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return KidFilterChips(
      metrics: metrics,
      selectedId: selectedId,
      onSelected: onSelected,
      items: <KidFilterChipData>[
        for (final StoryTopic topic in topics)
          KidFilterChipData(
            id: topic.id,
            label: topic.label,
            icon: _iconOf(topic.icon),
          ),
      ],
    );
  }

  static IconData _iconOf(TopicIcon icon) => switch (icon) {
    TopicIcon.all => AppIcons.topicAll,
    TopicIcon.folk => AppIcons.topicFolk,
    TopicIcon.animal => AppIcons.topicAnimal,
    TopicIcon.adventure => AppIcons.topicAdventure,
    TopicIcon.daily => AppIcons.topicDaily,
    // 서버가 앱보다 먼저 새 주제를 내려도 칩이 사라지지 않게.
    TopicIcon.unknown => AppIcons.topic,
  };
}
