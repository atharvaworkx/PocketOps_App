import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'main.dart' show border, green, muted, red, surface;
import 'observability_models.dart';

class ObservabilityPage extends StatefulWidget {
  final Future<dynamic> Function(int page)? loader;
  const ObservabilityPage({super.key, this.loader});
  @override
  State<ObservabilityPage> createState() => _ObservabilityPageState();
}

class _ObservabilityPageState extends State<ObservabilityPage> {
  final path = TextEditingController();
  final requestId = TextEditingController();
  final status = TextEditingController();
  final minDuration = TextEditingController();
  final maxDuration = TextEditingController();
  DateTime? startTime;
  DateTime? endTime;
  List<RequestEvent> events = [];
  bool loading = true, loadingMore = false, hasMore = false;
  String? error;
  int currentPage = 1;
  String method = '', classification = '';

  Future<dynamic> _fetch(int page) => widget.loader != null
      ? widget.loader!(page)
      : ApiService.getObservabilityRequests(
          page: page,
          method: method.isEmpty ? null : method,
          path: path.text.trim(),
          requestId: requestId.text.trim(),
          statusCode: int.tryParse(status.text.trim()),
          startTime: startTime,
          endTime: endTime,
          minDurationMs: double.tryParse(minDuration.text.trim()),
          maxDurationMs: double.tryParse(maxDuration.text.trim()),
          classification: classification.isEmpty ? null : classification,
        );

