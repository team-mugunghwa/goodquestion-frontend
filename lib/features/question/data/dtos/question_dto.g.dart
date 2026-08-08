// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'question_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QuestionDto _$QuestionDtoFromJson(Map<String, dynamic> json) => QuestionDto(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  content: json['content'] as String,
  authorName: json['authorName'] as String,
  createdAt: json['createdAt'] as String,
);

Map<String, dynamic> _$CreateQuestionRequestToJson(
  CreateQuestionRequest instance,
) => <String, dynamic>{'title': instance.title, 'content': instance.content};
