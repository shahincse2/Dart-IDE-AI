import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

enum GitProvider { github, gitlab }

/// Result returned by Git operations.
///
/// Contains:
/// - success: whether the operation succeeded
/// - message: human-readable success/error message
/// - statusCode: HTTP status returned by the Git provider
class GitOperationResult {
  final bool success;
  final String? message;
  final int? statusCode;

  const GitOperationResult({
    required this.success,
    this.message,
    this.statusCode,
  });
}

class GitRepo {
  final String name;
  final String fullName;
  final String htmlUrl;
  final String cloneUrl;
  final bool isPrivate;

  const GitRepo({
    required this.name,
    required this.fullName,
    required this.htmlUrl,
    required this.cloneUrl,
    required this.isPrivate,
  });

  factory GitRepo.fromGitHubJson(Map<String, dynamic> json) => GitRepo(
        name: json['name'] as String,
        fullName: json['full_name'] as String,
        htmlUrl: json['html_url'] as String,
        cloneUrl: json['clone_url'] as String,
        isPrivate: json['private'] as bool,
      );

  factory GitRepo.fromGitLabJson(Map<String, dynamic> json) => GitRepo(
        name: json['name'] as String,
        fullName: json['path_with_namespace'] as String,
        htmlUrl: json['web_url'] as String,
        cloneUrl: json['http_url_to_repo'] as String,
        isPrivate: json['visibility'] == 'private',
      );
}

/// Handles GitHub/GitLab authentication and API calls.
/// Tokens are stored in secure storage — never in plain prefs.
class GitService {
  static const _githubTokenKey = 'dartlab.github_token';
  static const _gitlabTokenKey = 'dartlab.gitlab_token';
  static const _gitlabUrlKey = 'dartlab.gitlab_url';

  final FlutterSecureStorage _storage;

  GitService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  // =========================================================
  // Token management
  // =========================================================

  Future<void> saveToken(
    GitProvider provider,
    String token, {
    String? gitlabUrl,
  }) async {
    if (provider == GitProvider.github) {
      await _storage.write(
        key: _githubTokenKey,
        value: token,
      );
    } else {
      await _storage.write(
        key: _gitlabTokenKey,
        value: token,
      );

      if (gitlabUrl != null) {
        await _storage.write(
          key: _gitlabUrlKey,
          value: gitlabUrl,
        );
      }
    }
  }

  Future<String?> getToken(GitProvider provider) async {
    return provider == GitProvider.github
        ? await _storage.read(key: _githubTokenKey)
        : await _storage.read(key: _gitlabTokenKey);
  }

  Future<void> clearToken(GitProvider provider) async {
    if (provider == GitProvider.github) {
      await _storage.delete(key: _githubTokenKey);
    } else {
      await _storage.delete(key: _gitlabTokenKey);
      await _storage.delete(key: _gitlabUrlKey);
    }
  }

  Future<bool> isAuthenticated(GitProvider provider) async {
    final token = await getToken(provider);
    return token != null && token.isNotEmpty;
  }

  // =========================================================
  // GitHub
  // =========================================================

