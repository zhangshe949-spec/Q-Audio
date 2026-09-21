import 'package:dio/dio.dart';

/// Transport contract for stage-4 music sources: decoded JSON over HTTP.
/// No credentials, source logic, or caching live here.
abstract interface class NetworkService {
  Future<Object?> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration? timeout,
  });
}

enum NetworkErrorKind { timeout, http, network, protocol }

class NetworkException implements Exception {
  const NetworkException(
    this.kind,
    this.message, {
    this.statusCode,
    this.cause,
  });

  final NetworkErrorKind kind;
  final String message;
  final int? statusCode;
  final Object? cause;

  bool get isTimeout => kind == NetworkErrorKind.timeout;

  @override
  String toString() =>
      'NetworkException(${kind.name}${statusCode == null ? '' : ', $statusCode'}): $message';
}

class DioNetworkService implements NetworkService {
  DioNetworkService(this._dio);

  factory DioNetworkService.withDefaults() => DioNetworkService(
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            responseType: ResponseType.json,
          ),
        ),
      );

  final Dio _dio;

  @override
  Future<Object?> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: (query == null || query.isEmpty) ? null : query,
        options: Options(
          headers: headers,
          sendTimeout: timeout,
          receiveTimeout: timeout,
        ),
      );
      return _ensureJson(response.data);
    } on DioException catch (error) {
      throw _map(error);
    }
  }

  /// getJson promises decoded JSON; a bare string body (e.g. HTML or plain
  /// text) is a protocol violation, not valid data.
  Object? _ensureJson(Object? data) {
    if (data is Map || data is List) return data;
    throw NetworkException(
      NetworkErrorKind.protocol,
      'Response is not JSON (${data.runtimeType})',
    );
  }

  NetworkException _map(DioException error) => switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.transformTimeout =>
          NetworkException(
            NetworkErrorKind.timeout,
            error.message ?? 'Request timed out',
            cause: error,
          ),
        DioExceptionType.badResponse => NetworkException(
            NetworkErrorKind.http,
            error.message ?? 'HTTP error',
            statusCode: error.response?.statusCode,
            cause: error,
          ),
        DioExceptionType.badCertificate ||
        DioExceptionType.connectionError ||
        DioExceptionType.cancel ||
        DioExceptionType.unknown =>
          NetworkException(
            NetworkErrorKind.network,
            error.message ?? 'Network error',
            cause: error,
          ),
      };
}
