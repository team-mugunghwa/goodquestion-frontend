import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodquestion/core/network/dio_client.dart';
import 'package:goodquestion/features/play/data/datasources/play_remote_data_source.dart';

/// 실제로 서버에 나가는 JSON 본문을 붙잡아 두는 가짜 어댑터.
///
/// 발화 제출은 리포지토리까지만 보는 테스트가 이미 있지만, `sttRawText` 를
/// **비운 채로 보내는지**는 본문을 조립하는 이 층에서만 확인할 수 있습니다 -
/// 예전에는 여기서 `sttRawText ?? text` 로 값을 대신 메우고 있었고, 그러면
/// 위층이 null 을 넘겨도 서버에는 원문이 있는 것처럼 도착합니다.
class _BodyCaptureAdapter implements HttpClientAdapter {
  Map<String, dynamic>? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastBody = jsonDecode(jsonEncode(options.data)) as Map<String, dynamic>;
    return ResponseBody.fromString(
      '{}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _BodyCaptureAdapter adapter;
  late PlayRemoteDataSource dataSource;

  setUp(() {
    adapter = _BodyCaptureAdapter();
    dataSource = PlayRemoteDataSource(
      DioClient(
        dio: Dio()..httpClientAdapter = adapter,
        tokenRefresher: () async => false,
        onUnauthorized: () {},
      ),
    );
  });

  test('선택지로 고른 문장은 STT 값을 비운 채로 나간다', () async {
    await dataSource.submitUtterance(
      'session-1',
      text: '자꾸 참으면 배가 아프니까, 가족들한테 먼저 솔직하게 말해 보세요.',
      sttRetryCount: 3,
    );

    final Map<String, dynamic> body = adapter.lastBody!;
    expect(body['text'], '자꾸 참으면 배가 아프니까, 가족들한테 먼저 솔직하게 말해 보세요.');
    expect(body['sttRetryCount'], 3);
    expect(
      body['sttRawText'],
      isNull,
      reason: 'STT 를 안 탄 말이라 원문이 없습니다 - 본문에서 text 로 대신 메우면 안 됩니다',
    );
    expect(body['sttConfidence'], isNull);
  });

  test('말로 한 발화는 STT 원문과 신뢰도를 그대로 싣는다', () async {
    await dataSource.submitUtterance(
      'session-1',
      text: '같이 놀자고 말해요',
      sttRawText: '가치 노자고 마래요',
      sttConfidence: 0.62,
      sttRetryCount: 1,
    );

    final Map<String, dynamic> body = adapter.lastBody!;
    expect(body['text'], '같이 놀자고 말해요');
    expect(body['sttRawText'], '가치 노자고 마래요');
    expect(body['sttConfidence'], 0.62);
    expect(body['sttRetryCount'], 1);
  });
}
