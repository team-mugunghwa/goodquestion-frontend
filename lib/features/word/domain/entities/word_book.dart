import 'word_group.dart';

/// 단어장 화면이 한 번에 받는 것.
class WordBook {
  const WordBook({
    required this.totalCount,
    required this.groups,
    this.childName,
    this.childAvatar,
  });

  /// 헤더 배지에 크게 뜨는 숫자. 그룹 합계와 다를 수 있어(서버가 세는 기준)
  /// 서버 값을 그대로 씁니다.
  final int totalCount;

  /// 최근 담은 이야기가 위. 서버 순서를 그대로 씁니다.
  final List<WordGroup> groups;

  final String? childName;
  final String? childAvatar;

  /// 아직 아무것도 담지 않았는가. 필터 결과 0건과는 다른 상태입니다.
  bool get isEmpty => groups.isEmpty;
}