  Future<String?> getGitHubUsername(String token) async {
    final res = await http.get(
      Uri.parse('https://api.github.com/user'),
      headers: _githubHeaders(token),
    );

    if (res.statusCode != 200) {
      return null;
    }

    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['login'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<GitRepo?> createGitHubRepo(
    String token, {
    required String name,
    required bool isPrivate,
    String description = '',
  }) async {
    final res = await http.post(
      Uri.parse('https://api.github.com/user/repos'),
      headers: _githubHeaders(token),
      body: jsonEncode({
        'name': name,
        'description': description,
        'private': isPrivate,
        'auto_init': true,
      }),
    );

    if (res.statusCode != 201) {
      return null;
    }

    try {
      return GitRepo.fromGitHubJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Creates or updates a file in a GitHub repository.
  ///
  /// Returns detailed information about the operation instead of
  /// returning only true/false.
  Future<GitOperationResult> pushFileToGitHub(
    String token, {
    required String owner,
    required String repo,
    required String path,
    required String content,
    required String commitMessage,
  }) async {
    final fileUrl = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/contents/$path',
    );

    // ---------------------------------------------------------
    // 1. Check whether the file already exists.
    // ---------------------------------------------------------

    String? sha;

    final getRes = await http.get(
      fileUrl,
      headers: _githubHeaders(token),
    );

    if (getRes.statusCode == 200) {
      try {
        final data = jsonDecode(getRes.body) as Map<String, dynamic>;
        sha = data['sha'] as String?;
      } catch (_) {
        return GitOperationResult(
          success: false,
          statusCode: getRes.statusCode,
          message: 'GitHub returned an invalid file response.',
        );
      }
    } else if (getRes.statusCode == 404) {
      // File does not exist.
      // This is normal when creating a new file.
      sha = null;
    } else {
      // IMPORTANT:
      // Do not treat 401/403/500 etc. as "file does not exist".
      return GitOperationResult(
        success: false,
        statusCode: getRes.statusCode,
        message: _githubErrorMessage(
          getRes,
          fallback: 'Unable to check the file on GitHub.',
        ),
      );
    }

    // ---------------------------------------------------------
    // 2. Prepare GitHub Contents API request.
    // ---------------------------------------------------------

    final body = <String, dynamic>{
      'message': commitMessage,
      'content': base64Encode(
        utf8.encode(content),
      ),
    };

    // GitHub requires SHA when updating an existing file.
    if (sha != null) {
      body['sha'] = sha;
    }

    // ---------------------------------------------------------
    // 3. Create or update the file.
    // ---------------------------------------------------------

    final res = await http.put(
      fileUrl,
      headers: _githubHeaders(token),
      body: jsonEncode(body),
    );

    // GitHub:
    // 201 = created
    // 200 = updated
    if (res.statusCode == 200 || res.statusCode == 201) {
      return GitOperationResult(
        success: true,
        statusCode: res.statusCode,
        message: sha == null
            ? 'File created successfully on GitHub.'
            : 'File updated successfully on GitHub.',
      );
    }

    // ---------------------------------------------------------
    // 4. Return actual GitHub error.
    // ---------------------------------------------------------

    return GitOperationResult(
      success: false,
      statusCode: res.statusCode,
      message: _githubErrorMessage(
        res,
        fallback: 'GitHub rejected the file push.',
      ),
    );
  }

  Future<List<GitRepo>> listGitHubRepos(String token) async {
    final res = await http.get(
      Uri.parse(
        'https://api.github.com/user/repos?sort=updated&per_page=30',
      ),
      headers: _githubHeaders(token),
    );

    if (res.statusCode != 200) {
      return const [];
    }

    try {
      final list = jsonDecode(res.body) as List<dynamic>;

      return list
          .map(
            (e) => GitRepo.fromGitHubJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Map<String, String> _githubHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'Content-Type': 'application/json',
      };

  /// Converts GitHub's response into a useful human-readable message.
  String _githubErrorMessage(
    http.Response response, {
    required String fallback,
  }) {
    String? githubMessage;
    String? documentationUrl;

    try {
      final data = jsonDecode(response.body);

      if (data is Map<String, dynamic>) {
        githubMessage = data['message'] as String?;

        documentationUrl = data['documentation_url'] as String?;

        final errors = data['errors'];

        if (githubMessage != null && errors is List && errors.isNotEmpty) {
          final errorDetails = errors.map((e) {
            if (e is Map<String, dynamic>) {
              final message = e['message'];
              final code = e['code'];

              if (message != null && code != null) {
                return '$message ($code)';
              }

              if (message != null) {
                return message.toString();
              }
            }

            return e.toString();
          }).join(', ');

          if (errorDetails.isNotEmpty) {
            githubMessage = '$githubMessage: $errorDetails';
          }
        }
      }
    } catch (_) {
      // Ignore JSON parsing errors and use fallback.
    }

    final message = githubMessage ?? fallback;

    switch (response.statusCode) {
      case 401:
        return 'GitHub authentication failed (401): $message';

      case 403:
        return 'GitHub permission denied (403): $message';

      case 404:
        return 'GitHub resource not found (404): $message';

      case 409:
        return 'GitHub conflict (409): $message';

      case 422:
        return 'GitHub validation failed (422): $message';

      case 429:
        return 'GitHub rate limit exceeded (429): $message';

      default:
        if (documentationUrl != null && documentationUrl.trim().isNotEmpty) {
          return '$message\nDocumentation: $documentationUrl';
        }

        return 'GitHub error (${response.statusCode}): $message';
    }
  }

  // =========================================================
  // GitLab
  // =========================================================

  Future<String?> getGitLabUsername(
    String token,
    String baseUrl,
  ) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/v4/user'),
      headers: _gitlabHeaders(token),
    );

    if (res.statusCode != 200) {
      return null;
    }

    try {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['username'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<GitRepo?> createGitLabRepo(
    String token,
    String baseUrl, {
    required String name,
    required bool isPrivate,
    String description = '',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v4/projects'),
      headers: _gitlabHeaders(token),
      body: jsonEncode({
        'name': name,
        'description': description,
        'visibility': isPrivate ? 'private' : 'public',
        'initialize_with_readme': true,
      }),
    );

    if (res.statusCode != 201) {
      return null;
    }

    try {
      return GitRepo.fromGitLabJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> pushFileToGitLab(
    String token,
    String baseUrl, {
    required int projectId,
    required String filePath,
    required String content,
    required String commitMessage,
    String branch = 'main',
  }) async {
    final encodedPath = Uri.encodeComponent(filePath);

    // Check if file exists.
    final getRes = await http.get(
      Uri.parse(
        '$baseUrl/api/v4/projects/$projectId/repository/files/'
        '$encodedPath?ref=$branch',
      ),
      headers: _gitlabHeaders(token),
    );

    final body = jsonEncode({
      'branch': branch,
      'content': content,
      'commit_message': commitMessage,
    });

    final http.Response res;

    if (getRes.statusCode == 200) {
      // Update existing file.
      res = await http.put(
        Uri.parse(
          '$baseUrl/api/v4/projects/$projectId/repository/files/'
          '$encodedPath',
        ),
        headers: _gitlabHeaders(token),
        body: body,
      );
    } else {
      // Create new file.
      res = await http.post(
        Uri.parse(
          '$baseUrl/api/v4/projects/$projectId/repository/files/'
          '$encodedPath',
        ),
        headers: _gitlabHeaders(token),
        body: body,
      );
    }

    return res.statusCode == 200 || res.statusCode == 201;
  }

  Map<String, String> _gitlabHeaders(String token) => {
        'PRIVATE-TOKEN': token,
        'Content-Type': 'application/json',
      };
}
