/// 주제 필터 하나.
///
/// 목록 화면의 칩 = 이 엔티티 하나입니다. 필터 목록을 서버가 내려주는 이유는
/// 주제가 콘텐츠와 함께 늘어나기 때문입니다. 앱에 하드코딩하면 이야기를
/// 추가할 때마다 앱을 새로 배포해야 합니다.
class StoryTopic {
  const StoryTopic({required this.id, required this.label, required this.icon});

  /// `all` 은 특별합니다 — 필터를 걸지 않는다는 뜻입니다.
  static const String allId = 'all';

  final String id;
  final String label;
  final TopicIcon icon;

  bool get isAll => id == allId;
}

/// 주제 칩에 붙는 그림.
///
/// 서버는 `"folk"` 같은 **문자열 키**를 내려주고, 앱이 실제 아이콘으로
/// 바꿉니다. 서버가 Material 아이콘 이름을 알 필요는 없습니다.
///
/// 모르는 키가 오면 [unknown] 으로 떨어집니다 — 칩이 사라지는 것보다
/// 낫습니다. 새 주제가 생기면 여기와 `AppIcons` 에 한 줄씩 추가하세요.
enum TopicIcon {
  all,
  folk,
  animal,
  adventure,
  daily,
  unknown;

  static TopicIcon fromKey(String? key) => switch (key) {
    'all' => TopicIcon.all,
    'folk' => TopicIcon.folk,
    'animal' => TopicIcon.animal,
    'adventure' => TopicIcon.adventure,
    'daily' => TopicIcon.daily,
    _ => TopicIcon.unknown,
  };
}
