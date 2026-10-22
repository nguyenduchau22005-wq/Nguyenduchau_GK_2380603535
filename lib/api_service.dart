import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ApiService {
  ApiService({
    this.baseUrl = 'https://unusable-negative-compile.ngrok-free.dev',
  });

  final String baseUrl;

  Future<dynamic> get(String path, {String? token}) =>
      _send('GET', path, token: token);

  Future<dynamic> post(String path, {Object? body, String? token}) =>
      _send('POST', path, body: body, token: token);

  Future<dynamic> put(String path, {Object? body, String? token}) =>
      _send('PUT', path, body: body, token: token);

  Future<dynamic> delete(String path, {String? token}) =>
      _send('DELETE', path, token: token);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    String? token,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.openUrl(method, Uri.parse('$baseUrl$path'));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      // Skip ngrok's browser interstitial so mobile JSON requests reach the API.
      request.headers.set('ngrok-skip-browser-warning', 'true');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      final response = await request.close().timeout(
        const Duration(seconds: 25),
      );
      final text = await utf8.decoder.bind(response).join();
      dynamic decoded;
      if (text.isNotEmpty) {
        try {
          decoded = jsonDecode(text);
        } catch (_) {
          decoded = text;
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(_apiErrorMessage(decoded, response.statusCode));
      }
      return decoded;
    } on TimeoutException {
      throw ApiException(
        'Máy chủ phản hồi quá lâu. Kiểm tra mạng rồi thử lại.',
      );
    } on SocketException {
      throw ApiException('Không kết nối được máy chủ chấm công.');
    } on HandshakeException {
      throw ApiException('Không tạo được kết nối bảo mật tới máy chủ.');
    } finally {
      client.close(force: true);
    }
  }
}

String _apiErrorMessage(dynamic payload, int statusCode) {
  if (payload is Map) {
    final map = Map<String, dynamic>.from(payload);
    for (final key in ['message', 'detail', 'error']) {
      final value = map[key];
      if (value != null && '$value'.trim().isNotEmpty) return '$value';
    }
    final errors = map['errors'];
    if (errors is Map) {
      final details = errors.entries.map((entry) {
        final value = entry.value;
        final message = value is Iterable
            ? value.map((item) => '$item').join(', ')
            : '$value';
        return '${entry.key}: $message';
      }).join('; ');
      if (details.isNotEmpty) return 'Lỗi $statusCode: $details';
    }
    for (final key in ['data', 'result', 'payload']) {
      if (map[key] is Map) {
        final nested = _apiErrorMessage(map[key], statusCode);
        if (!nested.endsWith('(HTTP $statusCode).')) return nested;
      }
    }
    final title = map['title'];
    if (title != null && '$title'.trim().isNotEmpty) return '$title';
  } else if (payload is String &&
      payload.trim().isNotEmpty &&
      !payload.toLowerCase().contains('<html')) {
    return payload.trim();
  }
  return 'Máy chủ từ chối yêu cầu (HTTP $statusCode).';
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
