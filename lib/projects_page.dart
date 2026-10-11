
import 'dart:convert';
import 'project_details_page.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';

const _bg = Color(0xFF0B1017);
const _surface = Color(0xFF141C26);
const _border = Color(0xFF263241);
const _muted = Color(0xFF91A0B2);
const _green = Color(0xFF65E6B3);

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  bool loading = true;
  bool creating = false;
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

      if (response.statusCode != 200) {
        throw Exception(
          'API returned ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      final List<dynamic> items = decoded is List
          ? decoded
          : (decoded['results'] as List? ?? []);

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
        error = e.toString();
        loading = false;
      });
    }
  }


  Future<void> showCreateProjectDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final descriptionController = TextEditingController();

    bool dialogCreating = false;

    try {
      final created = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: _surface,
                title: const Text('Add project'),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _field(
                          nameController,
                          'Project name',
                          required: true,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          urlController,
                          'Base URL (https://...)',
                          required: true,
                          isUrl: true,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          descriptionController,
                          'Description (optional)',
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: dialogCreating
                        ? null
                        : () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: dialogCreating
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }

                            setDialogState(() => dialogCreating = true);

                            try {
                              final response =
                                  await ApiService.createProject(
                                name: nameController.text,
                                baseUrlValue: urlController.text,
                                description: descriptionController.text,
                              );

                              if (response.statusCode != 201 &&
                                  response.statusCode != 200) {
                                throw Exception(
                                  'API ${response.statusCode}: '
                                  '${response.body}',
                                );
                              }

                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext, true);
                              }
                            } catch (e) {
                              if (!dialogContext.mounted) return;

                              setDialogState(
                                () => dialogCreating = false,
                              );

                              ScaffoldMessenger.of(dialogContext)
                                .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Could not create project: $e',
                                    ),
                                  ),
                                );
                            }
                          },
                    child: dialogCreating
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Create project'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (created == true && mounted) {
        await loadProjects();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project created successfully.'),
          ),
        );
      }
    } finally {
      nameController.dispose();
      urlController.dispose();
      descriptionController.dispose();
    }
  }


  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool isUrl = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType:
          isUrl ? TextInputType.url : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _muted),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';

        if (required && text.isEmpty) {
          return 'This field is required';
        }

        if (isUrl && text.isNotEmpty) {
          final uri = Uri.tryParse(text);
          if (uri == null ||
              !{'http', 'https'}.contains(uri.scheme) ||
              uri.host.isEmpty) {
            return 'Enter a valid URL including https://';
          }
        }

        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showCreateProjectDialog,
        backgroundColor: _green,
        foregroundColor: _bg,
        icon: const Icon(Icons.add),
        label: const Text('Add project'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadProjects,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Projects',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Manage your monitored services',
                          style: TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: loadProjects,
                    icon: const Icon(
                      Icons.refresh,
                      color: _green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: _green),
                  ),
                )
              else if (error != null)
                _messageCard(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load projects',
                  message: error!,
                  action: TextButton(
                    onPressed: loadProjects,
                    child: const Text('Retry'),
                  ),
                )
              else if (projects.isEmpty)
                _messageCard(
                  icon: Icons.folder_open_outlined,
                  title: 'No projects yet',
                  message:
                      'Create your first project to start monitoring APIs.',
                  action: FilledButton.icon(
                    onPressed: showCreateProjectDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Create project'),
                  ),
                )
              else ...[
                Text(
                  '${projects.length} project${projects.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                ...projects.map(_projectCard),
              ],
            ],
          ),
        ),
      ),
    );
  }


Widget _projectCard(Map<String, dynamic> project) {
  final name = project['name']?.toString() ?? 'Untitled project';
  final baseUrl = project['base_url']?.toString() ?? '';
  final description = project['description']?.toString() ?? '';
  final endpointCount = project['endpoint_count'] ?? 0;

  return InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProjectDetailsPage(project: project),
        ),
      );
    },
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.folder_outlined,
                  color: _green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: _muted,
              ),
            ],
          ),
          if (baseUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              baseUrl,
              style: const TextStyle(
                color: _green,
                fontSize: 13,
              ),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: _muted),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.link,
                size: 16,
                color: _muted,
              ),
              const SizedBox(width: 6),
              Text(
                '$endpointCount endpoints',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}


  Widget _messageCard({
    required IconData icon,
    required String title,
    required String message,
    required Widget action,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: _muted, size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 16),
          action,
        ],
      ),
    );
  }
}
