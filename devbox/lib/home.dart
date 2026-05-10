import 'package:devbox/globals.dart';
import 'package:devbox/project.dart';
import 'package:devbox/tools/all_snippets.dart';
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
                            builder: (dialogContext) {
                              projectNameController.clear();
                              Future<void> tryCreate() async {
                                if (projectNameController.text.trim().isEmpty)
                                  return;
                                final typedName = projectNameController.text
                                    .trim();
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
                                } on FileSystemException {
                                  // If listing fails, allow creation to proceed.
                                }
                                if (duplicateExists) {
                                  (dialogContext as Element).markNeedsBuild();
                                  setState(() {
                                    projectAlreadyExists = true;
                                  });
                                  return;
                                }
                                setState(() {
                                  Directory newProjectDir = Directory(
                                    '${contentFolder.path}/${projectNameController.text}',
                                  );
                                  newProjectDir.createSync();
                                  projectFolders.add(newProjectDir);

                                  //add default folders to project
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

                                  //add default files to project
                                  File(
                                    '${newProjectDir.path}/README.md',
                                  ).writeAsStringSync(
                                    '# ${projectNameController.text}\n\nProject description goes here.',
                                  );
                                  File(
                                    '${newProjectDir.path}/.gitignore',
                                  ).writeAsStringSync(
                                    'bin/\nbuild/\n.idea/\n.vscode/\n*.iml\n',
                                  );
                                  File(
                                    '${newProjectDir.path}/Collaborators/collaborators.json',
                                  ).writeAsStringSync(
                                    // collaborator structure: { "collaborators": [ { "name": "Alice", "email": "alice@example.com" } ] }
                                    '{\n  "collaborators": [{"name":"me", "email":"me@example.com"}]\n}\n',
                                  );
                                });
                                loadProjects();
                                Navigator.of(dialogContext).pop();
                              }

                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                title: Text('Create New Project'),
                                content: TextField(
                                  controller: projectNameController,
                                  decoration: InputDecoration(
                                    hintText: 'Project Name',
                                    errorText: projectAlreadyExists
                                        ? 'A project with this name already exists.'
                                        : null,
                                  ),
                                  onSubmitted: (_) async {
                                    await tryCreate();
                                  },
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop();
                                    },
                                    child: Text('Cancel'),
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
                                width: 40,
                                height: 40,
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
