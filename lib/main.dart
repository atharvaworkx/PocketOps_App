import 'dart:convert';
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'projects_page.dart';
import 'observability_page.dart';
import 'monitoring_models.dart';

void main() => runApp(const PocketOpsApp());

const bg = Color(0xFF0B1017);
const surface = Color(0xFF141C26);
const border = Color(0xFF263241);
const muted = Color(0xFF91A0B2);
const green = Color(0xFF65E6B3);
const orange = Color(0xFFFFBE69);
const red = Color(0xFFFF7777);

class PocketOpsApp extends StatelessWidget {
  const PocketOpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PocketOps',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: green,
          surface: surface,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
    );
  }
}

// Checks whether a login session exists.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? hasSession;

  @override
  void initState() {
    super.initState();
    ApiService.onSessionExpired = _handleSessionExpired;
    _checkSession();
  }

  Future<void> _handleSessionExpired() async {
    if (mounted) setState(() => hasSession = false);
  }

  Future<void> _checkSession() async {
    final saved = await ApiService.hasSavedSession();
    if (mounted) setState(() => hasSession = saved);
  }

  void _onLoginSuccess() {
    setState(() => hasSession = true);
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) setState(() => hasSession = false);
  }

  @override
  Widget build(BuildContext context) {
    if (hasSession == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: green),
        ),
      );
    }

    if (hasSession!) {
      return HomeScreen(onLogout: _logout);
    }

    return LoginPage(onLoginSuccess: _onLoginSuccess);
  }
}

// Login screen.
class LoginPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginPage({
    super.key,
    required this.onLoginSuccess,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  String? errorMessage;

  Future<void> _login() async {
    if (usernameController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      setState(() {
        errorMessage = 'Enter your username and password.';
      });
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      await ApiService.login(
        usernameController.text.trim(),
        passwordController.text,
      );

      if (mounted) widget.onLoginSuccess();
    } catch (_) {
      if (mounted) {
        setState(() {
          errorMessage =
              'Login failed. Check your credentials or connection.';
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: green,
                    size: 58,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'PocketOps',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'API OPERATIONS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sign in to manage your APIs.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 36),
                  TextField(
                    controller: usernameController,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    onSubmitted: (_) {
                      if (!loading) _login();
                    },
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: red),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: loading ? null : _login,
                      child: loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Sign in'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Main application navigation.
class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const HomeScreen({
    super.key,
    required this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      OverviewPage(onLogout: widget.onLogout),
      const ProjectsPage(),
      const IncidentsPage(),
      const ObservabilityPage(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[selectedTab]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: surface,
        indicatorColor: green.withValues(alpha: 0.14),
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.layers_outlined),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_rounded),
            label: 'Incidents',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal_rounded),
            label: 'Logs',
          ),
        ],
      ),
    );
  }
}

// Overview dashboard. Metrics are still demo data.
class OverviewPage extends StatefulWidget {
  final VoidCallback onLogout;

  const OverviewPage({
    super.key,
    required this.onLogout,
  });

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> projects = [];

  @override
  void initState() {
    super.initState();
    loadProjects();
  }

  Future<void> loadProjects() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await ApiService.getProjects();
      if (response.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      if (response.statusCode != 200) {
        throw Exception('Could not load projects (${response.statusCode}).');
      }
      final decoded = jsonDecode(response.body);
      final items = decoded is List
          ? decoded
          : decoded is Map && decoded['results'] is List
              ? decoded['results'] as List
              : <dynamic>[];
      if (!mounted) return;
      setState(() {
        projects = items
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: green,
                size: 27,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PocketOps',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.7,
                    ),
                  ),
                  Text(
                    'API OPERATIONS',
                    style: TextStyle(
                      fontSize: 10,
                      color: muted,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: widget.onLogout,
              tooltip: 'Log out',
              icon: const Icon(Icons.logout_rounded),
            ),
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notifications will be connected later.'),
                  ),
                );
              },
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ],
        ),
        const SizedBox(height: 30),
        const Text(
          'Your APIs, at a glance.',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Here is the latest overview of your services.',
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(color: green),
            ),
          )
        else if (error != null)
          _overviewMessage(
            icon: Icons.cloud_off_outlined,
            title: 'Overview unavailable',
            message: error!,
            action: TextButton(
              onPressed: loadProjects,
              child: const Text('Retry'),
            ),
          )
        else if (projects.isEmpty)
          _overviewMessage(
            icon: Icons.folder_open_outlined,
            title: 'No projects yet',
            message: 'Create a project to start monitoring APIs.',
          )
        else ...[
          _liveSummary(),
          const SizedBox(height: 29),
          SectionHeading(
            title: 'Your projects',
            trailing: '${projects.length} configured',
          ),
          const SizedBox(height: 13),
          ...projects.map(_projectCard),
        ],
      ],
    );
  }

  Widget _liveSummary() {
    final endpointCount = projects.fold<int>(
      0,
      (sum, project) => sum + (_toInt(project['endpoint_count']) ?? 0),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          const Icon(Icons.layers_outlined, color: green, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Metric(
              value: '${projects.length}',
              label: 'Configured projects',
            ),
          ),
          Expanded(
            child: Metric(
              value: '$endpointCount',
              label: 'Configured endpoints',
            ),
          ),
        ],
      ),
    );
  }

  Widget _projectCard(Map<String, dynamic> project) {
    final name = project['name']?.toString() ?? 'Untitled project';
    final url = project['base_url']?.toString() ?? '';
    final description = project['description']?.toString() ?? '';
    final count = _toInt(project['endpoint_count']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ProjectCard(
        name: name,
        url: url,
        status: description.isEmpty ? 'Configured' : description,
        latency: count == null ? 'Endpoint count unavailable' : '$count endpoints',
        color: green,
        icon: Icons.folder_outlined,
      ),
    );
  }

  int? _toInt(Object? value) => value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');

  Widget _overviewMessage({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, color: muted, size: 42),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center,
              style: const TextStyle(color: muted)),
          ?action,
        ],
      ),
    );
  }
}

