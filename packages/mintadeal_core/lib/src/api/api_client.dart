import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// An error returned by the Mintadeal API (RFC 9457 problem details with a `code`).
class ApiError implements Exception {
  ApiError(this.status, this.code, this.message, [this.fields = const {}]);

  final int status;
  final String code;
  final String message;

  /// Field-level validation messages, keyed by field name.
  final Map<String, String> fields;

  bool get isUnauthorized => status == 401;

  @override
  String toString() {
    if (fields.isEmpty) return message;
    return '$message: ${fields.entries.map((e) => '${e.key} ${e.value}').join(', ')}';
  }
}

/// Thin JSON-over-HTTP client that attaches the bearer token and turns errors into [ApiError].
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.token,
    this.onUnauthorized,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String? Function() token;
  final void Function()? onUnauthorized;
  final http.Client _http;

  Future<dynamic> get(String path, {Map<String, Object?> query = const {}}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body: body);

  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body: body);

  Future<dynamic> patch(String path, [Object? body]) => _send('PATCH', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Uploads an image and returns its public URL.
  Future<String> uploadImage(Uint8List bytes, String filename) async {
    final req = http.MultipartRequest('POST', _uri('/api/files'))
      ..headers.addAll(_headers(json: false))
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final res = await http.Response.fromStream(await _http.send(req));
    final body = _decode(res);
    return (body as Map<String, dynamic>)['url'] as String;
  }

  Uri _uri(String path, [Map<String, Object?> query = const {}]) {
    final params = <String, String>{
      for (final e in query.entries)
        if (e.value != null) e.key: '${e.value}',
    };
    return Uri.parse('$baseUrl$path').replace(queryParameters: params.isEmpty ? null : params);
  }

  Map<String, String> _headers({bool json = true}) {
    final t = token();
    return {
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  Future<dynamic> _send(String method, String path,
      {Map<String, Object?> query = const {}, Object? body}) async {
    final req = http.Request(method, _uri(path, query))..headers.addAll(_headers());
    if (body != null) req.body = jsonEncode(body);
    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req));
    } catch (e) {
      throw ApiError(0, 'network', 'Could not reach Mintadeal. Check your internet connection.');
    }
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    final text = utf8.decode(res.bodyBytes);
    final dynamic json = text.isEmpty ? null : _tryJson(text);
    if (res.statusCode >= 200 && res.statusCode < 300) return json;
    if (res.statusCode == 401) onUnauthorized?.call();
    if (json is Map<String, dynamic>) {
      final fields = (json['fields'] as Map<String, dynamic>? ?? const {})
          .map((k, v) => MapEntry(k, '$v'));
      throw ApiError(res.statusCode, json['code'] as String? ?? 'error',
          json['detail'] as String? ?? json['title'] as String? ?? 'Something went wrong', fields);
    }
    throw ApiError(res.statusCode, 'error',
        res.statusCode == 401 ? 'Please sign in again' : 'Something went wrong (${res.statusCode})');
  }

  static dynamic _tryJson(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}
