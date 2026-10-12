
import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'monitoring_models.dart';


const _bg = Color(0xFF0B1017);
const _surface = Color(0xFF141C26);
const _border = Color(0xFF263241);
const _muted = Color(0xFF91A0B2);
const _green = Color(0xFF65E6B3);
const _red = Color(0xFFFF7777);

class ProjectDetailsPage extends StatefulWidget {
  final Map<String, dynamic> project;

  const ProjectDetailsPage({super.key, required this.project});

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  List<Map<String, dynamic>> endpoints = [];
  bool loading = true;
  bool runningChecks = false;
  String? error;
  String? lastResult;
  bool? lastResultSuccess;
  List<CheckRecord> checks = [];
  bool checksLoading = true;
  String? checksError;
  String? selectedEndpointId;

  String get projectId => widget.project['id'].toString();

  @override
  void initState() {
    super.initState();
    loadEndpoints();
    loadChecks();
  }

  Future<void> loadEndpoints() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await ApiService.getProjectEndpoints(projectId);
      if (response.statusCode != 200) {
        throw Exception('API ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final List<dynamic> items =
          data is List ? data : (data['results'] as List? ?? []);

      if (!mounted) return;
      setState(() {
        endpoints = items
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> addEndpoint() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final pathController = TextEditingController(text: '/posts');
    final statusController = TextEditingController(text: '200');
    String method = 'GET';
    bool saving = false;

    try {
      final saved = await showDialog<Map<String, dynamic>?>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: _surface,
            title: const Text('Add endpoint'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: method,
                      dropdownColor: _surface,
                      decoration: const InputDecoration(labelText: 'Method'),
                      items: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() => method = value);
                              }

                            },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: pathController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Path',
                        hintText: '/posts',
                      ),
                      validator: (v) {
                        if (v == null || !v.trim().startsWith('/')) {
                          return 'Path must start with /';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: statusController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Expected HTTP status',
                      ),
                      validator: (v) {
                        final value = int.tryParse(v ?? '');
                        return value == null || value < 100 || value > 599
                            ? 'Enter a status from 100 to 599'
                            : null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => saving = true);

                        try {
                          final response = await ApiService.createEndpoint(
                            projectId: projectId,
                            name: nameController.text,
                            path: pathController.text,
                            method: method,
                            expectedStatus: int.parse(statusController.text),
                          );

                          if (response.statusCode != 201 &&
                              response.statusCode != 200) {
                            throw Exception(
                              'API ${response.statusCode}: ${response.body}',
                            );
                          }

                          Map<String, dynamic>? latestCheck;
                          final decoded = jsonDecode(response.body);
                          if (decoded is Map &&
                              decoded['latest_check'] is Map) {
                            latestCheck = Map<String, dynamic>.from(
                              decoded['latest_check'] as Map,
                            );
                          }

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, {
                              'latest_check': latestCheck,
                            });
                          }
                        } catch (e) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('Could not add endpoint: $e')),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save endpoint'),
              ),
            ],
          ),
        ),
      );

      if (saved != null && mounted) {
        final latestCheck = saved['latest_check'];
        if (latestCheck is Map) {
          final success = latestCheck['success'] == true;
          final statusCode = latestCheck['status_code'];
          final errorMessage = latestCheck['error_message']?.toString() ?? '';
          setState(() {
            lastResultSuccess = success;
            lastResult = success
                ? 'Endpoint check succeeded'
                    '${statusCode != null ? ' · HTTP $statusCode' : ''}'
                : 'Endpoint check failed'
                    '${statusCode != null ? ' · HTTP $statusCode' : ''}'
                    '${errorMessage.isNotEmpty ? ' · $errorMessage' : ''}';
          });
        }
        await loadEndpoints();
        await loadChecks();
      }
    } finally {
      nameController.dispose();
      pathController.dispose();
      statusController.dispose();
    }
  }

  Future<void> loadChecks() async {
    setState(() {
      checksLoading = true;
      checksError = null;
    });
    try {
      final response = await ApiService.getProjectChecks(
        projectId,
        endpointId: selectedEndpointId,
      );
      if (response.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      if (response.statusCode != 200) {
        throw Exception(
          'Could not load check history (${response.statusCode}).',
        );
      }
      final decoded = jsonDecode(response.body);
      final items = decoded is List
          ? decoded
          : decoded is Map && decoded['results'] is List
              ? decoded['results'] as List
              : <dynamic>[];
      if (!mounted) return;
      setState(() {
        checks = items
            .whereType<Map>()
            .map((item) => CheckRecord.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList();
        checksLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        checksLoading = false;
        checksError = e.toString();
      });
    }
  }

  Future<void> runAllChecks() async {
    setState(() {
      runningChecks = true;
      lastResult = null;
      lastResultSuccess = null;
    });

    try {
      final response = await ApiService.runProjectChecks(projectId);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('API ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() {
        lastResultSuccess = null;
        lastResult = _fullCheckSummary(data);
        runningChecks = false;
      });
      await loadChecks();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health checks triggered.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        lastResultSuccess = null;
        lastResult = 'Could not run checks: $e';
        runningChecks = false;
      });
    }

  }

  String _fullCheckSummary(dynamic data) {
    if (data is List) {
      return 'Health check returned ${data.length} result(s).';
    }
    if (data is Map && data['results'] is List) {
      return 'Health check returned ${(data['results'] as List).length} result(s).';
    }
    if (data is Map && data.isNotEmpty) {
      return 'Health check completed. Backend returned result details.';
    }
    return 'Health check completed with no result details.';
  }

  Future<void> runOneCheck(Map<String, dynamic> endpoint) async {
    final endpointId = endpoint['id']?.toString();
    if (endpointId == null || endpointId.isEmpty) return;

    try {
      final response =
          await ApiService.runEndpointCheck(projectId, endpointId);

      if (response.statusCode != 200) {
        throw Exception('API ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body);
      if (!mounted) return;

      final success = data is Map && data['success'] == true;
      final status = data is Map ? data['status_code'] : null;
      final duration = data is Map ? data['duration_ms'] : null;

      setState(() {
        lastResultSuccess = success;
        lastResult =
            '${endpoint['name']}: ${success ? 'SUCCESS' : 'CHECK COMPLETED'}'
            '${status != null ? ' · HTTP $status' : ''}'
            '${duration != null ? ' · $duration ms' : ''}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        lastResultSuccess = false;
        lastResult = 'Check failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.project['name']?.toString() ?? 'Project';
    final baseUrl = widget.project['base_url']?.toString() ?? '';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        title: Text(name),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addEndpoint,
        backgroundColor: _green,
        foregroundColor: _bg,
        icon: const Icon(Icons.add),
        label: const Text('Add endpoint'),
      ),
      body: RefreshIndicator(
        onRefresh: loadEndpoints,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BASE URL',
                      style: TextStyle(color: _muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  SelectableText(baseUrl,
                      style: const TextStyle(color: _green)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: runningChecks ? null : runAllChecks,
                      icon: runningChecks
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.monitor_heart_outlined),
                      label: Text(
                        runningChecks ? 'Running checks...' : 'Run all checks',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (lastResult != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    if (lastResultSuccess != null) ...[
                      Icon(
                        lastResultSuccess == true
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: lastResultSuccess == true ? _green : _red,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        lastResult!,
                        style: TextStyle(
                          color: lastResultSuccess == true
                              ? _green
                              : lastResultSuccess == false
                                  ? _red
                                  : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Check history',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: loadChecks,
                  icon: const Icon(Icons.refresh, color: _green),
                ),
              ],
            ),
            DropdownButtonFormField<String?>(
              initialValue: selectedEndpointId,
              decoration: const InputDecoration(labelText: 'Filter endpoint'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All endpoints'),
                ),
                ...endpoints.map(
                  (endpoint) => DropdownMenuItem<String?>(
                    value: endpoint['id']?.toString(),
                    child: Text(endpoint['name']?.toString() ?? 'Endpoint'),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => selectedEndpointId = value);
                loadChecks();
              },
            ),
            const SizedBox(height: 8),
            if (checksLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: _green),
                ),
              )
            else if (checksError != null)
              Text(checksError!, style: const TextStyle(color: _red))
            else if (checks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'No check history yet.',
                  style: TextStyle(color: _muted),
                ),
              )
            else
              ...checks.map(_checkCard),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Endpoints',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: loadEndpoints,
                  icon: const Icon(Icons.refresh, color: _green),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator(color: _green),
                ),
              )
            else if (error != null)
              Text(error!, style: const TextStyle(color: _red))
            else if (endpoints.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No endpoints yet. Add /posts to start monitoring.',
                  style: TextStyle(color: _muted),
                ),
              )
            else
              ...endpoints.map((endpoint) {
                final method = endpoint['method']?.toString() ?? 'GET';
                final path = endpoint['path']?.toString() ?? '';
                final endpointName =
                    endpoint['name']?.toString() ?? path;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface,
                    border: Border.all(color: _border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              method,
                              style: const TextStyle(
                                color: _green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              endpointName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(path, style: const TextStyle(color: _muted)),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => runOneCheck(endpoint),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Check now'),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }

  Widget _checkCard(CheckRecord check) {
    final color = check.success == true ? _green : _red;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                check.success == true
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  check.success == true ? 'Success' : 'Failed',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (check.statusCode != null)
                Text(
                  'HTTP ${check.statusCode}',
                  style: const TextStyle(color: _muted),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            [
              if (check.durationMs != null)
                '${check.durationMs!.toStringAsFixed(1)} ms',
              if (check.checkedAt != null)
                check.checkedAt!.toLocal().toString().split('.').first,
              if (check.endpointId != null) 'Endpoint ${check.endpointId}',
            ].join('  •  '),
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          if (check.errorMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(check.errorMessage,
                style: const TextStyle(color: _red, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