class IncidentsPage extends StatefulWidget {
  const IncidentsPage({super.key});

  @override
  State<IncidentsPage> createState() => _IncidentsPageState();
}

class _IncidentsPageState extends State<IncidentsPage> {
  bool loading = true;
  String? error;
  List<IncidentRecord> incidents = [];

  @override
  void initState() {
    super.initState();
    loadIncidents();
  }

  Future<void> loadIncidents() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final projectsResponse = await ApiService.getProjects();
      if (projectsResponse.statusCode == 401) {
        throw Exception('Session expired. Please sign in again.');
      }
      if (projectsResponse.statusCode != 200) {
        throw Exception('Could not load projects (${projectsResponse.statusCode}).');
      }
      final decoded = jsonDecode(projectsResponse.body);
      final rawProjects = decoded is List
          ? decoded
          : decoded is Map && decoded['results'] is List
              ? decoded['results'] as List
              : <dynamic>[];
      final projectIds = rawProjects
          .whereType<Map>()
          .map((project) => project['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();
      final results = <IncidentRecord>[];
      for (final projectId in projectIds) {
        final response = await ApiService.getProjectIncidents(projectId);
        if (response.statusCode == 401) {
          throw Exception('Session expired. Please sign in again.');
        }
        if (response.statusCode != 200) {
          throw Exception(
            'Could not load incidents (${response.statusCode}).',
          );
        }
        final data = jsonDecode(response.body);
        final items = data is List
            ? data
            : data is Map && data['results'] is List
                ? data['results'] as List
                : <dynamic>[];
        results.addAll(
          items.whereType<Map>().map(
                (item) => IncidentRecord.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              ),
        );
      }
      if (!mounted) return;
      setState(() {
        incidents = results;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: loadIncidents,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          const Text(
            'Incidents',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Failures and diagnostics from monitored projects.',
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 20),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: green),
              ),
            )
          else if (error != null)
            _incidentMessage(
              Icons.cloud_off_outlined,
              'Could not load incidents',
              error!,
              TextButton(onPressed: loadIncidents, child: const Text('Retry')),
            )
          else if (incidents.isEmpty)
            _incidentMessage(
              Icons.check_circle_outline,
              'No incidents found',
              'Recorded incidents will appear here.',
              null,
            )
          else
            ...incidents.map(_incidentCard),
        ],
      ),
    );
  }

  Widget _incidentCard(IncidentRecord incident) {
    final color = incident.resolved == true ? green : orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: color, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  incident.category,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (incident.httpStatus != null)
                StatusPill(
                  label: 'HTTP ${incident.httpStatus}',
                  color: color,
                ),
            ],
          ),
          if (incident.summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              incident.summary,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            [
              if (incident.occurredAt != null)
                incident.occurredAt!.toLocal().toString().split('.').first,
              if (incident.endpointId != null)
                'Endpoint ${incident.endpointId}',
              if (incident.resolved != null)
                incident.resolved! ? 'Resolved' : 'Unresolved',
            ].join('  •  '),
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          if (incident.explanation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(incident.explanation,
                style: const TextStyle(color: muted, height: 1.45)),
          ],
          if (incident.suggestedAction.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: green, size: 17),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    incident.suggestedAction,
                    style: const TextStyle(color: green, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _incidentMessage(
    IconData icon,
    String title,
    String message,
    Widget? action,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, color: muted, size: 42),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted)),
          ?action,
        ],
      ),
    );
  }
}

