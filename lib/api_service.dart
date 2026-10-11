
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      'https://sunny-tenderness-production.up.railway.app/api/v1';

  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();

  static final http.Client _client = http.Client();
  static Future<void> Function()? onSessionExpired;

  static final Uri _baseUri = Uri.parse(baseUrl);

  static bool _isBackend(Uri uri) =>
      uri.scheme == _baseUri.scheme &&
      uri.host == _baseUri.host &&
      uri.port == _baseUri.port;

  static String _bearerValue(String token) {
    final value = token.trim();
    final rawToken = value.replaceFirst(
      RegExp(r'^Bearer\s+', caseSensitive: false),
      '',
    );
    return 'Bearer $rawToken';
  }

  static Future<void> login(
    String username,
    String password,
  ) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/auth/token/'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Login failed (${response.statusCode}).');
    }

    final data = jsonDecode(response.body);

    await _storage.write(
      key: 'access_token',
      value: data['access'].toString(),
    );
    await _storage.write(
      key: 'refresh_token',
      value: data['refresh'].toString(),
    );
  }

  static Future<bool> hasSavedSession() async {
    final token = await _storage.read(key: 'access_token');
    return token != null && token.isNotEmpty;
  }

  static Future<bool> _refreshToken() async {
    final refresh = await _storage.read(key: 'refresh_token');

    if (refresh == null || refresh.isEmpty) {
      await _expireSession();
      return false;
    }

    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/auth/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refresh}),
      );

      if (response.statusCode != 200) {
        await _expireSession();
        return false;
      }

      final data = jsonDecode(response.body);
      final access = data['access'];

      if (access == null) {
        await _expireSession();
        return false;
      }

      await _storage.write(
        key: 'access_token',
        value: access.toString(),
      );

      final newRefresh = data['refresh'];
      if (newRefresh != null) {
        await _storage.write(
          key: 'refresh_token',
          value: newRefresh.toString(),
        );
      }

      return true;
    } catch (_) {
      await _expireSession();
      return false;
    }
  }

  static Future<void> _expireSession() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await onSessionExpired?.call();
  }

  static Future<http.Response> request({
    required String method,
    required String url,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final uri = Uri.parse(url.trim());

    if (!{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const FormatException('Invalid HTTP URL.');
    }

    final backend = _isBackend(uri);

    Future<http.Response> execute() async {
      final request = http.Request(method.toUpperCase(), uri);

      request.headers.addAll({
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        ...?headers,
      });

      // Never attach PocketOps credentials to unrelated domains.
      if (backend) {
        final token = await _storage.read(key: 'access_token');
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = _bearerValue(token);
        }
      }

      if (body != null) {
        request.body = body is String ? body : jsonEncode(body);
      }

      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 45));

      return http.Response.fromStream(streamed);
    }

    var response = await execute();

    if (backend && response.statusCode == 401) {
      if (await _refreshToken()) {
        response = await execute();
      }
    }

    return response;
  }

  static Future<http.Response> getProjects() {
    return request(
      method: 'GET',
      url: '$baseUrl/projects/',
    );
  }

  static Future<http.Response> createProject({
    required String name,
    required String baseUrlValue,
    String description = '',
  }) {
    return request(
      method: 'POST',
      url: '$baseUrl/projects/',
      body: {
        'name': name.trim(),
        'base_url': baseUrlValue.trim(),
        'description': description.trim(),
      },
    );
  }

  static Future<http.Response> getProjectEndpoints(
    String projectId,
  ) {
    return request(
      method: 'GET',
      url: '$baseUrl/projects/$projectId/endpoints/',
    );
  }


static Future<http.Response> createEndpoint({
  required String projectId,
  required String name,
  required String path,
  required String method,
  int expectedStatus = 200,
}) {
  return request(
    method: 'POST',
    url: '$baseUrl/projects/$projectId/endpoints/',
    body: {
      'project': projectId,
      'name': name.trim(),
      'path': path.trim(),
      'method': method,
      'expected_status': expectedStatus,
      'enabled': true,
    },
  );
}


  static Future<void> logout() async {
    final refresh = await _storage.read(key: 'refresh_token');

    if (refresh != null) {
      try {
        await _client.post(
          Uri.parse('$baseUrl/auth/token/blacklist/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh': refresh}),
        );
      } catch (_) {
        // Clear local credentials even if the server is unreachable.
      }
    }

    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }
  
  static Future<http.Response> sendRunnerRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    String? body,
  }) {
    return request(
      method: method,
      url: url,
      headers: headers,
      body: body,
    );
  }

  static Future<http.Response> runProjectChecks(String projectId) {
    return request(
      method: 'POST',
      url: '$baseUrl/projects/$projectId/check/',
      body: {},
    );
  }

  static Future<http.Response> runEndpointCheck(
    String projectId,
    String endpointId,
  ) {
    return request(
      method: 'POST',
      url: '$baseUrl/projects/$projectId/endpoints/$endpointId/check/',
      body: {},
    );
  }

  static Future<http.Response> getProjectChecks(
    String projectId, {
    String? endpointId,
  }) {
    final uri = Uri.parse('$baseUrl/projects/$projectId/checks/');
    return request(
      method: 'GET',
      url: uri
          .replace(queryParameters: {
            if (endpointId != null && endpointId.isNotEmpty)
              'endpoint_id': endpointId,
          })
          .toString(),
    );
  }

  static Future<http.Response> getProjectIncidents(String projectId) {
    return request(
      method: 'GET',
      url: '$baseUrl/projects/$projectId/incidents/',
    );
  }

  static Future<http.Response> getObservabilityRequests({
    int page = 1,
    int pageSize = 20,
    int? statusCode,
    String? method,
    String? path,
    String? classification,
    String? requestId,
    DateTime? startTime,
    DateTime? endTime,
    double? minDurationMs,
    double? maxDurationMs,
  }) {
    final query = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (statusCode != null) 'status_code': '$statusCode',
      if (method != null && method.isNotEmpty) 'method': method,
      if (path != null && path.isNotEmpty) 'path': path,
      if (classification != null && classification.isNotEmpty)
        'classification': classification,
      if (requestId != null && requestId.isNotEmpty) 'request_id': requestId,
      if (startTime != null) 'start_time': startTime.toUtc().toIso8601String(),
      if (endTime != null) 'end_time': endTime.toUtc().toIso8601String(),
      if (minDurationMs != null) 'min_duration_ms': '$minDurationMs',
      if (maxDurationMs != null) 'max_duration_ms': '$maxDurationMs',
    };
    return request(
      method: 'GET',
      url: Uri.parse('$baseUrl/observability/requests/')
          .replace(queryParameters: query)
          .toString(),
    );
  }

  static Future<http.Response> getObservabilityRequest(String id) {
    return request(
      method: 'GET',
      url: '$baseUrl/observability/requests/${Uri.encodeComponent(id)}/',
    );
  }

}
