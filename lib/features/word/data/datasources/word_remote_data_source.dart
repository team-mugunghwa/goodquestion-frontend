import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../dtos/sentence_practice_dto.dart';
import '../dtos/word_response_dto.dart';

class WordRemoteDataSource {
  const WordRemoteDataSource(this._client);

  final DioClient _client;

  Future<List<WordResponseDto>> fetchWords(String childId) =>
      _client.get<List<WordResponseDto>>(
        '/children/$childId/words',
        parse: (Object? data) {
          if (data is List<dynamic>) {
            return data
                .whereType<Map<String, dynamic>>()
                .map(WordResponseDto.fromJson)
                .toList(growable: false);
          }
          throw const ParseException('단어장 응답 형식이 올바르지 않습니다.');
        },
      );

  Future<WordResponseDto> toggleFavorite(String childId, String wordId) =>
      _client.patch<WordResponseDto>(
        '/children/$childId/words/$wordId/favorite',
        parse: (Object? data) {
          if (data is Map<String, dynamic>) {
            return WordResponseDto.fromJson(data);
          }
          throw const ParseException('좋아요 응답 형식이 올바르지 않습니다.');
        },
      );

  Future<SentencePracticeResultDto> practiceSentence(
    String childId,
    String wordId, {
    required String sentenceType,
    required String spokenText,
  }) => _client.post<SentencePracticeResultDto>(
    '/children/$childId/words/$wordId/sentence-practice',
    body: <String, Object?>{
      'sentenceType': sentenceType,
      'spokenText': spokenText,
    },
    parse: (Object? data) {
      if (data is Map<String, dynamic>) {
        return SentencePracticeResultDto.fromJson(data);
      }
      throw const ParseException('따라 말하기 응답 형식이 올바르지 않습니다.');
    },
  );

  /// 녹음(WAV)을 글자로 바꿉니다. play 의 `transcribeAudio` 와 같은 계약입니다.
  Future<String> transcribe(Uint8List wavBytes) => _client.post<String>(
    '/stt',
    body: FormData.fromMap(<String, Object>{
      'audio': MultipartFile.fromBytes(
        wavBytes,
        filename: 'child-speech.wav',
        contentType: DioMediaType('audio', 'wav'),
      ),
    }),
    parse: (Object? data) {
      if (data is Map<String, dynamic>) {
        final String? text = data['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          return text.trim();
        }
      }
      throw const ParseException('음성을 알아듣지 못했어요. 다시 말해 주세요.');
    },
  );
}