// HTTP request runner.
class RequestPage extends StatefulWidget {
  const RequestPage({super.key});

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  final urlController = TextEditingController();
  final bodyController = TextEditingController();

  String method = 'GET';
  bool loading = false;
  int? statusCode;
  int? latency;
  String responseBody = '';
  Map<String, String> responseHeaders = {};
  String? errorMessage;

Future<void> sendRequest() async {
  final rawUrl = urlController.text.trim();
  final uri = Uri.tryParse(rawUrl);

  if (uri == null ||
      !uri.hasAuthority ||
      !{'http', 'https'}.contains(uri.scheme)) {
    setState(() {
      errorMessage = 'Enter a valid HTTP or HTTPS URL.';
      statusCode = null;
      responseBody = '';
    });
    return;
  }

  setState(() {
    loading = true;
    errorMessage = null;
    statusCode = null;
    latency = null;
    responseBody = '';
    responseHeaders = {};
  });

  final stopwatch = Stopwatch()..start();

  try {
    final body = bodyController.text.trim();

    if (method != 'GET' && method != 'HEAD' && body.isNotEmpty) {
      jsonDecode(body);
    }

    final response = await ApiService.sendRunnerRequest(
      method: method,
      url: rawUrl,
      body: method == 'GET' || method == 'HEAD' || body.isEmpty
          ? null
          : body,
    );

    stopwatch.stop();

    if (!mounted) return;

    setState(() {
      statusCode = response.statusCode;
      latency = stopwatch.elapsedMilliseconds;
      responseBody = response.body;
      responseHeaders = response.headers;
    });
  } catch (e) {
    stopwatch.stop();

    if (!mounted) return;

    setState(() {
      errorMessage = e is FormatException
          ? 'Invalid URL or JSON body. Check your input.'
          : 'Request failed: $e';
      latency = stopwatch.elapsedMilliseconds;
    });
  } finally {
    if (mounted) {
      setState(() => loading = false);
    }
  }
}

  @override
  void dispose() {
    urlController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        const Text(
          'API Runner',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Send requests. Inspect responses. Debug faster.',
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'REQUEST',
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: method,
                dropdownColor: surface,
                decoration: const InputDecoration(
                  labelText: 'HTTP method',
                  border: OutlineInputBorder(),
                ),
                items: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: loading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => method = value);
                        }
                      },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Request URL',
                  hintText: 'https://api.example.com/health/',
                  prefixIcon: Icon(Icons.link_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: bodyController,
                minLines: 3,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: 'JSON body (optional)',
                  hintText: '{"username": "developer"}',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: loading ? null : sendRequest,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    loading ? 'Sending request...' : 'Send Request',
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: red.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              errorMessage!,
              style: const TextStyle(color: red, fontSize: 13),
            ),
          ),
        ],
        if (statusCode != null) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'RESPONSE',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusPill(
                label: 'HTTP $statusCode',
                color: statusCode! < 400 ? green : red,
              ),
              const SizedBox(width: 10),
              Text(
                '${latency ?? 0} ms',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BODY',
                  style: TextStyle(
                    color: green,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  responseBody.isEmpty
                      ? '(Empty response body)'
                      : responseBody,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'HEADERS',
                  style: TextStyle(
                    color: green,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                ...responseHeaders.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${entry.key}: ${entry.value}',
                      style: const TextStyle(
                        color: muted,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class SimplePage extends StatelessWidget {
  final String title;
  final String subtitle;
  final String message;
  final IconData icon;

  const SimplePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: green),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(subtitle, style: const TextStyle(color: muted)),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class Metric extends StatelessWidget {
  final String value;
  final String label;
  final String suffix;

  const Metric({
    super.key,
    required this.value,
    required this.label,
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                suffix,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: muted, fontSize: 11)),
      ],
    );
  }
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String trailing;

  const SectionHeading({
    super.key,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          trailing,
          style: const TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const StatusPill({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class ProjectCard extends StatelessWidget {
  final String name;
  final String url;
  final String status;
  final String latency;
  final Color color;
  final IconData icon;

  const ProjectCard({
    super.key,
    required this.name,
    required this.url,
    required this.status,
    required this.latency,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            height: 43,
            width: 43,
            decoration: BoxDecoration(
              color: const Color(0xFF202C39),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: muted, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  url,
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Icon(Icons.circle, color: color, size: 7),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: TextStyle(color: color, fontSize: 10),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.schedule, color: muted, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      latency,
                      style: const TextStyle(color: muted, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: muted, size: 20),
        ],
      ),
    );
  }
}