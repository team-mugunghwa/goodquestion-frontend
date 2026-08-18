import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../dtos/report_response_dto.dart';

class ReportRemoteDataSource {
  const ReportRemoteDataSource(this._client);

  final DioClient _client;

  Future<List<ReportListResponseDto>> fetchReports(String childId) =>
      _client.get<List<ReportListResponseDto>>(
        '/children/$childId/reports',
        parse: (Object? data) {
          if (data is! List<dynamic>) {
            throw const ParseException('리포트 목록 응답 형식이 올바르지 않습니다.');
          }
          return data
              .whereType<Map<String, dynamic>>()
              .map(ReportListResponseDto.fromJson)
              .toList(growable: false);
        },
      );

  Future<ReportDetailResponseDto> fetchReport(String sessionId) =>
      _client.get<ReportDetailResponseDto>(
        '/sessions/$sessionId/report',
        parse: (Object? data) {
          if (data is Map<String, dynamic>) {
            return ReportDetailResponseDto.fromJson(data);
          }
          throw const ParseException('리포트 상세 응답 형식이 올바르지 않습니다.');
        },
      );

  /// 6각 그래프 전용 — [fetchReport](요약·역량 카드용)와 별도 엔드포인트다.
  /// (D6 0-1절: 그래프는 서버 결정론적 집계 전용, LLM 미사용이라 API 자체가 분리돼 있다.)
  Future<List<AxisScoreResponseDto>> fetchAxisScores(String sessionId) =>
      _client.get<List<AxisScoreResponseDto>>(
        '/sessions/$sessionId/report/axis-scores',
        parse: (Object? data) {
          if (data is! List<dynamic>) {
            throw const ParseException('축 점수 응답 형식이 올바르지 않습니다.');
          }
          return data
              .whereType<Map<String, dynamic>>()
              .map(AxisScoreResponseDto.fromJson)
              .toList(growable: false);
        },
      );
}
