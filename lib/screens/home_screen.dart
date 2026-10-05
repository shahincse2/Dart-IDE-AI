import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project_model.dart';
import '../providers/file_provider.dart';
import '../utils/constants.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';

/// Landing screen — lists real projects from [FileProvider].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FileProvider>().loadProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fileProvider = context.watch<FileProvider>();
    final hasProjects = fileProvider.projects.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: fileProvider.isLoadingProjects
            ? const Center(child: CircularProgressIndicator())
            : hasProjects
                ? ListView.separated(
                    padding: const EdgeInsets.all(AppConstants.spaceMd),
                    itemCount: fileProvider.projects.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppConstants.spaceSm),
                    itemBuilder: (context, i) {
                      final project = fileProvider.projects[i];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(Icons.folder_outlined),
                          title: Text(project.name),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _openProject(context, project),
                        ),
                      );
                    },
                  )
                : _EmptyProjectsView(onCreate: () => _createProject(context)),
      ),
      floatingActionButton: hasProjects
          ? FloatingActionButton.extended(
              onPressed: () => _createProject(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New project'),
            )
          : null,
    );
  }

  Future<void> _createProject(BuildContext context) async {
    final name = await _promptProjectName(context);
    if (name == null || name.isEmpty || !context.mounted) return;
    final fileProvider = context.read<FileProvider>();
    final project = await fileProvider.createProject(name);
    if (!context.mounted) return;
    await _openProject(context, project);
  }

  Future<void> _openProject(BuildContext context, ProjectModel project) async {
    final fileProvider = context.read<FileProvider>();
    await fileProvider.openProject(project);
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EditorScreen()));
  }
}

class _EmptyProjectsView extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyProjectsView({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.code_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppConstants.spaceMd),
              Text(
                'Start your first project',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spaceSm),
              Text(
                'Write and run Dart code right on your phone — '
                'no computer needed.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spaceLg),
              SizedBox(
                height: AppConstants.minTouchTarget,
                child: FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New project'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _promptProjectName(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('New project'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Project name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('Create'),
        ),
      ],
    ),
  );
}
