import 'package:devbox/tools/all_snippets.dart';
import 'package:devbox/globals.dart';
import 'package:devbox/project.dart';
import 'package:devbox/tools_pages.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Directory contentFolder = Directory(
    'C:/Users/Utilizador/Desktop/devbox_content',
  );
  List<Directory> projectFolders = [];
  final List<_ShortcutItem> shortcuts = [];
  int? _draggingShortcutIndex;
  ImageCache? logoCache;


  TextEditingController projectNameController = TextEditingController();
  bool projectAlreadyExists = false;

  File get _shortcutsFile =>
      File('${contentFolder.path}${Platform.pathSeparator}shortcuts.json');

  Future<void> _setupTechWorkspace(
    String filesPath,
    String techKey,
    String projectName,
  ) async {
    switch (techKey) {
      case 'flutter':
        final flutterPackageName = projectName
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
            .replaceAll(RegExp(r'_+'), '_')
            .replaceAll(RegExp(r'^_+|_+$'), '');
        await Process.run(
          'flutter',
          ['create', '--project-name', flutterPackageName, '.'],
          workingDirectory: filesPath,
          runInShell: true,
        );
        break;
      case 'nodejs':
        await Process.run(
          'npm',
          ['init', '-y'],
          workingDirectory: filesPath,
          runInShell: true,
        );
        break;
      case 'python':
        await Process.run(
          'python',
          ['-m', 'venv', 'venv'],
          workingDirectory: filesPath,
          runInShell: true,
        );
        File('$filesPath/main.py').writeAsStringSync(
          '# $projectName\n\ndef main():\n    pass\n\nif __name__ == "__main__":\n    main()\n',
        );
        File('$filesPath/requirements.txt').writeAsStringSync('');
        break;
      case 'react':
        await Process.run(
          'npx',
          ['--yes', 'create-vite@latest', '.', '--template', 'react'],
          workingDirectory: filesPath,
          runInShell: true,
        );
        break;
      case 'html':
        final slug = projectName;
        File('$filesPath/index.html').writeAsStringSync(
          '<!DOCTYPE html>\n<html lang="en">\n<head>\n  <meta charset="UTF-8">\n  <meta name="viewport" content="width=device-width, initial-scale=1.0">\n  <title>$slug</title>\n  <link rel="stylesheet" href="style.css">\n</head>\n<body>\n  <h1>$slug</h1>\n  <script src="script.js"></script>\n</body>\n</html>\n',
        );
        File('$filesPath/style.css').writeAsStringSync(
          '/* Styles for $slug */\n\nbody {\n  font-family: sans-serif;\n  margin: 0;\n  padding: 20px;\n}\n',
        );
        File('$filesPath/script.js').writeAsStringSync(
          '// $slug\n\ndocument.addEventListener("DOMContentLoaded", function () {\n  console.log("$slug loaded");\n});\n',
        );
        break;
      case 'dotnet':
        await Process.run(
          'dotnet',
          ['new', 'console', '--force'],
          workingDirectory: filesPath,
          runInShell: true,
        );
        break;
      case 'rust':
        await Process.run(
          'cargo',
          ['init'],
          workingDirectory: filesPath,
          runInShell: true,
        );
        break;
      case 'go':
        final modName = projectName.toLowerCase().replaceAll(' ', '-');
        await Process.run(
          'go',
          ['mod', 'init', modName],
          workingDirectory: filesPath,
          runInShell: true,
        );
        File('$filesPath/main.go').writeAsStringSync(
          'package main\n\nimport "fmt"\n\nfunc main() {\n\tfmt.Println("Hello, $projectName!")\n}\n',
        );
        break;
      default:
        break;
    }
  }

  void loadProjects() {
    if (contentFolder.existsSync()) {
      setState(() {
        projectFolders = contentFolder
            .listSync()
            .whereType<Directory>()
            .toList();
      });
    }
  }

  void _loadShortcuts() {
    try {
      if (!_shortcutsFile.existsSync()) {
        setState(() {
          shortcuts
            ..clear()
            ..add(
              const _ShortcutItem(name: 'Github', url: 'https://github.com'),
            );
        });
        _saveShortcuts();
        return;
      }

      final content = _shortcutsFile.readAsStringSync();
      if (content.trim().isEmpty) {
        setState(() {
          shortcuts.clear();
        });
        return;
      }

      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        return;
      }

      final list = decoded['shortcuts'];
      if (list is! List) {
        return;
      }

      final loaded = <_ShortcutItem>[];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final name = (item['name'] ?? '').toString().trim();
          final url = (item['url'] ?? '').toString().trim();
          if (name.isNotEmpty && url.isNotEmpty) {
            loaded.add(_ShortcutItem(name: name, url: url));
          }
        } else if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final name = (map['name'] ?? '').toString().trim();
          final url = (map['url'] ?? '').toString().trim();
          if (name.isNotEmpty && url.isNotEmpty) {
            loaded.add(_ShortcutItem(name: name, url: url));
          }
        }
      }

      setState(() {
        shortcuts
          ..clear()
          ..addAll(loaded);
      });
    } on FormatException {
      // ignore malformed shortcuts file
    } on FileSystemException {
      // ignore shortcuts read errors
    }
  }

  void _saveShortcuts() {
    try {
      final parent = _shortcutsFile.parent;
      if (!parent.existsSync()) {
        parent.createSync(recursive: true);
      }
      final payload = {
        'shortcuts': shortcuts
            .map((item) => {'name': item.name, 'url': item.url})
            .toList(),
      };
      _shortcutsFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(payload),
      );
    } on FileSystemException {
      // ignore shortcuts write errors
    }
  }

  Future<void> _showAddShortcutDialog() async {
    final created = await _showShortcutDialog();

    if (created == null) {
      return;
    }

    setState(() {
      shortcuts.add(created);
    });
    _saveShortcuts();
  }

  Future<_ShortcutItem?> _showShortcutDialog({_ShortcutItem? initial}) async {
    final nameController = TextEditingController(text: initial?.name ?? '');
    final urlController = TextEditingController(text: initial?.url ?? '');
    String? nameError;
    String? urlError;

    return showDialog<_ShortcutItem>(
      context: context,
      builder: (dialogContext) {
        void submit() {
          final name = nameController.text.trim();
          var url = urlController.text.trim();

          nameError = null;
          urlError = null;

          if (name.isEmpty) {
            nameError = 'Name is required.';
          }
          if (url.isEmpty) {
            urlError = 'URL is required.';
          }

          if (url.isNotEmpty && !url.contains('://')) {
            url = 'https://$url';
          }

          final uri = Uri.tryParse(url);
          if (urlError == null &&
              (uri == null || uri.host.isEmpty || !uri.hasScheme)) {
            urlError = 'Enter a valid URL.';
          }

          if (nameError != null || urlError != null) {
            (dialogContext as Element).markNeedsBuild();
            return;
          }

          Navigator.of(dialogContext).pop(_ShortcutItem(name: name, url: url));
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: Text(initial == null ? 'Add Shortcut' : 'Edit Shortcut'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Github',
                    errorText: nameError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submit(),
                  decoration: InputDecoration(
                    labelText: 'URL',
                    hintText: 'https://example.com',
                    errorText: urlError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: submit,
              child: Text(initial == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editShortcut(int index) async {
    if (index < 0 || index >= shortcuts.length) {
      return;
    }

    final edited = await _showShortcutDialog(initial: shortcuts[index]);
    if (edited == null) {
      return;
    }

    setState(() {
      shortcuts[index] = edited;
    });
    _saveShortcuts();
  }

  Future<void> _deleteShortcut(int index) async {
    if (index < 0 || index >= shortcuts.length) {
      return;
    }

    final item = shortcuts[index];
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: const Text('Delete shortcut'),
        content: Text('Delete "${item.name}" shortcut?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      shortcuts.removeAt(index);
    });
    _saveShortcuts();
  }

  Future<void> _showShortcutContextMenu(
    TapDownDetails details,
    int index,
  ) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: const [
        PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
        PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
      ],
    );

    if (selected == 'edit') {
      await _editShortcut(index);
      return;
    }
    if (selected == 'delete') {
      await _deleteShortcut(index);
    }
  }

  void _moveShortcut(int fromIndex, int toIndex) {
    if (fromIndex == toIndex ||
        fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= shortcuts.length ||
        toIndex >= shortcuts.length) {
      return;
    }

    setState(() {
      final item = shortcuts.removeAt(fromIndex);
      shortcuts.insert(toIndex, item);
    });
    _saveShortcuts();
  }

  Widget _buildDraggableShortcutTile(int index) {
    final shortcut = shortcuts[index];
    final tile = GestureDetector(
      onSecondaryTapDown: (details) {
        _showShortcutContextMenu(details, index);
      },
      child: _HomeActionBlock(
        icon: Icons.link,
        label: shortcut.name,
        onTap: () => _openShortcutUrl(shortcut.url),
      ),
    );

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != index,
      onAcceptWithDetails: (details) {
        _moveShortcut(details.data, index);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHovering ? Colors.blueGrey : Colors.transparent,
              width: 2,
            ),
          ),
          child: Draggable<int>(
            data: index,
            maxSimultaneousDrags: 1,
            onDragStarted: () {
              setState(() {
                _draggingShortcutIndex = index;
              });
            },
            onDragEnd: (_) {
              if (!mounted) {
                return;
              }
              setState(() {
                _draggingShortcutIndex = null;
              });
            },
            feedback: Material(
              color: Colors.transparent,
              child: Opacity(
                opacity: 0.9,
                child: SizedBox(width: 145, height: 145, child: tile),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: tile),
            child: _draggingShortcutIndex == index
                ? Opacity(opacity: 0.35, child: tile)
                : tile,
          ),
        );
      },
    );
  }

  Future<void> _openShortcutUrl(String url) async {
    var target = url.trim();
    if (target.isEmpty) {
      return;
    }
    if (!target.contains('://')) {
      target = 'https://$target';
    }

    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', target]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [target]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [target]);
      }
    } on ProcessException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open shortcut URL.')),
      );
    }
  }

  Future<bool> _checkCommandAvailable(String command) async {
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        [command],
        runInShell: true,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  String _getRequiredCommand(String techKey) {
    switch (techKey) {
      case 'flutter':
        return 'flutter';
      case 'nodejs':
        return 'npm';
      case 'react':
        return 'npx';
      case 'python':
        return 'python';
      case 'dotnet':
        return 'dotnet';
      case 'rust':
        return 'cargo';
      case 'go':
        return 'go';
      default:
        return '';
    }
  }

  String? _getInstallUrl(String techKey) {
    switch (techKey) {
      case 'flutter':
        return 'https://flutter.dev/docs/get-started/install';
      case 'nodejs':
        return 'https://nodejs.org/';
      case 'react':
        return 'https://nodejs.org/';
      case 'python':
        return 'https://www.python.org/downloads/';
      case 'dotnet':
        return 'https://dotnet.microsoft.com/download';
      case 'rust':
        return 'https://rustup.rs/';
      case 'go':
        return 'https://go.dev/dl/';
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    loadProjects();
    _loadShortcuts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 200,
            color: Colors.blueGrey[900],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Projects',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add),
                        color: Colors.white,
                        onPressed: () {
                          projectAlreadyExists = false;
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (dialogContext) {
                              projectNameController.clear();
                              int step = 0;
                              int? selectedTechIndex;
                              bool openInVsCode = false;
                              bool isCreating = false;

                              return StatefulBuilder(
                                builder: (ctx, setDialogState) {
                                  Future<void> tryCreate() async {
                                    if (projectNameController.text
                                        .trim()
                                        .isEmpty) return;
                                    final typedName =
                                        projectNameController.text.trim();
                                    bool duplicateExists = false;
                                    try {
                                      duplicateExists = contentFolder
                                          .listSync()
                                          .whereType<Directory>()
                                          .any((folder) {
                                            final name = folder.path
                                                .split(RegExp(r'[/\\]'))
                                                .where((s) => s.isNotEmpty)
                                                .last;
                                            return name.toLowerCase() ==
                                                typedName.toLowerCase();
                                          });
                                    } on FileSystemException {}
                                    if (duplicateExists) {
                                      setState(() {
                                        projectAlreadyExists = true;
                                      });
                                      setDialogState(() => step = 0);
                                      return;
                                    }

                                    // Check if required tool is installed
                                    bool doTechSetup =
                                        selectedTechIndex != null;
                                    if (selectedTechIndex != null) {
                                      final techKey =
                                          _kTechOptions[selectedTechIndex!].key;
                                      final requiredCmd =
                                          _getRequiredCommand(techKey);
                                      if (requiredCmd.isNotEmpty) {
                                        final available =
                                            await _checkCommandAvailable(
                                              requiredCmd,
                                            );
                                        if (!available) {
                                          final techLabel =
                                              _kTechOptions[selectedTechIndex!]
                                                  .label;
                                          final installUrl =
                                              _getInstallUrl(techKey);
                                          final action =
                                              await showDialog<String>(
                                                context: ctx,
                                                builder:
                                                    (innerCtx) => AlertDialog(
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              5,
                                                            ),
                                                      ),
                                                      title: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.warning_amber,
                                                            color: Colors
                                                                .orange[700],
                                                          ),
                                                          const SizedBox(
                                                            width: 10,
                                                          ),
                                                          Expanded(
                                                            child: Text(
                                                              '$techLabel not found',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      content: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            '"$requiredCmd" is not installed or not in your PATH.',
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            height: 10,
                                                          ),
                                                          Text(
                                                            'Without it the project workspace cannot be scaffolded. '
                                                            'You can install $techLabel and try again, or create an empty project and set it up later.',
                                                          ),
                                                          if (installUrl !=
                                                              null) ...[
                                                            const SizedBox(
                                                              height: 14,
                                                            ),
                                                            Text(
                                                              'Install page: $installUrl',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .blueGrey[600],
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                innerCtx,
                                                              ).pop('cancel'),
                                                          child: const Text(
                                                            'Cancel',
                                                          ),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                innerCtx,
                                                              ).pop('skip'),
                                                          child: const Text(
                                                            'Create Without Scaffold',
                                                          ),
                                                        ),
                                                        if (installUrl !=
                                                            null)
                                                          ElevatedButton.icon(
                                                            icon: const Icon(
                                                              Icons.open_in_browser,
                                                              size: 16,
                                                            ),
                                                            label: Text(
                                                              'Install $techLabel',
                                                            ),
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                  innerCtx,
                                                                ).pop('install'),
                                                          ),
                                                      ],
                                                    ),
                                              );
                                          if (action == null ||
                                              action == 'cancel') {
                                            return;
                                          }
                                          if (action == 'install') {
                                            await _openShortcutUrl(installUrl!);
                                            return;
                                          }
                                          // 'skip' — create project without scaffold
                                          doTechSetup = false;
                                        }
                                      }
                                    }

                                    setDialogState(() => isCreating = true);
                                    final newProjectDir = Directory(
                                      '${contentFolder.path}/$typedName',
                                    );
                                    newProjectDir.createSync();
                                    Directory(
                                      '${newProjectDir.path}/Files',
                                    ).createSync();
                                    Directory(
                                      '${newProjectDir.path}/MindMaps',
                                    ).createSync();
                                    Directory(
                                      '${newProjectDir.path}/Database',
                                    ).createSync();
                                    Directory(
                                      '${newProjectDir.path}/Collaborators',
                                    ).createSync();
                                    Directory(
                                      '${newProjectDir.path}/Snippets',
                                    ).createSync();
                                    File(
                                      '${newProjectDir.path}/README.md',
                                    ).writeAsStringSync(
                                      '# $typedName\n\nProject description goes here.',
                                    );
                                    File(
                                      '${newProjectDir.path}/.gitignore',
                                    ).writeAsStringSync(
                                      'bin/\nbuild/\n.idea/\n.vscode/\n*.iml\n',
                                    );
                                    File(
                                      '${newProjectDir.path}/Collaborators/collaborators.json',
                                    ).writeAsStringSync(
                                      '{\n  "collaborators": [{"name":"me", "email":"me@example.com"}]\n}\n',
                                    );
                                    final filesPath =
                                        '${newProjectDir.path}/Files';
                                    if (doTechSetup &&
                                        selectedTechIndex != null) {
                                      final techKey =
                                          _kTechOptions[selectedTechIndex!].key;
                                      try {
                                        await _setupTechWorkspace(
                                          filesPath,
                                          techKey,
                                          typedName,
                                        );
                                      } catch (_) {}
                                    }
                                    if (openInVsCode) {
                                      try {
                                        await Process.run(
                                          'code',
                                          [filesPath],
                                          runInShell: true,
                                        );
                                      } catch (_) {}
                                    }
                                    setState(() {
                                      projectFolders.add(newProjectDir);
                                    });
                                    loadProjects();
                                    if (dialogContext.mounted) {
                                      Navigator.of(dialogContext).pop();
                                    }
                                  }

                                  // ── Step 0: project name ──
                                  if (step == 0) {
                                    return AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      title: Text('Create New Project'),
                                      content: SizedBox(
                                        width: 320,
                                        child: TextField(
                                          controller: projectNameController,
                                          autofocus: true,
                                          decoration: InputDecoration(
                                            hintText: 'Project Name',
                                            errorText: projectAlreadyExists
                                                ? 'A project with this name already exists.'
                                                : null,
                                          ),
                                          onSubmitted: (_) {
                                            if (projectNameController.text
                                                .trim()
                                                .isNotEmpty) {
                                              setState(() {
                                                projectAlreadyExists = false;
                                              });
                                              setDialogState(() => step = 1);
                                            }
                                          },
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(dialogContext).pop(),
                                          child: Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            if (projectNameController.text
                                                .trim()
                                                .isNotEmpty) {
                                              setState(() {
                                                projectAlreadyExists = false;
                                              });
                                              setDialogState(() => step = 1);
                                            }
                                          },
                                          child: Text('Next'),
                                        ),
                                      ],
                                    );
                                  }

                                  // ── Step 1: tech selection ──
                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    title: Text('What are you building?'),
                                    content: SizedBox(
                                      width: 420,
                                      child: isCreating
                                          ? SizedBox(
                                              height: 80,
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            )
                                          : Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: List.generate(
                                                    _kTechOptions.length,
                                                    (i) {
                                                      final opt =
                                                          _kTechOptions[i];
                                                      final selected =
                                                          selectedTechIndex ==
                                                          i;
                                                      return ChoiceChip(
                                                        avatar: Icon(
                                                          opt.icon,
                                                          size: 16,
                                                          color: selected
                                                              ? Colors.white
                                                              : null,
                                                        ),
                                                        label: Text(opt.label),
                                                        selected: selected,
                                                        onSelected: (_) =>
                                                            setDialogState(
                                                              () =>
                                                                  selectedTechIndex =
                                                                      selected
                                                                      ? null
                                                                      : i,
                                                            ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                                SizedBox(height: 12),
                                                CheckboxListTile(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  title: Text(
                                                    'Open Files folder in VS Code',
                                                  ),
                                                  value: openInVsCode,
                                                  onChanged: (v) =>
                                                      setDialogState(
                                                        () => openInVsCode =
                                                            v ?? false,
                                                      ),
                                                ),
                                              ],
                                            ),
                                    ),
                                    actions: isCreating
                                        ? []
                                        : [
                                            TextButton(
                                              onPressed: () =>
                                                  setDialogState(() => step = 0),
                                              child: Text('Back'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                await tryCreate();
                                              },
                                              child: Text('Create'),
                                            ),
                                          ],
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (projectFolders.isEmpty)
                  Center(
                    child: Text(
                      'No projects yet.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: projectFolders.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 4.0,
                          ),
                          child: Material(
                            color: Colors.blueGrey[800],
                            elevation: 2,
                            borderRadius: BorderRadius.circular(5),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(5),
                              hoverColor: Colors.blueGrey[700],
                              splashColor: const Color.fromARGB(
                                255,
                                148,
                                160,
                                180,
                              ).withOpacity(0.3),
                              onTap: () {
                                Globals().projectTab.value = 0;
                                Navigator.of(context)
                                    .push<bool>(
                                      MaterialPageRoute(
                                        builder: (context) => Project(
                                          projectFolder: projectFolders[index],
                                          projectName: projectFolders[index]
                                              .path
                                              .split(Platform.pathSeparator)
                                              .last,
                                        ),
                                      ),
                                    )
                                    .then((wasChanged) {
                                      if (wasChanged == true && mounted) {
                                        loadProjects();
                                      }
                                    });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.folder, color: Colors.white70),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        projectFolders[index].path
                                            .split('\\')
                                            .last,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: Container(
              color: Colors.blueGrey[50],
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 48,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.blueGrey[100],
                        ),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Image(
                                image: AssetImage('assets/devbox_logo.png'),
                                width: 50,
                                height: 50,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'DevBox',
                              style: TextStyle(
                                color: Colors.blueGrey[900],
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Spacer(),
                            IconButton(
                              icon: Icon(Icons.settings),
                              color: Colors.blueGrey[700],
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const HomeSettingsPage(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 18),
                      Text(
                        'Shortcuts',
                        style: TextStyle(
                          color: Colors.blueGrey[900],
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.start,
                        spacing: 18.5,
                        runSpacing: 16,
                        children: [
                          ...List<Widget>.generate(
                            shortcuts.length,
                            (index) => _buildDraggableShortcutTile(index),
                          ),
                          _HomeActionBlock(
                            icon: Icons.add,
                            label: 'Add Shortcut',
                            onTap: _showAddShortcutDialog,
                          ),
                        ],
                      ),
                      SizedBox(height: 18),
                      Text(
                        'Tools',
                        style: TextStyle(
                          color: Colors.blueGrey[900],
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.start,
                        spacing: 18.5,
                        runSpacing: 16,
                        children: [
                          _HomeActionBlock(
                            icon: Icons.code,
                            label: 'Snippets',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => AllSnippetsPage(
                                    contentFolder: contentFolder,
                                  ),
                                ),
                              );
                            },
                          ),
                          _HomeActionBlock(
                            icon: Icons.transform,
                            label: 'Data Transformer',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const DataTransformerPage(),
                                ),
                              );
                            },
                          ),
                          _HomeActionBlock(
                            icon: Icons.construction_rounded,
                            label: 'API Builder',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const ApiBuilderPage(),
                                ),
                              );
                            },
                          ),
                          _HomeActionBlock(
                            icon: Icons.storage,
                            label: 'Database Builder',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const DatabaseBuilderPage(),
                                ),
                              );
                            },
                          ),
                          _HomeActionBlock(
                            icon: Icons.image_aspect_ratio,
                            label: 'Animation to Spreadsheet',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const AnimationToSpreadsheetPage(),
                                ),
                              );
                            },
                          ),
                          _HomeActionBlock(
                            icon: Icons.password,
                            label: 'Code Obfuscator',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CodeObfuscatorPage(),
                                ),
                              );
                            },
                          ),
                          _HomeActionBlock(
                            icon: Icons.lock,
                            label: 'Password Manager',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const PasswordManagerPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeActionBlock extends StatelessWidget {
  const _HomeActionBlock({
    this.icon,
    this.symbol,
    required this.label,
    required this.onTap,
  }) : assert(icon != null || symbol != null, 'Provide either icon or symbol.');

  final IconData? icon;
  final String? symbol;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 145,
      height: 145,
      child: Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                symbol != null
                    ? Text(
                        symbol!,
                        style: TextStyle(
                          fontSize: 40,
                          color: Colors.blueGrey[800],
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : Icon(icon, size: 32, color: Colors.blueGrey[800]),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.blueGrey[900],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutItem {
  const _ShortcutItem({required this.name, required this.url});

  final String name;
  final String url;
}

class _TechOption {
  const _TechOption(this.label, this.icon, this.key);
  final String label;
  final IconData icon;
  final String key;
}

const List<_TechOption> _kTechOptions = [
  _TechOption('Flutter', Icons.phone_android, 'flutter'),
  _TechOption('Node.js', Icons.javascript, 'nodejs'),
  _TechOption('Python', Icons.code, 'python'),
  _TechOption('React', Icons.web, 'react'),
  _TechOption('HTML/CSS/JS', Icons.html, 'html'),
  _TechOption('.NET / C#', Icons.computer, 'dotnet'),
  _TechOption('Rust', Icons.build, 'rust'),
  _TechOption('Go', Icons.language, 'go'),
  _TechOption('None / Empty', Icons.folder_open, 'none'),
];
