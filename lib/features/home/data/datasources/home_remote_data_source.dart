import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../dtos/home_response_dto.dart';

class HomeRemoteDataSource {
  const HomeRemoteDataSource(this._client);

  final DioClient _client;

  Future<HomeResponseDto> fetchHome(String childId) =>
      _client.get<HomeResponseDto>(
        '/children/$childId/home',
        parse: (Object? data) {
          if (data is Map<String, dynamic>) {
            return HomeResponseDto.fromJson(data);
          }
          throw const ParseException('홈 응답 형식이 올바르지 않습니다.');
        },
      );
}
