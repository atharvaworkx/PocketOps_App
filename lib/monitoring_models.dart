class IncidentRecord {
  final String id;
  final String? projectId;
  final String? endpointId;
  final DateTime? occurredAt;
  final int? httpStatus;
  final String category;
  final String summary;
  final dynamic safeDetails;
  final String explanation;
  final String suggestedAction;
  final bool? resolved;

  const IncidentRecord({
    required this.id,
    required this.projectId,
    required this.endpointId,
    required this.occurredAt,
    required this.httpStatus,
    required this.category,
    required this.summary,
    required this.safeDetails,
    required this.explanation,
    required this.suggestedAction,
    required this.resolved,
  });

  factory IncidentRecord.fromJson(Map<String, dynamic> json) {
    return IncidentRecord(
      id: '${json['id'] ?? ''}',
      projectId: json['project']?.toString(),
      endpointId: json['endpoint']?.toString(),
      occurredAt: DateTime.tryParse('${json['occurred_at'] ?? ''}'),
      httpStatus: _int(json['http_status']),
      category: '${json['diagnostic_category'] ?? 'Incident'}',
      summary: '${json['summary'] ?? ''}',
      safeDetails: json['safe_details'],
      explanation: '${json['explanation'] ?? ''}',
      suggestedAction: '${json['suggested_action'] ?? ''}',
      resolved: json['resolved'] is bool ? json['resolved'] as bool : null,
    );
  }

  static int? _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
}

class CheckRecord {
  final String id;
  final String? endpointId;
  final int? statusCode;
  final double? durationMs;
  final bool? success;
  final String errorMessage;
  final String responseSummary;
  final DateTime? checkedAt;

  const CheckRecord({
    required this.id,
    required this.endpointId,
    required this.statusCode,
    required this.durationMs,
    required this.success,
    required this.errorMessage,
    required this.responseSummary,
    required this.checkedAt,
  });

  factory CheckRecord.fromJson(Map<String, dynamic> json) {
    return CheckRecord(
      id: '${json['id'] ?? ''}',
      endpointId: json['endpoint']?.toString(),
      statusCode: _int(json['status_code']),
      durationMs: _double(json['duration_ms']),
      success: json['success'] is bool ? json['success'] as bool : null,
      errorMessage: '${json['error_message'] ?? ''}',
      responseSummary: '${json['response_summary'] ?? ''}',
      checkedAt: DateTime.tryParse(
        '${json['checked_at'] ?? json['timestamp'] ?? ''}',
      ),
    );
  }

  static int? _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  static double? _double(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '');
}
