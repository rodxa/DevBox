import 'dart:io';

class _VsCodeCommandAttempt {
  const _VsCodeCommandAttempt(
    this.command, {
    this.argsPrefix = const <String>[],
    this.runInShell = false,
  });

  final String command;
  final List<String> argsPrefix;
  final bool runInShell;
}

Future<bool> openFolderInVsCode(String folderPath) async {
  final target = folderPath.trim();
  if (target.isEmpty) {
    return false;
  }

  for (final attempt in _buildVsCodeCommandAttempts()) {
    try {
      final result = await Process.run(attempt.command, [
        ...attempt.argsPrefix,
        target,
      ], runInShell: attempt.runInShell);
      if (result.exitCode == 0) {
        return true;
      }
    } on ProcessException {
      // Try the next command candidate.
    } catch (_) {
      // Ignore and continue trying fallback commands.
    }
  }

  return false;
}

List<_VsCodeCommandAttempt> _buildVsCodeCommandAttempts() {
  if (Platform.isWindows) {
    final env = Platform.environment;
    final commands = <String>[
      'code',
      'code.cmd',
      'code-insiders',
      'code-insiders.cmd',
    ];

    void addFromEnv(String? basePath, String suffix) {
      if (basePath == null || basePath.isEmpty) {
        return;
      }
      commands.add('$basePath\\$suffix');
    }

    addFromEnv(env['LOCALAPPDATA'], r'Programs\Microsoft VS Code\bin\code.cmd');
    addFromEnv(env['PROGRAMFILES'], r'Microsoft VS Code\bin\code.cmd');
    addFromEnv(env['PROGRAMFILES(X86)'], r'Microsoft VS Code\bin\code.cmd');

    return [
      ...commands.map(
        (command) => _VsCodeCommandAttempt(command, runInShell: true),
      ),
      const _VsCodeCommandAttempt(
        'cmd',
        argsPrefix: <String>['/c', 'start', '', 'code'],
        runInShell: true,
      ),
    ];
  }

  if (Platform.isMacOS) {
    return const [
      _VsCodeCommandAttempt('code'),
      _VsCodeCommandAttempt('code-insiders'),
      _VsCodeCommandAttempt(
        'open',
        argsPrefix: <String>['-a', 'Visual Studio Code'],
      ),
    ];
  }

  if (Platform.isLinux) {
    return const [
      _VsCodeCommandAttempt('code'),
      _VsCodeCommandAttempt('code-insiders'),
    ];
  }

  return const [];
}
