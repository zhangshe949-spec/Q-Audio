import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:q_audio/services/network/network_service.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late DioNetworkService service;

  setUp(() {
    dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    adapter = DioAdapter(dio: dio);
    service = DioNetworkService(dio);
  });

  test('returns decoded JSON on success', () async {
    adapter.onGet(
      '/api/search',
      (server) => server.reply(200, <String, Object?>{
        'result': <Map<String, Object>>[
          {'id': 1},
        ],
      }),
    );
    expect(await service.getJson('/api/search', query: {'s': 'x'}), {
      'result': [
        {'id': 1},
      ],
    });
  });

  test('maps 4xx/5xx to http errors with status code', () async {
    adapter.onGet('/boom', (server) => server.reply(403, 'denied'));
    await expectLater(
      service.getJson('/boom'),
      throwsA(
        isA<NetworkException>()
            .having((e) => e.kind, 'kind', NetworkErrorKind.http)
            .having((e) => e.statusCode, 'statusCode', 403),
      ),
    );
  });

  test('maps timeouts distinctly', () async {
    adapter.onGet(
      '/slow',
      (server) => server.throws(
        504,
        DioException(
          requestOptions: RequestOptions(path: '/slow'),
          type: DioExceptionType.receiveTimeout,
          message: 'timed out',
        ),
      ),
    );
    await expectLater(
      service.getJson('/slow'),
      throwsA(
        isA<NetworkException>().having((e) => e.isTimeout, 'isTimeout', isTrue),
      ),
    );
  });

  test('maps connection failures to network errors', () async {
    adapter.onGet(
      '/down',
      (server) => server.throws(
        500,
        DioException.connectionError(
          requestOptions: RequestOptions(path: '/down'),
          reason: 'refused',
        ),
      ),
    );
    await expectLater(
      service.getJson('/down'),
      throwsA(
        isA<NetworkException>().having(
          (e) => e.kind,
          'kind',
          NetworkErrorKind.network,
        ),
      ),
    );
  });

  test('invalid JSON payload is surfaced as protocol problem', () async {
    adapter.onGet(
      '/html',
      (server) => server.reply(200, '<html>not json</html>'),
    );
    await expectLater(
      service.getJson('/html'),
      throwsA(isA<NetworkException>()),
    );
  });
}
