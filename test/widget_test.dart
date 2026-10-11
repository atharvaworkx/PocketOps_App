
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:pocketops/main.dart';
import 'package:pocketops/monitoring_models.dart';
import 'package:pocketops/observability_models.dart';

void main() {
  testWidgets('PocketOps app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const PocketOpsApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  test('parses request events and redacts sensitive values', () {
    final event = RequestEvent.fromJson({
      'id': 'event-1',
      'request_id': 'request-1',
      'timestamp': '2026-10-11T21:00:00Z',
      'method': 'post',
      'path': '/api/v1/projects/',
      'status_code': 400,
      'duration_ms': 24.5,
      'classification': 'client_error',
      'request_headers': {'authorization': 'Bearer secret'},
      'request_body': '{"password":"secret"}',
    });

    expect(event.method, 'POST');
    expect(event.category, 'Client error');
    expect(event.durationMs, 24.5);
    expect(event.safeDetails, contains('[REDACTED]'));
    expect(event.safeDetails, isNot(contains('Bearer secret')));
  });

  test('parses missing optional fields', () {
    final event = RequestEvent.fromJson({
      'id': 'event-2',
      'request_id': 'request-2',
      'method': 'GET',
      'path': '/health/',
    });

    expect(event.statusCode, isNull);
    expect(event.timestamp, isNull);
    expect(event.category, 'Unknown');
  });

  test('rejects malformed paginated responses', () {
    expect(
      () => RequestEventPage.fromJson({'count': 1}),
      throwsFormatException,
    );
  });

  test('parses incident and check records', () {
    final incident = IncidentRecord.fromJson({
      'id': 'incident-1',
      'project': 'project-1',
      'endpoint': 'endpoint-1',
      'occurred_at': '2026-10-11T21:00:00Z',
      'http_status': 500,
      'diagnostic_category': 'server_error',
      'summary': 'Server failed',
      'resolved': false,
    });
    final check = CheckRecord.fromJson({
      'id': 'check-1',
      'endpoint': 'endpoint-1',
      'status_code': 200,
      'duration_ms': 42.5,
      'success': true,
      'checked_at': '2026-10-11T21:00:00Z',
    });

    expect(incident.projectId, 'project-1');
    expect(incident.httpStatus, 500);
    expect(incident.resolved, isFalse);
    expect(check.endpointId, 'endpoint-1');
    expect(check.statusCode, 200);
    expect(check.durationMs, 42.5);
    expect(check.success, isTrue);
  });
}
