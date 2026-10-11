import 'dart:convert';

class RequestEvent {
  final String id;
  final String requestId;
  final String? correlationId;
  final DateTime? timestamp;
  final String method;
  final String path;
  final int? statusCode;
  final double? durationMs;
  final String? classification;
  final Map<String, dynamic> data;

  const RequestEvent({
    required this.id,
    required this.requestId,
    required this.correlationId,
    required this.timestamp,
    required this.method,
    required this.path,
    required this.statusCode,
    required this.durationMs,
    required this.classification,
    required this.data,
  });

  factory RequestEvent.fromJson(Map<String, dynamic> json) {
    final rawTimestamp = json['timestamp'];
    return RequestEvent(
      id: '${json['id'] ?? ''}',
      requestId: '${json['request_id'] ?? ''}',
      correlationId: json['correlation_id']?.toString(),
      timestamp: rawTimestamp == null
          ? null
          : DateTime.tryParse(rawTimestamp.toString()),
      method: '${json['method'] ?? 'UNKNOWN'}'.toUpperCase(),
      path: '${json['path'] ?? '/'}',
      statusCode: _toInt(json['status_code']),
      durationMs: _toDouble(json['duration_ms']),
      classification: json['classification']?.toString(),
      data: redactMap(json),
    );
  }

  static int? _toInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  static double? _toDouble(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');

  String get category {
    if (classification == 'success') return 'Success';
    if (classification == 'client_error') return 'Client error';
    if (classification == 'server_error') return 'Server error';
    if (classification == 'exception') return 'Exception';
    final status = statusCode ?? 0;
    if (status >= 500) return 'Server error';
    if (status >= 400) return 'Client error';
    if (status >= 200 && status < 400) return 'Success';
    return classification ?? 'Unknown';
  }

  String get displayTimestamp => timestamp == null
      ? 'Unknown time'
      : timestamp!.toLocal().toString().split('.').first;

  String get safeDetails => const JsonEncoder.withIndent('  ').convert(data);

  static Map<String, dynamic> redactMap(Map<String, dynamic> source) {
    const sensitive = {
      'authorization', 'cookie', 'set-cookie', 'password', 'token',
      'secret', 'api_key', 'access_token', 'refresh_token',
    };
    dynamic redact(dynamic value, [String key = '']) {
      if (sensitive.contains(key.toLowerCase())) return '[REDACTED]';
      if (value is Map) {
        return value.map(
          (k, v) => MapEntry(k.toString(), redact(v, k.toString())),
        );
      }
      if (value is List) return value.map((item) => redact(item)).toList();
      if (value is String && key.toLowerCase().contains('body')) {
        try {
          return redact(jsonDecode(value), key);
        } catch (_) {
          return value;
        }
      }
      return value;
    }
    return Map<String, dynamic>.from(redact(source) as Map);
  }
}

class RequestEventPage {
  final int count;
  final String? next;
  final List<RequestEvent> results;

  const RequestEventPage({
    required this.count,
    required this.next,
    required this.results,
  });

  factory RequestEventPage.fromJson(dynamic json) {
    if (json is List) {
      return RequestEventPage(
        count: json.length,
        next: null,
        results: json
            .whereType<Map>()
            .map((item) => RequestEvent.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
      );
    }
    if (json is! Map || json['results'] is! List) {
      throw const FormatException('Invalid request-event response.');
    }
    final results = json['results'] as List;
    return RequestEventPage(
      count: int.tryParse('${json['count'] ?? results.length}') ?? results.length,
      next: json['next']?.toString(),
      results: results
          .whereType<Map>()
          .map((item) => RequestEvent.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}
