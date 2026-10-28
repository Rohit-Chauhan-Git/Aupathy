import 'package:dio/dio.dart';

class LnReaderHttpResponse {
  const LnReaderHttpResponse({
    required this.statusCode,
    required this.body,
    required this.uri,
    this.headers = const <String, String>{},
    this.statusMessage = '',
    this.redirected = false,
  });

  final int statusCode;
  final String body;
  final Uri uri;
  final Map<String, String> headers;
  final String statusMessage;
  final bool redirected;
}

class LnReaderHttpException implements Exception {
  const LnReaderHttpException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class LnReaderHttpClient {
  Future<LnReaderHttpResponse> get(Uri uri);

  Future<LnReaderHttpResponse> request(
    Uri uri, {
    String method = 'GET',
    Map<String, String> headers = const <String, String>{},
    String? body,
  });

  void close();
}

class DioLnReaderHttpClient implements LnReaderHttpClient {
  DioLnReaderHttpClient({
    Dio? dio,
    this.timeout = const Duration(seconds: 20),
    this.maxBodyBytes = 4 * 1024 * 1024,
  }) : _dio = dio ?? Dio();

  final Dio _dio;
  final Duration timeout;
  final int maxBodyBytes;
  bool _closed = false;

  @override
  Future<LnReaderHttpResponse> get(Uri uri) => request(uri);

  @override
  Future<LnReaderHttpResponse> request(
    Uri uri, {
    String method = 'GET',
    Map<String, String> headers = const <String, String>{},
    String? body,
  }) async {
    if (_closed) {
      throw const LnReaderHttpException('The HTTP client is closed.');
    }

    try {
      final requestHeaders = <String, String>{
        'Accept': 'application/json,text/javascript,text/plain,*/*',
        'User-Agent': 'ReaderApp-LNReader-Diagnostics/1.0',
        ...headers,
      };
      final normalizedMethod = method.toUpperCase();
      final response = await _dio.request<String>(
        uri.toString(),
        data: body,
        options: Options(
          method: normalizedMethod,
          responseType: ResponseType.plain,
          followRedirects: true,
          receiveTimeout: timeout,
          sendTimeout: timeout,
          validateStatus: (_) => true,
          headers: requestHeaders,
        ),
      );

      final responseBody = response.data ?? '';
      if (responseBody.length > maxBodyBytes) {
        throw LnReaderHttpException(
          'Response exceeded the ${maxBodyBytes ~/ (1024 * 1024)} MB limit.',
        );
      }

      return LnReaderHttpResponse(
        statusCode: response.statusCode ?? 0,
        body: responseBody,
        uri: response.realUri,
        headers: response.headers.map.map(
          (key, value) => MapEntry(key.toLowerCase(), value.join(', ')),
        ),
        statusMessage: response.statusMessage ?? '',
        redirected: response.realUri != uri,
      );
    } on DioException catch (error) {
      throw LnReaderHttpException(_describeDioError(error));
    } on LnReaderHttpException {
      rethrow;
    } catch (error) {
      throw LnReaderHttpException('Network request failed: $error');
    }
  }

  String _describeDioError(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout => 'Connection timed out.',
      DioExceptionType.sendTimeout => 'Request timed out while sending.',
      DioExceptionType.receiveTimeout => 'Timed out waiting for a response.',
      DioExceptionType.transformTimeout =>
        'Timed out while processing the response.',
      DioExceptionType.connectionError => 'Could not connect to the server.',
      DioExceptionType.badCertificate => 'The server certificate is invalid.',
      DioExceptionType.cancel => 'The request was cancelled.',
      DioExceptionType.badResponse =>
        'Unexpected HTTP response: ${error.message ?? 'unknown error'}.',
      DioExceptionType.unknown =>
        'Network error: ${error.message ?? error.error ?? 'unknown'}.',
    };
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _dio.close(force: true);
  }
}
