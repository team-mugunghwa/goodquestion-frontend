import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_client.dart';

class ChildProfileRemoteDataSource {
  const ChildProfileRemoteDataSource(this._client);

  final DioClient _client;

  Future<List<Map<String, dynamic>>> getChildren() =>
      _client.get<List<Map<String, dynamic>>>(
        '/children',
        parse: (Object? data) => (data as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false),
      );

  /// 별가루 지갑. 마이페이지가 쓰는 것은 **현재 잔액(`balance`)** 입니다 -
  /// `totalEarned` 는 쓰고 남은 것이 아니라 누적 획득이라 다른 값입니다.
  /// → `docs/API.md` 2.14 · `StardustWalletResponse`
  Future<int> getStardustBalance(String childId) => _client.get<int>(
    '/children/$childId/stardust',
    parse: (Object? data) {
      if (data is Map<String, dynamic>) {
        final Object? balance = data['balance'];
        if (balance is num) return balance.toInt();
      }
      throw const ParseException('별가루 응답 형식이 올바르지 않습니다.');
    },
  );

  Future<Map<String, dynamic>> createChild({
    required String name,
    required int birthYear,
  }) => _client.post<Map<String, dynamic>>(
    '/children',
    body: <String, dynamic>{'name': name, 'birthYear': birthYear},
    parse: (Object? data) {
      if (data is Map<String, dynamic>) return data;
      throw const ParseException('아이 정보 응답 형식이 올바르지 않습니다.');
    },
  );
}
