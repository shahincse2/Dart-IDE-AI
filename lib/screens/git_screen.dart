import 'package:flutter/material.dart';

import '../services/git_service.dart';
import '../utils/constants.dart';

/// Entry point for GitHub/GitLab integration.
/// Shows tabs for GitHub and GitLab.
class GitScreen extends StatelessWidget {
  final String fileContent;
  final String fileName;

  const GitScreen({
    super.key,
    required this.fileContent,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Git'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'GitHub'),
              Tab(text: 'GitLab'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _GitProviderPanel(
              provider: GitProvider.github,
              fileContent: fileContent,
              fileName: fileName,
            ),
            _GitProviderPanel(
              provider: GitProvider.gitlab,
              fileContent: fileContent,
              fileName: fileName,
            ),
          ],
        ),
      ),
    );
  }
}

class _GitProviderPanel extends StatefulWidget {
  final GitProvider provider;
  final String fileContent;
  final String fileName;

  const _GitProviderPanel({
    required this.provider,
    required this.fileContent,
    required this.fileName,
  });

  @override
  State<_GitProviderPanel> createState() => _GitProviderPanelState();
}

class _GitProviderPanelState extends State<_GitProviderPanel> {
  final _service = GitService();
  final _tokenController = TextEditingController();
  final _gitlabUrlController =
      TextEditingController(text: 'https://gitlab.com');

  bool _isLoading = false;
  String? _token;
  String? _username;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _gitlabUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final token = await _service.getToken(widget.provider);
    if (token != null && mounted) {
      setState(() => _token = token);
      await _fetchUsername(token);
    }
  }

  Future<void> _fetchUsername(String token) async {
    setState(() => _isLoading = true);
    try {
      final username = widget.provider == GitProvider.github
          ? await _service.getGitHubUsername(token)
          : await _service.getGitLabUsername(
              token, _gitlabUrlController.text.trim());
      if (mounted) setState(() => _username = username);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _connect() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _service.saveToken(widget.provider, token,
        gitlabUrl: widget.provider == GitProvider.gitlab
            ? _gitlabUrlController.text.trim()
            : null);
    await _fetchUsername(token);
    if (mounted) {
      setState(() {
        _token = token;
        _isLoading = false;
      });
    }
  }

  Future<void> _disconnect() async {
    await _service.clearToken(widget.provider);
    if (mounted)
      setState(() {
        _token = null;
        _username = null;
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_token == null || _username == null) {
      return _TokenSetupView(
        provider: widget.provider,
        tokenController: _tokenController,
        gitlabUrlController: _gitlabUrlController,
        onConnect: _connect,
        error: _error,
      );
    }
    return _PushView(
      provider: widget.provider,
      service: _service,
      token: _token!,
      username: _username!,
      fileContent: widget.fileContent,
      fileName: widget.fileName,
      gitlabBaseUrl: _gitlabUrlController.text.trim(),
      onDisconnect: _disconnect,
    );
  }
}

class _TokenSetupView extends StatelessWidget {
  final GitProvider provider;
  final TextEditingController tokenController;
  final TextEditingController gitlabUrlController;
  final VoidCallback onConnect;
  final String? error;

  const _TokenSetupView({
    required this.provider,
    required this.tokenController,
    required this.gitlabUrlController,
    required this.onConnect,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final isGitHub = provider == GitProvider.github;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isGitHub ? 'Connect to GitHub' : 'Connect to GitLab',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Text(
            isGitHub
                ? 'Create a Personal Access Token at '
                    'github.com → Settings → Developer Settings → PAT.\n'
                    'Required scope: repo'
                : 'Create a Personal Access Token at '
                    'GitLab → User Settings → Access Tokens.\n'
                    'Required scope: api',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppConstants.spaceMd),
          if (!isGitHub) ...[
            TextField(
              controller: gitlabUrlController,
              decoration: const InputDecoration(
                labelText: 'GitLab URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppConstants.spaceSm),
          ],
          TextField(
            controller: tokenController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Personal Access Token',
              border: const OutlineInputBorder(),
              errorText: error,
            ),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          FilledButton(
            onPressed: onConnect,
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}

class _PushView extends StatefulWidget {
  final GitProvider provider;
  final GitService service;
  final String token;
  final String username;
  final String fileContent;
  final String fileName;
  final String gitlabBaseUrl;
  final VoidCallback onDisconnect;

  const _PushView({
    required this.provider,
    required this.service,
    required this.token,
    required this.username,
    required this.fileContent,
    required this.fileName,
    required this.gitlabBaseUrl,
    required this.onDisconnect,
  });

  @override
  State<_PushView> createState() => _PushViewState();
}

class _PushViewState extends State<_PushView> {
  final _repoController = TextEditingController();
  final _commitController =
      TextEditingController(text: 'Add Dart file from DartLab');
  bool _isPrivate = false;
  bool _isLoading = false;
  String? _statusMessage;
  String? _repoUrl;

  @override
  void dispose() {
    _repoController.dispose();
    _commitController.dispose();
    super.dispose();
  }

  Future<void> _createAndPush() async {
    final repoName = _repoController.text.trim();

    if (repoName.isEmpty) {
      setState(() {
        _statusMessage = 'Repository name is required.';
        _repoUrl = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _repoUrl = null;
    });

    try {
      if (widget.provider == GitProvider.github) {
        final repo = await widget.service.createGitHubRepo(
          widget.token,
          name: repoName,
          isPrivate: _isPrivate,
        );

        if (!mounted) return;

        if (repo == null) {
          setState(() {
            _statusMessage = 'Failed to create repository.';
            _repoUrl = null;
          });
          return;
        }

        final result = await widget.service.pushFileToGitHub(
          widget.token,
          owner: widget.username,
          repo: repoName,
          path: widget.fileName,
          content: widget.fileContent,
          commitMessage: _commitController.text.trim(),
        );

        if (!mounted) return;

        setState(() {
          if (result.success) {
            _statusMessage = 'Pushed successfully!';
            _repoUrl = repo.htmlUrl;
          } else {
            _statusMessage = result.message ?? 'Push failed.';
            _repoUrl = null;
          }
        });
      } else {
        // GitLab push is not implemented yet.
        if (!mounted) return;

        setState(() {
          _statusMessage = 'GitLab push coming soon — repo creation works!';
          _repoUrl = null;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _statusMessage = 'Unexpected error: $e';
        _repoUrl = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline),
            title: Text(widget.username),
            subtitle: Text(
                widget.provider == GitProvider.github ? 'GitHub' : 'GitLab'),
            trailing: TextButton(
              onPressed: widget.onDisconnect,
              child: const Text('Disconnect'),
            ),
          ),
          const Divider(),
          const SizedBox(height: AppConstants.spaceSm),
          Text('Push "${widget.fileName}"',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppConstants.spaceMd),
          TextField(
            controller: _repoController,
            decoration: const InputDecoration(
              labelText: 'Repository name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppConstants.spaceSm),
          TextField(
            controller: _commitController,
            decoration: const InputDecoration(
              labelText: 'Commit message',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppConstants.spaceSm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Private repository'),
            value: _isPrivate,
            onChanged: (v) => setState(() => _isPrivate = v),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : FilledButton.icon(
                  onPressed: _createAndPush,
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text('Create repo & push'),
                ),
          if (_statusMessage != null) ...[
            const SizedBox(height: AppConstants.spaceMd),
            Container(
              padding: const EdgeInsets.all(AppConstants.spaceSm),
              decoration: BoxDecoration(
                color: _repoUrl != null
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusMessage!,
                style: TextStyle(
                  color: _repoUrl != null
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
