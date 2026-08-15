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
}
