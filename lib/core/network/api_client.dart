import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nomowear/core/network/api_constants.dart';
import 'package:nomowear/core/network/api_exception.dart';

class ApiClient {
  final http.Client _client;
  final String baseUrl;

  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? ApiConstants.baseUrl;

  Uri _uri(String path) {
    final root = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final segment = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$root$segment');
  }

  Map<String, String> _headers({
    String? authToken,
    bool jsonBody = false,
  }) {
    final headers = <String, String>{};
    if (jsonBody) {
      headers['Content-Type'] = 'application/json';
    }
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? authToken,
  }) async {
    _logRequest(method: 'POST', path: path, body: body);
    return _request(
      () => _client.post(
        _uri(path),
        headers: _headers(authToken: authToken, jsonBody: true),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> get(
    String path, {
    required String authToken,
    Map<String, String>? queryParameters,
  }) async {
    _logRequest(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
    );
    var uri = _uri(path);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParameters);
    }
    return _request(
      () => _client.get(
        uri,
        headers: _headers(authToken: authToken),
      ),
    );
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    required String authToken,
  }) async {
    _logRequest(method: 'PUT', path: path, body: body);
    return _request(
      () => _client.put(
        _uri(path),
        headers: _headers(authToken: authToken, jsonBody: true),
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    required String authToken,
  }) async {
    _logRequest(method: 'DELETE', path: path);
    return _request(
      () => _client.delete(
        _uri(path),
        headers: _headers(authToken: authToken),
      ),
    );
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required Map<String, String> fields,
    List<http.MultipartFile> files = const [],
    String? authToken,
  }) async {
    return _sendMultipart('POST', path, fields: fields, files: files, authToken: authToken);
  }

  Future<Map<String, dynamic>> putMultipart(
    String path, {
    required Map<String, String> fields,
    List<http.MultipartFile> files = const [],
    required String authToken,
  }) async {
    return _sendMultipart('PUT', path, fields: fields, files: files, authToken: authToken);
  }

  Future<Map<String, dynamic>> _sendMultipart(
    String method,
    String path, {
    required Map<String, String> fields,
    required List<http.MultipartFile> files,
    String? authToken,
  }) async {
    _logRequest(
      method: method,
      path: path,
      fields: fields,
      fileNames: files.map((file) => file.filename ?? file.field).toList(),
    );
    return _request(() async {
      final request = http.MultipartRequest(method, _uri(path));
      if (authToken != null && authToken.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }
      request.fields.addAll(fields);
      request.files.addAll(files);
      final streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    });
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function() send,
  ) async {
    try {
      final response = await send().timeout(const Duration(seconds: 30));
      return _decodeResponse(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'Unable to connect. Check your network and server.',
      );
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(response.body);
      decoded = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    } catch (_) {
      throw const ApiException('Invalid response from server');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      _logResponse(response.statusCode, decoded);
      return decoded;
    }

    _logResponse(response.statusCode, decoded);

    final message =
        decoded['message']?.toString() ?? 'Request failed (${response.statusCode})';
    throw ApiException(message, statusCode: response.statusCode);
  }

  void _logRequest({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    Map<String, String>? fields,
    List<String>? fileNames,
  }) {
    if (!kDebugMode) return;

    final buffer = StringBuffer()
      ..writeln('──────── API Request ────────')
      ..writeln('$method ${_uri(path)}');

    if (queryParameters != null && queryParameters.isNotEmpty) {
      buffer.writeln(
        'Query: ${const JsonEncoder.withIndent('  ').convert(queryParameters)}',
      );
    }
    if (body != null) {
      buffer.writeln(
        'Body: ${const JsonEncoder.withIndent('  ').convert(body)}',
      );
    }
    if (fields != null && fields.isNotEmpty) {
      buffer.writeln(
        'Fields: ${const JsonEncoder.withIndent('  ').convert(fields)}',
      );
    }
    if (fileNames != null && fileNames.isNotEmpty) {
      buffer.writeln('Files: ${fileNames.join(', ')}');
    }
    buffer.writeln('────────────────────────────');

    debugPrint(buffer.toString());
  }

  void _logResponse(int statusCode, Map<String, dynamic> body) {
    if (!kDebugMode) return;

    final buffer = StringBuffer()
      ..writeln('──────── API Response ────────')
      ..writeln('Status: $statusCode')
      ..writeln(
        'Body: ${const JsonEncoder.withIndent('  ').convert(body)}',
      )
      ..writeln('────────────────────────────');

    debugPrint(buffer.toString());
  }
}
