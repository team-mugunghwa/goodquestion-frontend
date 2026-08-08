/// 질문 도메인 엔티티.
///
/// **순수 Dart 입니다.** Flutter 도, Dio 도, JSON 도 모릅니다.
/// `fromJson` 을 여기에 추가하지 마세요 — 그 순간 domain 이 서버 스펙에
/// 묶여서 클린 아키텍처를 쓰는 의미가 사라집니다.
/// JSON 변환은 `data/dtos/question_dto.dart` 가 담당합니다.
class Question {
  const Question({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String content;
  final String authorName;
  final DateTime createdAt;

  /// 화면에 쓰이는 규칙은 domain 에 두면 여러 화면이 함께 씁니다.
  bool get isLongForm => content.length > 300;

  Question copyWith({String? title, String? content}) => Question(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    authorName: authorName,
    createdAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Question && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
