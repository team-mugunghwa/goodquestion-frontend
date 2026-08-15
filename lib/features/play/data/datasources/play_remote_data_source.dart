import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/play_session.dart';
import '../dtos/play_session_dto.dart';

class PlayRemoteDataSource {
  const PlayRemoteDataSource(this._client);

  final DioClient _client;

  Future<PlaySessionSnapshot> resume(String sessionId) =>
      _client.get<PlaySessionSnapshot>(
        '/sessions/$sessionId/resume',
        parse: (Object? data) {
          if (data is Map<String, dynamic>) {
            return PlaySessionDto.fromResumeJson(data);
          }
          throw const ParseException('이어하기 응답 형식이 올바르지 않습니다.');
        },
      );

  Future<PlaySessionSnapshot> completeStoryScene(String sessionId) =>
      _client.post<PlaySessionSnapshot>(
        '/sessions/$sessionId/scenes/current/story-complete',
        parse: (Object? data) {
          if (data is Map<String, dynamic>) {
            return PlaySessionDto.fromAdvanceJson(data);
          }
          throw const ParseException('장면 전환 응답 형식이 올바르지 않습니다.');
        },
      );

  Future<PlayOpeningMessage> openCurrentScene(String sessionId) =>
      _client.post<PlayOpeningMessage>(
        '/sessions/$sessionId/scenes/current/opening',
        parse: (Object? data) {
          if (data is Map<String, dynamic>) {
            final Object? messageValue = data['message'];
            if (messageValue is Map<String, dynamic>) {
              final String? text = messageValue['text'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                return PlayOpeningMessage(
                  text: text.trim(),
                  audioUrl: messageValue['audioUrl'] as String?,
                  audioTimings: PlaySessionDto.audioTimings(
                    messageValue['audioTimings'],
                  ),
                  alreadyOpened: data['alreadyOpened'] as bool? ?? false,
                );
              }
            }
          }
          throw const ParseException('첫 대사 응답 형식이 올바르지 않습니다.');
        },
      );

  Future<List<PlayMessage>> sceneMessages(
    String sessionId, {
    required String sceneId,
  }) => _client.get<List<PlayMessage>>(
    '/sessions/$sessionId/messages',
    queryParameters: <String, dynamic>{'sceneId': sceneId},
    parse: PlaySessionDto.messages,
  );

  Future<PlayMission?> currentMission(String sessionId) =>
      _client.get<PlayMission?>(
        '/sessions/$sessionId/missions/current',
        parse: (Object? data) {
          if (data is Map<String, dynamic>) {
            return PlaySessionDto.mission(data['mission']);
          }
          throw const ParseException('현재 미션 응답 형식이 올바르지 않습니다.');
        },
      );

  Future<PlayTranscription> transcribeAudio(Uint8List wavBytes) =>
      _client.post<PlayTranscription>(
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
              return PlayTranscription(
                text: text.trim(),
                confidence: (data['confidence'] as num?)?.toDouble(),
                lowConfidence: data['lowConfidence'] as bool? ?? false,
              );
            }
          }
          throw const ParseException('음성을 알아듣지 못했어요. 다시 말해 주세요.');
        },
      );

  Future<PlaySpeechAudio> synthesizeSpeech({
    required String text,
    String? characterName,
  }) => _client.post<PlaySpeechAudio>(
    '/tts',
    body: <String, Object?>{'text': text, 'characterName': characterName},
    parse: (Object? data) {
      if (data is Map<String, dynamic>) {
        final String? audioUrl = data['audioUrl'] as String?;
        if (audioUrl != null && audioUrl.trim().isNotEmpty) {
          return PlaySpeechAudio(audioUrl: audioUrl.trim());
        }
      }
      throw const ParseException('음성 합성 응답 형식이 올바르지 않습니다.');
    },
  );

  Future<PlayTurnResult> submitUtterance(
    String sessionId, {
    required String text,
    String? missionId,
    String? sttRawText,
    double? sttConfidence,
    int sttRetryCount = 0,
    String? idempotencyKey,
  }) => _client.post<PlayTurnResult>(
    '/sessions/$sessionId/utterances',
    body: <String, Object?>{
      'text': text,
      'sttRawText': sttRawText ?? text,
      'sttConfidence': sttConfidence,
      'sttRetryCount': sttRetryCount,
      'missionId': missionId,
    },
    headers: idempotencyKey != null
        ? <String, dynamic>{'Idempotency-Key': idempotencyKey}
        : null,
    parse: (Object? data) {
      if (data is Map<String, dynamic>) {
        return PlaySessionDto.fromUtteranceJson(data);
      }
      throw const ParseException('대화 응답 형식이 올바르지 않습니다.');
    },
  );

  /// 본문 없이 200 만 옵니다. → `docs/이야기_전개_가이드.md` 3.8
  Future<void> stop(String sessionId) =>
      _client.post<void>('/sessions/$sessionId/stop', parse: (_) {});
}
