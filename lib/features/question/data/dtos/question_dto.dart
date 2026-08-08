import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/question.dart';

part 'question_dto.g.dart';

/// 서버 응답의 모양 그대로를 담는 객체.
///
/// Entity 와 분리하는 이유: 서버 필드명이 바뀌어도 [toEntity] 한 곳만
/// 고치면 되고 화면 코드는 손대지 않습니다.
///
/// 이 파일을 고쳤다면 반드시 코드 생성을 다시 돌리세요.
/// ```bash
/// dart run build_runner build
/// ```
@JsonSerializable(createToJson: false)
class QuestionDto {
  const QuestionDto({
    required this.id,
    required this.title,
    required this.content,
    required this.authorName,
    required this.createdAt,
  });

  factory QuestionDto.fromJson(Map<String, dynamic> json) =>
      _$QuestionDtoFromJson(json);

  final int id;
  final String title;
  final String content;

  /// 서버가 snake_case 로 준다면 여기서만 매핑하면 됩니다.
  /// 예: `@JsonKey(name: 'author_name')`
  final String authorName;

  /// ISO 8601 문자열. `docs/API.md` 의 합의 사항입니다.
  final String createdAt;

  Question toEntity() => Question(
    id: id,
    title: title,
    content: content,
    authorName: authorName,
    // 서버가 타임존 없는 문자열을 주면 tryParse 가 null 을 낼 수 있습니다.
    // 화면이 죽지 않도록 방어하고, 값이 이상하면 API.md 를 확인하세요.
    createdAt: DateTime.tryParse(createdAt)?.toLocal() ?? DateTime.now(),
  );
}

/// 질문 생성 요청 본문.
@JsonSerializable(createFactory: false)
class CreateQuestionRequest {
  const CreateQuestionRequest({required this.title, required this.content});

  final String title;
  final String content;

  Map<String, dynamic> toJson() => _$CreateQuestionRequestToJson(this);
}