  Future<void> load({bool refresh = true}) async {
    setState(() {
      if (refresh) loading = true;
      if (!refresh) loadingMore = true;
      error = null;
    });
    try {
      final raw = await _fetch(refresh ? 1 : currentPage + 1);
      if (raw is! RequestEventPage) {
        if (raw.statusCode == 401) {
          throw Exception('Session expired. Please sign in again.');
        }
        if (raw.statusCode < 200 || raw.statusCode >= 300) {
          throw Exception('Request logs unavailable (${raw.statusCode}).');
        }
      }
      final page = raw is RequestEventPage
          ? raw
          : RequestEventPage.fromJson(jsonDecode(raw.body as String));
      if (!mounted) return;
      setState(() {
        events = refresh ? page.results : [...events, ...page.results];
        currentPage = refresh ? 1 : currentPage + 1;
        hasMore = page.next != null;
        loading = false;
        loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadingMore = false;
        error = e is FormatException ? e.message : e.toString();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    path.dispose();
    requestId.dispose();
    status.dispose();
    minDuration.dispose();
    maxDuration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () => load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            const Text('Request Logs',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            const Text('Incoming requests received by your backend.',
                style: TextStyle(color: muted)),
            const SizedBox(height: 18),
            _filters(),
            const SizedBox(height: 16),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: green),
                ),
              )
            else if (error != null)
              _message(Icons.cloud_off_outlined, 'Could not load requests',
                  error!, true)
            else if (events.isEmpty)
              _message(Icons.inbox_outlined, 'No requests found',
                  'Requests received by the backend will appear here.', false)
            else ...[
              for (final event in events) _tile(event),
              if (hasMore)
                OutlinedButton(
                  onPressed: loadingMore ? null : () => load(refresh: false),
                  child: loadingMore
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Load more'),
                ),
            ],
          ],
        ),
      );

  Widget _filters() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          children: [
            Row(children: [
              Expanded(child: _dropdown('Method', method,
                  ['', 'GET', 'POST', 'PUT', 'PATCH', 'DELETE'], (v) {
                setState(() => method = v);
              })),
              const SizedBox(width: 10),
              Expanded(child: _dropdown('Class', classification,
                  ['', 'success', 'client_error', 'server_error', 'exception'],
                  (v) {
                setState(() => classification = v);
              })),
            ]),
            TextField(
              controller: path,
              decoration: const InputDecoration(labelText: 'Path contains'),
            ),
            TextField(
              controller: requestId,
              decoration: const InputDecoration(labelText: 'Request ID'),
            ),
            TextField(
              controller: status,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Status code'),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(true),
                    child: Text(
                      startTime == null
                          ? 'Start time'
                          : _dateLabel(startTime!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(false),
                    child: Text(
                      endTime == null ? 'End time' : _dateLabel(endTime!),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minDuration,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration:
                        const InputDecoration(labelText: 'Min ms'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: maxDuration,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration:
                        const InputDecoration(labelText: 'Max ms'),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => load(),
                    child: const Text('Apply filters'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Future<void> _pickDate(bool start) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: (start ? startTime : endTime) ?? DateTime.now(),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (start) {
        startTime = DateTime(
          selected.year,
          selected.month,
          selected.day,
        );
      } else {
        endTime = DateTime(
          selected.year,
          selected.month,
          selected.day,
          23,
          59,
          59,
        );
      }
    });
  }

  String _dateLabel(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  void _clearFilters() {
    path.clear();
    requestId.clear();
    status.clear();
    minDuration.clear();
    maxDuration.clear();
    setState(() {
      method = '';
      classification = '';
      startTime = null;
      endTime = null;
    });
    load();
  }

  Widget _dropdown(String label, String value, List<String> values,
          ValueChanged<String> onChanged) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: values
            .map((v) => DropdownMenuItem(
                value: v, child: Text(v.isEmpty ? 'All' : v)))
            .toList(),
        onChanged: (v) => onChanged(v ?? ''),
      );

  Widget _tile(RequestEvent event) {
    final color = event.category == 'Success'
        ? green
        : event.category == 'Client error'
            ? Colors.orangeAccent
            : red;
    return Card(
      color: surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        onTap: () => _details(event),
        title: Row(children: [
          Text(event.method,
              style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Expanded(child: Text(event.path, overflow: TextOverflow.ellipsis)),
          Text('${event.statusCode ?? '-'}',
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ]),
        subtitle: Text(
          '${event.category}  •  ${event.durationMs?.toStringAsFixed(1) ?? '-'} ms\n'
          '${event.displayTimestamp}  •  ${event.requestId}',
          style: const TextStyle(color: muted, height: 1.45, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: muted),
      ),
    );
  }

  Future<void> _details(RequestEvent event) async {
    var detail = event;
    if (event.id.isNotEmpty && widget.loader == null) {
      try {
        final response = await ApiService.getObservabilityRequest(event.id);
        if (response.statusCode == 401) {
          throw Exception('Session expired. Please sign in again.');
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('Could not load request details.');
        }
        detail = RequestEvent.fromJson(
          Map<String, dynamic>.from(jsonDecode(response.body) as Map),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$e')));
        }
        return;
      }
    }
    if (mounted) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => RequestDetailPage(event: detail)));
    }
  }

  Widget _message(IconData icon, String title, String text, bool retry) =>
      Padding(
        padding: const EdgeInsets.all(35),
        child: Column(children: [
          Icon(icon, color: retry ? red : muted, size: 42),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(text, textAlign: TextAlign.center,
              style: const TextStyle(color: muted)),
          if (retry) TextButton(onPressed: load, child: const Text('Retry')),
        ]),
      );
}

class RequestDetailPage extends StatelessWidget {
  final RequestEvent event;
  const RequestDetailPage({super.key, required this.event});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Request details')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('${event.method} ${event.path}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _row('Status', '${event.statusCode ?? '-'}'),
            _row('Classification', event.category),
            _row('Timestamp', event.displayTimestamp),
            _row('Duration', '${event.durationMs?.toStringAsFixed(1) ?? '-'} ms'),
            _row('Request ID', event.requestId),
            if (event.correlationId != null)
              _row('Correlation ID', event.correlationId!),
            const SizedBox(height: 14),
            const Text('Recorded data',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SelectableText(event.safeDetails,
                style: const TextStyle(color: muted, fontFamily: 'monospace')),
          ],
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: muted))),
          Expanded(child: Text(value)),
        ]),
      );
}
