import 'dart:convert';
import 'dart:io';

import 'package:devbox/database.dart';
import 'package:devbox/globals.dart';
import 'package:devbox/mindmap.dart';
import 'package:devbox/snippets.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

class Project extends StatefulWidget {
  const Project({
    super.key,
    required this.projectFolder,
    required this.projectName,
  });
  final Directory projectFolder;
  final String projectName;

  @override
  State<Project> createState() => _ProjectState();
}

class _ProjectState extends State<Project> {
  //retrieve every json file in mindmaps folder
  void _loadProject() {
    final mindmapsFolder = Directory(
      '${widget.projectFolder.path}${Platform.pathSeparator}mindmaps',
    );
    if (!mindmapsFolder.existsSync()) {
      return;
    }
  }

  @override
  void initState() {
    super.initState();
    Globals().currentProjectFolder = widget.projectFolder;
    _loadProject();
  }

  @override
  void dispose() {
    final current = Globals().currentProjectFolder;
    if (current?.path.toLowerCase() ==
        widget.projectFolder.path.toLowerCase()) {
      Globals().currentProjectFolder = null;
    }
    super.dispose();
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
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back),
                        color: Colors.white,
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.projectName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Navigation items
                Expanded(
                  child: Column(
                    children: [
                      DevBoxProjectButton(
                        onTap: () {
                          setState(() {
                            Globals().projectTab.value = 0;
                          });
                        },
                        text: "Dashboard",
                        icon: Icons.dashboard,
                        id: 0,
                      ),
                      DevBoxProjectButton(
                        onTap: () {
                          setState(() {
                            Globals().projectTab.value = 1;
                          });
                        },
                        text: "Files",
                        icon: Icons.folder,
                        id: 1,
                      ),
                      DevBoxProjectButton(
                        onTap: () {
                          setState(() {
                            Globals().projectTab.value = 2;
                          });
                        },
                        text: "Mindmaps",
                        icon: Icons.map,
                        id: 2,
                      ),
                      DevBoxProjectButton(
                        onTap: () {
                          setState(() {
                            Globals().projectTab.value = 5;
                          });
                        },
                        text: "Database",
                        icon: Icons.storage,
                        id: 5,
                      ),
                      DevBoxProjectButton(
                        onTap: () {
                          setState(() {
                            Globals().projectTab.value = 3;
                          });
                        },
                        text: "Colaborators",
                        icon: Icons.people,
                        id: 3,
                      ),
                      DevBoxProjectButton(
                        onTap: () {
                          setState(() {
                            Globals().projectTab.value = 6;
                          });
                        },
                        text: "Snippets",
                        icon: Icons.code,
                        id: 6,
                      ),

                      DevBoxProjectButton(
                        onTap: () {
                          setState(() {
                            Globals().projectTab.value = 4;
                          });
                        },
                        text: "Settings",
                        icon: Icons.settings,
                        id: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Globals().projectTab,
              builder: (context, value, child) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                  child: () {
                    if (value == 0) {
                      return KeyedSubtree(
                        key: const ValueKey('project-dashboard'),
                        child: Dashboard(widget.projectName, widget.projectFolder),
                      );
                    }
                    if (value == 1) {
                      return KeyedSubtree(
                        key: const ValueKey('project-files'),
                        child: Files(
                          projectName: widget.projectName,
                          projectFolder: widget.projectFolder,
                        ),
                      );
                    }
                    if (value == 2) {
                      return KeyedSubtree(
                        key: const ValueKey('project-mindmaps'),
                        child: MindMaps(
                          projectName: widget.projectName,
                          projectFolder: widget.projectFolder,
                        ),
                      );
                    }
                    if (value == 3) {
                      return KeyedSubtree(
                        key: const ValueKey('project-collaborators'),
                        child: Collaborators(
                          projectName: widget.projectName,
                          projectFolder: widget.projectFolder,
                        ),
                      );
                    }
                    if (value == 4) {
                      return KeyedSubtree(
                        key: const ValueKey('project-settings'),
                        child: ProjectSettings(
                          projectName: widget.projectName,
                          projectFolder: widget.projectFolder,
                        ),
                      );
                    }
                    if (value == 5) {
                      return KeyedSubtree(
                        key: const ValueKey('project-database'),
                        child: database(
                          projectName: widget.projectName,
                          projectFolder: widget.projectFolder,
                        ),
                      );
                    }
                    if (value == 6) {
                      return KeyedSubtree(
                        key: const ValueKey('project-snippets'),
                        child: Snippets(
                          projectName: widget.projectName,
                          projectFolder: widget.projectFolder,
                        ),
                      );
                    }
                    return KeyedSubtree(
                      key: ValueKey('project-tab-$value'),
                      child: Dashboard(widget.projectName, widget.projectFolder),
                    );
                  }(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DevBoxProjectButton extends StatelessWidget {
  const DevBoxProjectButton({
    super.key,
    required this.onTap,
    required this.text,
    required this.icon,
    required this.id,
  });

  final VoidCallback onTap;
  final String text;
  final IconData icon;
  final int id;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Material(
        color: Globals().projectTab.value == id
            ? Colors.blueGrey[600]
            : Colors.blueGrey[800],
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
            // ignore: deprecated_member_use
          ).withOpacity(0.3),
          onTap: () {
            onTap();
          },

          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: Colors.white70),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
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
  }
}

// ignore: non_constant_identifier_names
class Dashboard extends StatefulWidget {
  const Dashboard(this.projectName, this.projectFolder, {super.key});
  final String projectName;
  final Directory projectFolder;

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _fileCount = 0;
  int _snippetCount = 0;
  int _mindmapCount = 0;
  int _dbCount = 0;
  int _collaboratorCount = 0;
  String _readmeContent = '';
  List<_RecentFile> _recentFiles = [];
  bool _isEditingReadme = false;
  late TextEditingController _readmeController;

  @override
  void initState() {
    super.initState();
    _readmeController = TextEditingController();
    _loadStats();
  }

  @override
  void dispose() {
    _readmeController.dispose();
    super.dispose();
  }

  void _loadStats() {
    final p = widget.projectFolder.path;

    // Files count (recursive)
    try {
      final filesDir = Directory('$p/Files');
      if (filesDir.existsSync()) {
        _fileCount = filesDir
            .listSync(recursive: true)
            .whereType<File>()
            .length;
        final allFiles = filesDir
            .listSync(recursive: true)
            .whereType<File>()
            .toList()
          ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        _recentFiles = allFiles.take(5).map((f) {
          final rel = f.path.replaceFirst('$p/Files', '').replaceAll('\\', '/');
          return _RecentFile(rel.startsWith('/') ? rel.substring(1) : rel, f.statSync().modified);
        }).toList();
      }
    } on FileSystemException {}

    // Snippets count
    try {
      final snipDir = Directory('$p/Snippets');
      if (snipDir.existsSync()) {
        _snippetCount = snipDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .fold<int>(0, (sum, f) {
              try {
                final decoded = jsonDecode(f.readAsStringSync());
                if (decoded is Map && decoded['snippets'] is List) {
                  return sum + (decoded['snippets'] as List).length;
                }
              } catch (_) {}
              return sum;
            });
      }
    } on FileSystemException {}

    // Mindmaps count
    try {
      final mmDir = Directory('$p/MindMaps');
      if (mmDir.existsSync()) {
        _mindmapCount = mmDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .length;
      }
    } on FileSystemException {}

    // Database count
    try {
      final dbDir = Directory('$p/Database');
      if (dbDir.existsSync()) {
        _dbCount = dbDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .length;
      }
    } on FileSystemException {}

    // Collaborators count
    try {
      final collabFile = File('$p/Collaborators/collaborators.json');
      if (collabFile.existsSync()) {
        final decoded = jsonDecode(collabFile.readAsStringSync());
        if (decoded is Map && decoded['collaborators'] is List) {
          _collaboratorCount = (decoded['collaborators'] as List).length;
        }
      }
    } on FileSystemException {}

    // README
    try {
      final readme = File('$p/README.md');
      if (readme.existsSync()) {
        _readmeContent = readme.readAsStringSync();
        _readmeController.text = _readmeContent;
      }
    } on FileSystemException {}

    setState(() {});
  }

  void _saveReadme() {
    try {
      final readmeFile = File('${widget.projectFolder.path}/README.md');
      readmeFile.writeAsStringSync(_readmeController.text);
      _readmeContent = _readmeController.text;
      _isEditingReadme = false;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('README.md saved successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } on FileSystemException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving README.md: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _cancelEdit() {
    _readmeController.text = _readmeContent;
    _isEditingReadme = false;
    setState(() {});
  }

  void _openInVsCode() {
    final filesPath = '${widget.projectFolder.path}/Files';
    Process.run('code', [filesPath], runInShell: true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — matches other tabs style
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[100],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      widget.projectName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[900],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: Colors.blueGrey[100],
                  borderRadius: BorderRadius.circular(5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(5),
                    onTap: _openInVsCode,
                    splashColor: Colors.blueGrey[200],
                    highlightColor: Colors.blueGrey[300],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 15,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.code,
                            size: 18,
                            color: Colors.blueGrey[900],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Open in VS Code',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.blueGrey[100],
                  borderRadius: BorderRadius.circular(5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(5),
                    onTap: _loadStats,
                    splashColor: Colors.blueGrey[200],
                    highlightColor: Colors.blueGrey[300],
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      child: Icon(
                        Icons.refresh,
                        size: 18,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Stats row
            Row(
              children: [
                _StatCard(
                  icon: Icons.folder,
                  label: 'Files',
                  value: '$_fileCount',
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.code,
                  label: 'Snippets',
                  value: '$_snippetCount',
                  color: Colors.teal,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.map,
                  label: 'Mind Maps',
                  value: '$_mindmapCount',
                  color: Colors.orange,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.storage,
                  label: 'Databases',
                  value: '$_dbCount',
                  color: Colors.purple,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.people,
                  label: 'Collaborators',
                  value: '$_collaboratorCount',
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Bottom row: README + Recent Files — fills remaining space
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueGrey.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.description, size: 16, color: Colors.blueGrey[600]),
                                  const SizedBox(width: 6),
                                  Text(
                                    'README.md',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blueGrey[700],
                                    ),
                                  ),
                                ],
                              ),
                              if (!_isEditingReadme)
                                Material(
                                  color: Colors.transparent,
                                  child: Ink(
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey[100],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(4),
                                      onTap: () {
                                        setState(() {
                                          _isEditingReadme = true;
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit, size: 14, color: Colors.blueGrey[700]),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Edit',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blueGrey[700],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Material(
                                      color: Colors.green[100],
                                      borderRadius: BorderRadius.circular(4),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(4),
                                        onTap: _saveReadme,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.save, size: 14, color: Colors.green[700]),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Save',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.green[700],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Material(
                                      color: Colors.red[100],
                                      borderRadius: BorderRadius.circular(4),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(4),
                                        onTap: _cancelEdit,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.close, size: 14, color: Colors.red[700]),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.red[700],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _readmeContent.isEmpty && !_isEditingReadme
                                ? Text(
                                    'No README found.',
                                    style: TextStyle(
                                      color: Colors.blueGrey[400],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                : _isEditingReadme
                                    ? TextField(
                                      textAlignVertical: TextAlignVertical.top,
                                        controller: _readmeController,
                                        maxLines: null,
                                        expands: true,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderSide: BorderSide(color: Colors.blueGrey[300]!),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(color: Colors.blueGrey[600]!),
                                          ),
                                          contentPadding: const EdgeInsets.all(8),
                                        ),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blueGrey[800],
                                        ),
                                      )
                                    : SingleChildScrollView(
                                        child: Text(
                                          _readmeContent,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.blueGrey[800],
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _DashCard(
                      title: 'Recently Modified',
                      icon: Icons.history,
                      child: _recentFiles.isEmpty
                          ? Text(
                              'No files yet.',
                              style: TextStyle(
                                color: Colors.blueGrey[400],
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _recentFiles.map((rf) {
                                final ago = _timeAgo(rf.modified);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.insert_drive_file,
                                        size: 15,
                                        color: Colors.blueGrey[400],
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          rf.name,
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        ago,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blueGrey[400],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _RecentFile {
  const _RecentFile(this.name, this.modified);
  final String name;
  final DateTime modified;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blueGrey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[900],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.blueGrey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  const _DashCard({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.blueGrey[600]),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class Files extends StatefulWidget {
  const Files({
    super.key,
    required this.projectName,
    required this.projectFolder,
  });

  final String projectName;
  final Directory projectFolder;

  @override
  State<Files> createState() => _FilesState();
}

class _FilesState extends State<Files> {
  late final Directory _filesRootDirectory;
  late Directory _currentDirectory;
  final TextEditingController _folderNameController = TextEditingController();
  bool _isExternalDropActive = false;

  String _ioPath(String path) {
    if (!Platform.isWindows) {
      return path;
    }

    var normalized = path.replaceAll('/', '\\');
    if (normalized.startsWith('\\\\?\\')) {
      return normalized;
    }
    if (normalized.startsWith('\\\\')) {
      return '\\\\?\\UNC\\${normalized.substring(2)}';
    }
    if (RegExp(r'^[a-zA-Z]:\\').hasMatch(normalized)) {
      return '\\\\?\\$normalized';
    }
    return normalized;
  }

  bool _directoryExists(Directory directory) {
    return Directory(_ioPath(directory.path)).existsSync();
  }

  String _normalizePathForComparison(String path) {
    final normalized = path
        .replaceAll('/', Platform.pathSeparator)
        .replaceAll('\\', Platform.pathSeparator);
    if (!Platform.isWindows) {
      return normalized;
    }
    return normalized.toLowerCase();
  }

  bool _samePathIgnoringCase(String first, String second) {
    return _normalizePathForComparison(first) ==
        _normalizePathForComparison(second);
  }

  Future<void> _renameDirectory(Directory from, Directory to) async {
    final fromPath = from.path;
    final toPath = to.path;

    final isCaseOnlyRename =
        Platform.isWindows &&
        _samePathIgnoringCase(fromPath, toPath) &&
        fromPath != toPath;

    if (!isCaseOnlyRename) {
      await Directory(_ioPath(fromPath)).rename(_ioPath(toPath));
      return;
    }

    final tempDirectory = Directory(
      '${from.parent.path}${Platform.pathSeparator}.__devbox_case_tmp_${DateTime.now().microsecondsSinceEpoch}',
    );

    await Directory(_ioPath(fromPath)).rename(_ioPath(tempDirectory.path));
    await Directory(_ioPath(tempDirectory.path)).rename(_ioPath(toPath));
  }

  List<Directory> _listDirectories(Directory directory) {
    return Directory(
      _ioPath(directory.path),
    ).listSync().whereType<Directory>().map((entry) {
      var path = entry.path;
      if (Platform.isWindows && path.startsWith('\\\\?\\UNC\\')) {
        path = '\\\\${path.substring('\\\\?\\UNC\\'.length)}';
      } else if (Platform.isWindows && path.startsWith('\\\\?\\')) {
        path = path.substring('\\\\?\\'.length);
      }
      return Directory(path);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _filesRootDirectory = Directory(
      '${widget.projectFolder.path}${Platform.pathSeparator}files',
    );
    if (!_directoryExists(_filesRootDirectory)) {
      Directory(_ioPath(_filesRootDirectory.path)).createSync(recursive: true);
    }
    _currentDirectory = _filesRootDirectory;
  }

  @override
  void dispose() {
    _folderNameController.dispose();
    super.dispose();
  }

  List<Directory> _directoriesInCurrentPath() {
    bool exists;
    try {
      exists = _directoryExists(_currentDirectory);
    } on FileSystemException {
      return const [];
    }

    if (!exists) {
      return const [];
    }

    try {
      final entries =
          _listDirectories(_currentDirectory).where(_isWithinFilesRoot).toList()
            ..sort((first, second) => first.path.compareTo(second.path));
      return entries;
    } on FileSystemException {
      return const [];
    }
  }

  List<File> _filesInCurrentPath() {
    try {
      if (!_directoryExists(_currentDirectory)) return const [];
      return Directory(
          _ioPath(_currentDirectory.path),
        ).listSync().whereType<File>().map((f) {
          var path = f.path;
          if (Platform.isWindows && path.startsWith('\\\\?\\UNC\\')) {
            path = '\\\\${path.substring('\\\\?\\UNC\\'.length)}';
          } else if (Platform.isWindows && path.startsWith('\\\\?\\')) {
            path = path.substring('\\\\?\\'.length);
          }
          return File(path);
        }).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
    } on FileSystemException {
      return const [];
    }
  }

  bool _isWithinFilesRoot(Directory directory) {
    String normalize(String value) {
      var normalized = value
          .replaceAll('/', Platform.pathSeparator)
          .replaceAll('\\', Platform.pathSeparator);
      if (Platform.isWindows) {
        normalized = normalized.toLowerCase();
      }
      return normalized;
    }

    final rootPath = normalize(_filesRootDirectory.absolute.path);
    final candidatePath = normalize(directory.absolute.path);

    return candidatePath == rootPath ||
        candidatePath.startsWith('$rootPath${Platform.pathSeparator}');
  }

  List<Directory> _pathDirectories() {
    if (!_isWithinFilesRoot(_currentDirectory)) {
      _currentDirectory = _filesRootDirectory;
    }

    final relativePath = _currentDirectory.path.substring(
      _filesRootDirectory.path.length,
    );
    final parts = relativePath
        .split(Platform.pathSeparator)
        .where((part) => part.isNotEmpty)
        .toList();

    final directories = <Directory>[_filesRootDirectory];
    var path = _filesRootDirectory.path;
    for (final part in parts) {
      path = '$path${Platform.pathSeparator}$part';
      final nextDirectory = Directory(path);
      if (_isWithinFilesRoot(nextDirectory)) {
        directories.add(nextDirectory);
      }
    }
    return directories;
  }

  Future<void> _createFolder() async {
    var folderAlreadyExists = false;
    String? folderCreateError;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        _folderNameController.clear();

        Future<void> tryCreate() async {
          final folderName = _folderNameController.text.trim();
          if (folderName.isEmpty) {
            return;
          }

          final newDirectory = Directory(
            '${_currentDirectory.path}${Platform.pathSeparator}$folderName',
          );

          if (!_isWithinFilesRoot(newDirectory)) {
            return;
          }

          // Case-sensitive duplicate check: compare exact names from listing.
          final existingNames = _listDirectories(_currentDirectory)
              .map(
                (d) => d.path
                    .split(RegExp(r'[/\\]'))
                    .where((s) => s.isNotEmpty)
                    .last
                    .toLowerCase(),
              )
              .toList();
          if (existingNames.contains(folderName.toLowerCase())) {
            folderAlreadyExists = true;
            folderCreateError = null;
            (dialogContext as Element).markNeedsBuild();
            return;
          }

          try {
            await Directory(_ioPath(newDirectory.path)).create();
          } on FileSystemException {
            folderCreateError = 'Could not create folder.';
            (dialogContext as Element).markNeedsBuild();
            return;
          }

          if (!mounted) {
            return;
          }

          // ignore: use_build_context_synchronously
          Navigator.of(dialogContext).pop(true);
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('New folder'),
          content: TextField(
            controller: _folderNameController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Folder name',
              errorText: folderAlreadyExists
                  ? 'A folder with this name already exists.'
                  : folderCreateError,
            ),
            onChanged: (_) {
              if (folderAlreadyExists) {
                folderAlreadyExists = false;
                (dialogContext as Element).markNeedsBuild();
              }
              if (folderCreateError != null) {
                folderCreateError = null;
                (dialogContext as Element).markNeedsBuild();
              }
            },
            onSubmitted: (_) async {
              await tryCreate();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await tryCreate();
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (shouldCreate != true) {
      _folderNameController.clear();
      return;
    }
    _folderNameController.clear();

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _renameFolder(Directory folder) async {
    if (!_isWithinFilesRoot(folder) ||
        folder.path == _filesRootDirectory.path) {
      return;
    }

    var folderAlreadyExists = false;
    final currentName = folder.path.split(Platform.pathSeparator).last;
    var nextFolderName = currentName;

    final shouldRename = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogElement = dialogContext as Element;

        Future<void> tryRename() async {
          final nextName = nextFolderName.trim();
          if (nextName.isEmpty || nextName == currentName) {
            return;
          }

          final parentPath = folder.parent.path;
          final renamedFolder = Directory(
            '$parentPath${Platform.pathSeparator}$nextName',
          );

          if (!_isWithinFilesRoot(renamedFolder)) {
            return;
          }

          final isCaseOnlyRename =
              Platform.isWindows &&
              _samePathIgnoringCase(folder.path, renamedFolder.path) &&
              folder.path != renamedFolder.path;

          if (!isCaseOnlyRename && _directoryExists(renamedFolder)) {
            folderAlreadyExists = true;
            if (dialogElement.mounted) {
              dialogElement.markNeedsBuild();
            }
            return;
          }

          try {
            await _renameDirectory(folder, renamedFolder);
          } on FileSystemException {
            if (!context.mounted) {
              return;
            }
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not rename folder.')),
            );
            return;
          }

          if (!context.mounted) {
            return;
          }

          Navigator.of(dialogContext).pop(true);
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Rename folder'),
          content: TextFormField(
            initialValue: currentName,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Folder name',
              errorText: folderAlreadyExists
                  ? 'A folder with this name already exists.'
                  : null,
            ),
            onChanged: (value) {
              nextFolderName = value;
              if (folderAlreadyExists) {
                folderAlreadyExists = false;
                if (dialogElement.mounted) {
                  dialogElement.markNeedsBuild();
                }
              }
            },
            onFieldSubmitted: (_) {
              FocusScope.of(dialogContext).unfocus();
              Future<void>.microtask(tryRename);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await tryRename();
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    if (shouldRename != true || !mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _deleteFolder(Directory folder) async {
    if (!_isWithinFilesRoot(folder) ||
        folder.path == _filesRootDirectory.path) {
      return;
    }

    final folderName = folder.path.split(Platform.pathSeparator).last;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Delete folder'),
          content: Text(
            'Delete "$folderName" permanently? This cannot be undone.',
          ),
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
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      final deleteTarget = Directory(_ioPath(folder.path));
      if (deleteTarget.existsSync()) {
        await deleteTarget.delete(recursive: true);
      }
    } on FileSystemException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not delete folder.')));
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _handleExternalDrop(List<DropItem> droppedItems) async {
    if (!_directoryExists(_currentDirectory)) {
      return;
    }

    var copiedCount = 0;
    var skippedExistingCount = 0;
    var skippedNonFileCount = 0;
    var failedCount = 0;

    for (final item in droppedItems) {
      final sourcePath = item.path;
      if (sourcePath.isEmpty) {
        skippedNonFileCount++;
        continue;
      }

      final sourceFile = File(_ioPath(sourcePath));
      if (!sourceFile.existsSync()) {
        skippedNonFileCount++;
        continue;
      }

      final name = sourcePath.split(RegExp(r'[/\\]')).last;
      final destinationPath =
          '${_currentDirectory.path}${Platform.pathSeparator}$name';

      if (File(_ioPath(destinationPath)).existsSync() ||
          Directory(_ioPath(destinationPath)).existsSync()) {
        skippedExistingCount++;
        continue;
      }

      try {
        await sourceFile.copy(_ioPath(destinationPath));
        copiedCount++;
      } on FileSystemException {
        failedCount++;
      }
    }

    if (!mounted) {
      return;
    }

    if (copiedCount > 0) {
      setState(() {});
    }

    final messages = <String>[];
    if (copiedCount > 0) {
      messages.add('$copiedCount ${copiedCount == 1 ? 'file' : 'files'} added');
    }
    if (skippedExistingCount > 0) {
      messages.add('$skippedExistingCount already existed');
    }
    if (skippedNonFileCount > 0) {
      messages.add('$skippedNonFileCount skipped (not files)');
    }
    if (failedCount > 0) {
      messages.add('$failedCount failed');
    }

    if (messages.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(messages.join(' • '))));
    }
  }

  Future<void> _moveItem(String sourcePath, Directory targetFolder) async {
    if (!_isWithinFilesRoot(targetFolder)) return;

    final name = sourcePath.split(Platform.pathSeparator).last;
    final destPath = '${targetFolder.path}${Platform.pathSeparator}$name';

    // Already in this folder — nothing to do
    if (sourcePath == destPath) return;
    // Prevent dropping a folder into one of its own descendants
    if (targetFolder.path.startsWith(sourcePath + Platform.pathSeparator)) {
      return;
    }

    if (File(_ioPath(destPath)).existsSync() ||
        Directory(_ioPath(destPath)).existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$name" already exists in the destination folder.'),
        ),
      );
      return;
    }

    try {
      final srcDir = Directory(_ioPath(sourcePath));
      if (srcDir.existsSync()) {
        await srcDir.rename(_ioPath(destPath));
      } else {
        await File(_ioPath(sourcePath)).rename(_ioPath(destPath));
      }
    } on FileSystemException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not move item.')));
      return;
    }

    if (mounted) setState(() {});
  }

  void _openDirectory(Directory directory) {
    if (!_isWithinFilesRoot(directory)) {
      return;
    }

    try {
      if (!_directoryExists(directory)) {
        return;
      }
    } on FileSystemException {
      return;
    }

    setState(() {
      _currentDirectory = directory;
    });
  }

  @override
  Widget build(BuildContext context) {
    final folders = _directoriesInCurrentPath();
    final files = _filesInCurrentPath();
    final pathDirectories = _pathDirectories();
    final totalItems = folders.length + files.length;
    final contentKey = ValueKey(
      '${_currentDirectory.path}-${folders.length}-${files.length}',
    );

    return Container(
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[100],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Files',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[900],
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${folders.length} ${folders.length == 1 ? 'folder' : 'folders'}, ${files.length} ${files.length == 1 ? 'file' : 'files'}',
                          style: TextStyle(
                            color: Colors.blueGrey[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 18),
                Material(
                  color: Colors.blueGrey[100],
                  borderRadius: BorderRadius.circular(5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(5),
                    onTap: _createFolder,
                    splashColor: Colors.blueGrey[200],
                    highlightColor: Colors.blueGrey[300],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.create_new_folder,
                            color: Colors.blueGrey[900],
                          ),
                          SizedBox(width: 8),
                          Text(
                            'New Folder',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 18),
                Material(
                  color: Colors.blueGrey[100],
                  borderRadius: BorderRadius.circular(5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(5),
                    onTap: () {
                      setState(() {});
                    },
                    splashColor: Colors.blueGrey[200],
                    highlightColor: Colors.blueGrey[300],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.refresh, color: Colors.blueGrey[900]),
                          SizedBox(width: 8),
                          Text(
                            'Refresh',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 17),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < pathDirectories.length; i++)
                  DragTarget<String>(
                    onWillAcceptWithDetails: (details) {
                      final dir = pathDirectories[i];
                      final src = details.data;
                      if (src == dir.path) return false;
                      if (dir.path.startsWith(src + Platform.pathSeparator)) {
                        return false;
                      }
                      return _isWithinFilesRoot(dir);
                    },
                    onAcceptWithDetails: (details) =>
                        _moveItem(details.data, pathDirectories[i]),
                    builder: (context, candidateData, rejectedData) =>
                        _PathCrumb(
                          label: i == 0
                              ? 'Files'
                              : pathDirectories[i].path
                                    .split(Platform.pathSeparator)
                                    .last,
                          isActive: _samePathIgnoringCase(
                            pathDirectories[i].path,
                            _currentDirectory.path,
                          ),
                          isDropTarget: candidateData.isNotEmpty,
                          onTap: () => _openDirectory(pathDirectories[i]),
                        ),
                  ),
              ],
            ),
            SizedBox(height: 17),
            Expanded(
              child: DropTarget(
                onDragEntered: (_) {
                  setState(() {
                    _isExternalDropActive = true;
                  });
                },
                onDragExited: (_) {
                  setState(() {
                    _isExternalDropActive = false;
                  });
                },
                onDragDone: (details) async {
                  setState(() {
                    _isExternalDropActive = false;
                  });
                  await _handleExternalDrop(details.files);
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: _isExternalDropActive
                          ? Colors.blueGrey[700]!
                          : Colors.transparent,
                      width: 2,
                    ),
                    color: _isExternalDropActive
                        ? Colors.blueGrey[100]
                        : Colors.transparent,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: totalItems == 0
                        ? Center(
                            key: contentKey,
                            child: Text(
                              _isExternalDropActive
                                  ? 'Drop files to add them here'
                                  : 'No files or folders here yet.',
                              style: TextStyle(
                                color: Colors.blueGrey[500],
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.builder(
                            key: contentKey,
                            itemCount: totalItems,
                            itemBuilder: (context, index) {
                              if (index < folders.length) {
                                final folder = folders[index];
                                final folderPath = folder.path;
                                final folderName = folderPath
                                    .split(Platform.pathSeparator)
                                    .last;
                                return Draggable<String>(
                                  data: folderPath,
                                  dragAnchorStrategy: pointerDragAnchorStrategy,
                                  feedback: Transform.translate(
                                    offset: const Offset(-110, -20),
                                    child: Material(
                                      elevation: 4,
                                      borderRadius: BorderRadius.circular(5),
                                      child: Container(
                                        width: 220,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blueGrey[400],
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.folder,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                folderName,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.4,
                                    child: FileButton(
                                      name: folderName,
                                      onTap: () {},
                                      onRename: () {},
                                      onDelete: () {},
                                    ),
                                  ),
                                  child: DragTarget<String>(
                                    onWillAcceptWithDetails: (details) {
                                      final src = details.data;
                                      if (src == folderPath) return false;
                                      if (folderPath.startsWith(
                                        src + Platform.pathSeparator,
                                      )) {
                                        return false;
                                      }
                                      final srcParent =
                                          (src.split(Platform.pathSeparator)
                                                ..removeLast())
                                              .join(Platform.pathSeparator);
                                      return srcParent != folderPath;
                                    },
                                    onAcceptWithDetails: (details) =>
                                        _moveItem(details.data, folder),
                                    builder: (context, candidateData, _) =>
                                        FileButton(
                                          name: folderName,
                                          isDropTarget:
                                              candidateData.isNotEmpty,
                                          onTap: () {
                                            _openDirectory(folder);
                                          },
                                          onRename: () => _renameFolder(folder),
                                          onDelete: () => _deleteFolder(folder),
                                        ),
                                  ),
                                );
                              }
                              final file = files[index - folders.length];
                              final filePath = file.path;
                              final fileName = filePath
                                  .split(Platform.pathSeparator)
                                  .last;
                              return Draggable<String>(
                                data: filePath,
                                dragAnchorStrategy: pointerDragAnchorStrategy,
                                feedback: Transform.translate(
                                  offset: const Offset(-110, -20),
                                  child: Material(
                                    elevation: 4,
                                    borderRadius: BorderRadius.circular(5),
                                    child: Container(
                                      width: 220,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey[300],
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.insert_drive_file,
                                            color: Colors.blueGrey[800],
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              fileName,
                                              style: TextStyle(
                                                color: Colors.blueGrey[900],
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
                                childWhenDragging: Opacity(
                                  opacity: 0.4,
                                  child: _FileItemTile(
                                    name: fileName,
                                    onDelete: () {},
                                  ),
                                ),
                                child: _FileItemTile(
                                  name: fileName,
                                  onDelete: () => _deleteFile(file),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteFile(File file) async {
    final name = file.path.split(Platform.pathSeparator).last;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: const Text('Delete file'),
        content: Text('Delete "$name" permanently? This cannot be undone.'),
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

    if (shouldDelete != true) return;

    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not delete file.')));
      return;
    }

    if (mounted) setState(() {});
  }
}

class _FileItemTile extends StatelessWidget {
  const _FileItemTile({required this.name, required this.onDelete});

  final String name;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Material(
        color: Colors.blueGrey[200],
        borderRadius: BorderRadius.circular(5),
        child: ListTile(
          leading: Icon(Icons.insert_drive_file, color: Colors.blueGrey[800]),
          title: Text(
            name,
            style: TextStyle(
              color: Colors.blueGrey[900],
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete, color: Colors.blueGrey[700]),
            tooltip: 'Delete file',
            onPressed: onDelete,
          ),
        ),
      ),
    );
  }
}

class _PathCrumb extends StatelessWidget {
  const _PathCrumb({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isDropTarget = false,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDropTarget;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDropTarget
          ? Colors.blueGrey[500]
          : isActive
          ? Colors.blueGrey[700]
          : Colors.blueGrey[200],
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.blueGrey[900],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class FileButton extends StatelessWidget {
  const FileButton({
    super.key,
    required this.name,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    this.isDropTarget = false,
  });

  final String name;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final bool isDropTarget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Material(
        color: isDropTarget ? Colors.blueGrey[500] : Colors.blueGrey[300],
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: onTap,
          child: ListTile(
            leading: Icon(Icons.folder, color: Colors.white),
            title: Text(
              name,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  tooltip: 'Rename folder',
                  onPressed: onRename,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  tooltip: 'Delete folder',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Collaborators extends StatefulWidget {
  const Collaborators({
    super.key,
    required this.projectName,
    required this.projectFolder,
  });

  final String projectName;
  final Directory projectFolder;

  @override
  State<Collaborators> createState() => _CollaboratorsState();
}

class _CollaboratorsState extends State<Collaborators> {
  final List<Map<String, String>> _collaborators = [];

  File get _jsonFile => File(
    '${widget.projectFolder.path}${Platform.pathSeparator}Collaborators${Platform.pathSeparator}collaborators.json',
  );

  @override
  void initState() {
    super.initState();
    _loadCollaborators();
  }

  void _loadCollaborators() {
    try {
      if (!_jsonFile.existsSync()) return;
      final content = _jsonFile.readAsStringSync();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final list = decoded['collaborators'] as List<dynamic>?;
      if (list == null) return;
      setState(() {
        _collaborators.clear();
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            _collaborators.add({
              'name': item['name']?.toString() ?? '',
              'email': item['email']?.toString() ?? '',
              'role': item['role']?.toString() ?? '',
              'github': item['github']?.toString() ?? '',
              'pay': item['pay']?.toString() ?? '',
            });
          }
        }
      });
    } on FileSystemException {
      // ignore read errors
    } on FormatException {
      // ignore malformed JSON
    }
  }

  void _saveCollaborators() {
    try {
      final dir = _jsonFile.parent;
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final encoded = jsonEncode({'collaborators': _collaborators});
      _jsonFile.writeAsStringSync(encoded);
    } on FileSystemException {
      // ignore write errors
    }
  }

  Future<void> _showCollaboratorDialog({int? editIndex}) async {
    final isEditing = editIndex != null;
    final nameCtrl = TextEditingController(
      text: isEditing ? _collaborators[editIndex]['name'] : '',
    );
    final emailCtrl = TextEditingController(
      text: isEditing ? _collaborators[editIndex]['email'] : '',
    );
    final roleCtrl = TextEditingController(
      text: isEditing ? _collaborators[editIndex]['role'] : '',
    );
    final githubCtrl = TextEditingController(
      text: isEditing ? _collaborators[editIndex]['github'] : '',
    );
    final payCtrl = TextEditingController(
      text: isEditing ? _collaborators[editIndex]['pay'] : '',
    );

    String? nameError;
    String? emailError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void trySubmit() {
              final name = nameCtrl.text.trim();
              final email = emailCtrl.text.trim();

              if (name.isEmpty) {
                setDialogState(() => nameError = 'Name is required.');
                return;
              }

              final nameTaken = _collaborators.indexWhere(
                (c) => c['name']?.toLowerCase() == name.toLowerCase(),
              );
              if (nameTaken != -1 && nameTaken != editIndex) {
                setDialogState(() => nameError = 'Name already in use.');
                return;
              }

              if (email.isNotEmpty) {
                final emailTaken = _collaborators.indexWhere(
                  (c) =>
                      c['email']?.isNotEmpty == true &&
                      c['email']?.toLowerCase() == email.toLowerCase(),
                );
                if (emailTaken != -1 && emailTaken != editIndex) {
                  setDialogState(() => emailError = 'Email already in use.');
                  return;
                }
              }

              final entry = {
                'name': name,
                'email': email,
                'role': roleCtrl.text.trim(),
                'github': githubCtrl.text.trim(),
                'pay': payCtrl.text.trim(),
              };

              setState(() {
                if (isEditing) {
                  _collaborators[editIndex] = entry;
                } else {
                  _collaborators.add(entry);
                }
              });
              _saveCollaborators();
              Navigator.of(dialogContext).pop();
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              title: Text(isEditing ? 'Edit Collaborator' : 'Add Collaborator'),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        hintText: 'Full name',
                        errorText: nameError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      onChanged: (_) {
                        if (nameError != null) {
                          setDialogState(() => nameError = null);
                        }
                      },
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'email@example.com',
                        errorText: emailError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      onChanged: (_) {
                        if (emailError != null) {
                          setDialogState(() => emailError = null);
                        }
                      },
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: roleCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Role',
                        hintText: 'e.g. Developer, Designer',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: githubCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'GitHub',
                        hintText: 'GitHub username',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: payCtrl,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Pay',
                        hintText: 'e.g. 25/hr, 3000/mo',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      onSubmitted: (_) => trySubmit(),
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
                  onPressed: trySubmit,
                  child: Text(isEditing ? 'Save' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[100],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      'Collaborators',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 18),
                Material(
                  color: Colors.blueGrey[100],
                  borderRadius: BorderRadius.circular(5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(5),
                    onTap: () => _showCollaboratorDialog(),
                    splashColor: Colors.blueGrey[200],
                    highlightColor: Colors.blueGrey[300],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 15,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_add,
                            size: 18,
                            color: Colors.blueGrey[900],
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Add Collaborator',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Expanded(
              child: _collaborators.isEmpty
                  ? Center(
                      child: Text(
                        'No collaborators yet.',
                        style: TextStyle(
                          color: Colors.blueGrey[500],
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _collaborators.length,
                      itemBuilder: (context, index) {
                        final collaborator = _collaborators[index];
                        final email = collaborator['email'] ?? '';
                        final role = collaborator['role'] ?? '';
                        final subtitle = [
                          if (email.isNotEmpty) email,
                          if (role.isNotEmpty) role,
                          if (collaborator['github']?.isNotEmpty == true)
                            '${collaborator['github']}',
                          if (collaborator['pay']?.isNotEmpty == true)
                            '${collaborator['pay']}',
                        ].join('  •  ');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Material(
                            color: Colors.blueGrey[200],
                            borderRadius: BorderRadius.circular(5),
                            child: ListTile(
                              leading: Icon(
                                Icons.person,
                                color: Colors.blueGrey[800],
                              ),
                              title: Text(
                                collaborator['name'] ?? '',
                                style: TextStyle(
                                  color: Colors.blueGrey[900],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: subtitle.isNotEmpty
                                  ? Text(
                                      subtitle,
                                      style: TextStyle(
                                        color: Colors.blueGrey[700],
                                        fontSize: 13,
                                      ),
                                    )
                                  : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      color: Colors.blueGrey[600],
                                    ),
                                    tooltip: 'Edit collaborator',
                                    onPressed: () => _showCollaboratorDialog(
                                      editIndex: index,
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: Colors.blueGrey[700],
                                    ),
                                    tooltip: 'Remove collaborator',
                                    onPressed: () async {
                                      final shouldDelete = await showDialog<bool>(
                                        context: context,
                                        builder: (dialogContext) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                          title: const Text(
                                            'Remove collaborator',
                                          ),
                                          content: Text(
                                            'Remove "${collaborator['name']}" from collaborators?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                dialogContext,
                                              ).pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    Colors.red[700],
                                              ),
                                              onPressed: () => Navigator.of(
                                                dialogContext,
                                              ).pop(true),
                                              child: const Text('Remove'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (shouldDelete != true) return;
                                      setState(() {
                                        _collaborators.removeAt(index);
                                      });
                                      _saveCollaborators();
                                    },
                                  ),
                                ],
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
    );
  }
}

class ProjectSettings extends StatelessWidget {
  const ProjectSettings({
    super.key,
    required this.projectName,
    required this.projectFolder,
  });

  final String projectName;
  final Directory projectFolder;

  String _ioPath(String path) {
    if (!Platform.isWindows) {
      return path;
    }

    var normalized = path.replaceAll('/', '\\');
    if (normalized.startsWith('\\\\?\\')) {
      return normalized;
    }
    if (normalized.startsWith('\\\\')) {
      return '\\\\?\\UNC\\${normalized.substring(2)}';
    }
    if (RegExp(r'^[a-zA-Z]:\\').hasMatch(normalized)) {
      return '\\\\?\\$normalized';
    }
    return normalized;
  }

  String _normalizePathForComparison(String path) {
    final normalized = path
        .replaceAll('/', Platform.pathSeparator)
        .replaceAll('\\', Platform.pathSeparator);
    if (!Platform.isWindows) {
      return normalized;
    }
    return normalized.toLowerCase();
  }

  bool _samePathIgnoringCase(String first, String second) {
    return _normalizePathForComparison(first) ==
        _normalizePathForComparison(second);
  }

  Future<void> _renameDirectory(Directory from, Directory to) async {
    final fromPath = from.path;
    final toPath = to.path;

    final isCaseOnlyRename =
        Platform.isWindows &&
        _samePathIgnoringCase(fromPath, toPath) &&
        fromPath != toPath;

    if (!isCaseOnlyRename) {
      await Directory(_ioPath(fromPath)).rename(_ioPath(toPath));
      return;
    }

    final tempDirectory = Directory(
      '${from.parent.path}${Platform.pathSeparator}.__devbox_case_tmp_${DateTime.now().microsecondsSinceEpoch}',
    );

    await Directory(_ioPath(fromPath)).rename(_ioPath(tempDirectory.path));
    await Directory(_ioPath(tempDirectory.path)).rename(_ioPath(toPath));
  }

  Future<void> _renameProject(BuildContext context) async {
    var projectAlreadyExists = false;
    var nextProjectName = projectName;

    final shouldRename = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogElement = dialogContext as Element;

        Future<void> tryRename() async {
          final nextName = nextProjectName.trim();
          if (nextName.isEmpty || nextName == projectName) {
            return;
          }

          final parentPath = projectFolder.parent.path;
          final renamedProject = Directory(
            '$parentPath${Platform.pathSeparator}$nextName',
          );

          final isCaseOnlyRename =
              Platform.isWindows &&
              _samePathIgnoringCase(projectFolder.path, renamedProject.path) &&
              projectFolder.path != renamedProject.path;

          if (!isCaseOnlyRename &&
              Directory(_ioPath(renamedProject.path)).existsSync()) {
            projectAlreadyExists = true;
            if (dialogElement.mounted) {
              dialogElement.markNeedsBuild();
            }
            return;
          }

          try {
            await _renameDirectory(projectFolder, renamedProject);
          } catch (_) {
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not rename project folder.')),
            );
            return;
          }

          if (!context.mounted) {
            return;
          }

          Navigator.of(dialogContext).pop(true);
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Rename project'),
          content: TextFormField(
            initialValue: projectName,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Project name',
              errorText: projectAlreadyExists
                  ? 'A project with this name already exists.'
                  : null,
            ),
            onChanged: (value) {
              nextProjectName = value;
              if (projectAlreadyExists) {
                projectAlreadyExists = false;
                if (dialogElement.mounted) {
                  dialogElement.markNeedsBuild();
                }
              }
            },
            onFieldSubmitted: (_) {
              FocusScope.of(dialogContext).unfocus();
              Future<void>.microtask(tryRename);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await tryRename();
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    if (shouldRename != true || !context.mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  Future<void> _deleteProject(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Delete project'),
          content: Text(
            'Delete "$projectName" permanently? This cannot be undone.',
          ),
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
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      final deleteTarget = Directory(_ioPath(projectFolder.path));
      if (deleteTarget.existsSync()) {
        await deleteTarget.delete(recursive: true);
      }
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete project folder.')),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[100],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[100],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          projectName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[900],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blueGrey[700]),
                          onPressed: () {
                            _renameProject(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 17),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey[100],
                borderRadius: BorderRadius.circular(5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Danger Zone',
                    style: TextStyle(
                      color: Colors.red[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Deleting this project removes the folder and all files inside it.',
                    style: TextStyle(color: Colors.blueGrey[800]),
                  ),
                  SizedBox(height: 14),
                  Material(
                    color: Colors.red[700],
                    borderRadius: BorderRadius.circular(5),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(5),
                      onTap: () => _deleteProject(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.delete_forever, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Delete Project',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MindMaps extends StatefulWidget {
  const MindMaps({
    super.key,
    required this.projectName,
    required this.projectFolder,
  });

  final String projectName;
  final Directory projectFolder;

  @override
  State<MindMaps> createState() => _MindMapsState();
}

class _MindMapsState extends State<MindMaps> {
  late final Directory _mindmapsDirectory;
  List<File> _mindmapFiles = const [];
  final TextEditingController _mindmapNameController = TextEditingController();

  @override
  void dispose() {
    _mindmapNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _mindmapsDirectory = Directory(
      '${widget.projectFolder.path}${Platform.pathSeparator}mindmaps',
    );
    _loadMindmaps();
  }

  Future<void> _createMindmap() async {
    var alreadyExists = false;
    String? createError;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        _mindmapNameController.clear();

        Future<void> tryCreate() async {
          final rawName = _mindmapNameController.text.trim();
          if (rawName.isEmpty) return;

          // Reject names with filesystem-unsafe characters
          if (rawName.contains(RegExp(r'[<>:"/\\|?*]'))) {
            createError = 'Name contains invalid characters.';
            (dialogContext as Element).markNeedsBuild();
            return;
          }

          final fileName = rawName.endsWith('.json')
              ? rawName
              : '$rawName.json';

          final existingNames = _mindmapFiles
              .map(
                (f) => f.path
                    .split(RegExp(r'[/\\]'))
                    .where((s) => s.isNotEmpty)
                    .last
                    .toLowerCase(),
              )
              .toList();

          if (existingNames.contains(fileName.toLowerCase())) {
            alreadyExists = true;
            createError = null;
            (dialogContext as Element).markNeedsBuild();
            return;
          }

          final newFile = File(
            '${_mindmapsDirectory.path}${Platform.pathSeparator}$fileName',
          );

          try {
            if (!_mindmapsDirectory.existsSync()) {
              _mindmapsDirectory.createSync(recursive: true);
            }
            await newFile.writeAsString('{"nodes":[]}');
          } on FileSystemException {
            createError = 'Could not create mindmap file.';
            (dialogContext as Element).markNeedsBuild();
            return;
          }

          if (!mounted) return;
          // ignore: use_build_context_synchronously
          Navigator.of(dialogContext).pop(true);
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('New Mindmap'),
          content: TextField(
            controller: _mindmapNameController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Mindmap name',
              hintText: 'my-mindmap',
              errorText: alreadyExists
                  ? 'A mindmap with this name already exists.'
                  : createError,
            ),
            onChanged: (_) {
              if (alreadyExists) {
                alreadyExists = false;
                (dialogContext as Element).markNeedsBuild();
              }
              if (createError != null) {
                createError = null;
                (dialogContext as Element).markNeedsBuild();
              }
            },
            onSubmitted: (_) async => tryCreate(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async => tryCreate(),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (shouldCreate == true) {
      _loadMindmaps();
    }
  }

  Future<void> _renameMindmap(File file) async {
    var alreadyExists = false;
    final currentName = file.path.split(Platform.pathSeparator).last;
    // strip .json for display
    final baseName = currentName.endsWith('.json')
        ? currentName.substring(0, currentName.length - 5)
        : currentName;
    var nextName = baseName;

    final shouldRename = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogElement = dialogContext as Element;

        Future<void> tryRename() async {
          final raw = nextName.trim();
          if (raw.isEmpty || raw == baseName) return;

          if (raw.contains(RegExp(r'[<>:"/\\|?*]'))) {
            alreadyExists = false;
            (dialogContext).markNeedsBuild();
            return;
          }

          final newFileName = raw.endsWith('.json') ? raw : '$raw.json';

          final existingNames = _mindmapFiles
              .map(
                (f) => f.path
                    .split(RegExp(r'[/\\]'))
                    .where((s) => s.isNotEmpty)
                    .last
                    .toLowerCase(),
              )
              .toList();

          if (existingNames.contains(newFileName.toLowerCase()) &&
              newFileName.toLowerCase() != currentName.toLowerCase()) {
            alreadyExists = true;
            if (dialogElement.mounted) dialogElement.markNeedsBuild();
            return;
          }

          final newFile = File(
            '${file.parent.path}${Platform.pathSeparator}$newFileName',
          );

          try {
            await file.rename(newFile.path);
          } on FileSystemException {
            if (!context.mounted) return;
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not rename mindmap.')),
            );
            return;
          }

          if (!context.mounted) return;
          Navigator.of(dialogContext).pop(true);
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Rename mindmap'),
          content: TextFormField(
            initialValue: baseName,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Mindmap name',
              errorText: alreadyExists
                  ? 'A mindmap with this name already exists.'
                  : null,
            ),
            onChanged: (value) {
              nextName = value;
              if (alreadyExists) {
                alreadyExists = false;
                if (dialogElement.mounted) dialogElement.markNeedsBuild();
              }
            },
            onFieldSubmitted: (_) {
              FocusScope.of(dialogContext).unfocus();
              Future<void>.microtask(tryRename);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async => tryRename(),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    if (shouldRename == true && mounted) _loadMindmaps();
  }

  Future<void> _deleteMindmap(File file) async {
    final name = file.path.split(Platform.pathSeparator).last;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: const Text('Delete mindmap'),
        content: Text('Delete "$name" permanently? This cannot be undone.'),
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

    if (shouldDelete != true) return;

    try {
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete mindmap.')),
      );
      return;
    }

    if (mounted) _loadMindmaps();
  }

  void _loadMindmaps() {
    if (!_mindmapsDirectory.existsSync()) {
      _mindmapsDirectory.createSync(recursive: true);
      setState(() {
        _mindmapFiles = const [];
      });
      return;
    }

    final files =
        _mindmapsDirectory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.json'))
            .toList()
          ..sort((first, second) => first.path.compareTo(second.path));

    setState(() {
      _mindmapFiles = files;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[100],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Mindmaps',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[900],
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${_mindmapFiles.length} ${_mindmapFiles.length == 1 ? "file" : "files"}',
                          style: TextStyle(
                            color: Colors.blueGrey[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 18),
                Material(
                  color: Colors.blueGrey[100],
                  borderRadius: BorderRadius.circular(5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(5),
                    onTap: _createMindmap,
                    splashColor: Colors.blueGrey[200],
                    highlightColor: Colors.blueGrey[300],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add, color: Colors.blueGrey[900]),
                          SizedBox(width: 8),
                          Text(
                            'New Mindmap',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 18),
                Material(
                  color: Colors.blueGrey[100],
                  borderRadius: BorderRadius.circular(5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(5),
                    onTap: _loadMindmaps,
                    splashColor: Colors.blueGrey[200],
                    highlightColor: Colors.blueGrey[300],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.refresh, color: Colors.blueGrey[900]),
                          SizedBox(width: 8),
                          Text(
                            'Refresh',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 17),
            Expanded(
              child: _mindmapFiles.isEmpty
                  ? Center(
                      child: Text(
                        'No mindmaps yet.',
                        style: TextStyle(
                          color: Colors.blueGrey[500],
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _mindmapFiles.length,
                      itemBuilder: (context, index) {
                        final mindmapFile = _mindmapFiles[index];
                        return MindmapTile(
                          name: mindmapFile.path
                              .split(Platform.pathSeparator)
                              .last
                              .split('.')
                              .first,
                          onTap: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        Mindmap(mindmapFile: mindmapFile),
                                  ),
                                )
                                .then((_) => _loadMindmaps());
                          },
                          onRename: () => _renameMindmap(mindmapFile),
                          onDelete: () => _deleteMindmap(mindmapFile),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

//mindmap list tile
class MindmapTile extends StatelessWidget {
  const MindmapTile({
    super.key,
    required this.name,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final String name;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Material(
        color: Colors.blueGrey[300],
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: onTap,
          child: ListTile(
            leading: Icon(Icons.map, color: Colors.white),
            title: Text(
              name,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  tooltip: 'Rename mindmap',
                  onPressed: onRename,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  tooltip: 'Delete mindmap',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: camel_case_types
class database extends StatefulWidget {
  const database({
    super.key,
    required this.projectName,
    required this.projectFolder,
  });

  final String projectName;
  final Directory projectFolder;

  @override
  State<database> createState() => _databaseState();
}

// ignore: camel_case_types
class _databaseState extends State<database> {
  late final Directory _databaseDirectory;
  List<File> _databaseFiles = const [];
  final TextEditingController _databaseNameController = TextEditingController();

  @override
  void dispose() {
    _databaseNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _databaseDirectory = Directory(
      '${widget.projectFolder.path}${Platform.pathSeparator}Database',
    );
    _loadDatabaseFiles();
  }

  void _loadDatabaseFiles() {
    if (!_databaseDirectory.existsSync()) {
      _databaseDirectory.createSync(recursive: true);
      setState(() {
        _databaseFiles = const [];
      });
      return;
    }

    final files =
        _databaseDirectory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.json'))
            .toList()
          ..sort((first, second) => first.path.compareTo(second.path));

    setState(() {
      _databaseFiles = files;
    });
  }

  Future<void> _createDatabaseFile() async {
    var alreadyExists = false;
    String? createError;
    _databaseNameController.clear();

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> tryCreate() async {
              final rawName = _databaseNameController.text.trim();
              if (rawName.isEmpty) return;

              if (rawName.contains(RegExp(r'[<>:"/\\|?*]'))) {
                setDialogState(() {
                  createError = 'Name contains invalid characters.';
                });
                return;
              }

              final fileName = rawName.endsWith('.json')
                  ? rawName
                  : '$rawName.json';
              final filePath =
                  '${_databaseDirectory.path}${Platform.pathSeparator}$fileName';

              if (File(filePath).existsSync()) {
                setDialogState(() {
                  alreadyExists = true;
                  createError = null;
                });
                return;
              }

              try {
                if (!_databaseDirectory.existsSync()) {
                  _databaseDirectory.createSync(recursive: true);
                }
                await File(filePath).writeAsString('{"tables":[]}');
              } on FileSystemException {
                setDialogState(() {
                  createError = 'Could not create database file.';
                });
                return;
              }

              if (!mounted) return;
              // ignore: use_build_context_synchronously
              Navigator.of(dialogContext).pop(true);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              title: const Text('Create Database'),
              content: TextField(
                controller: _databaseNameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Database name',
                  hintText: 'my-database',
                  errorText: alreadyExists
                      ? 'A database with this name already exists.'
                      : createError,
                ),
                onChanged: (_) {
                  if (alreadyExists || createError != null) {
                    setDialogState(() {
                      alreadyExists = false;
                      createError = null;
                    });
                  }
                },
                onSubmitted: (_) async => tryCreate(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async => tryCreate(),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldCreate == true && mounted) {
      _loadDatabaseFiles();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Database file created.')));
    }
  }

  Future<void> _renameDatabaseFile(File file) async {
    var alreadyExists = false;
    final currentName = file.path.split(Platform.pathSeparator).last;
    final baseName = currentName.endsWith('.json')
        ? currentName.substring(0, currentName.length - 5)
        : currentName;
    var nextName = baseName;

    final shouldRename = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogElement = dialogContext as Element;

        Future<void> tryRename() async {
          final raw = nextName.trim();
          if (raw.isEmpty || raw == baseName) return;

          if (raw.contains(RegExp(r'[<>:"/\\|?*]'))) {
            alreadyExists = false;
            dialogElement.markNeedsBuild();
            return;
          }

          final newFileName = raw.endsWith('.json') ? raw : '$raw.json';

          final existingNames = _databaseFiles
              .map(
                (f) => f.path
                    .split(RegExp(r'[/\\]'))
                    .where((s) => s.isNotEmpty)
                    .last
                    .toLowerCase(),
              )
              .toList();

          if (existingNames.contains(newFileName.toLowerCase()) &&
              newFileName.toLowerCase() != currentName.toLowerCase()) {
            alreadyExists = true;
            if (dialogElement.mounted) dialogElement.markNeedsBuild();
            return;
          }

          final newFile = File(
            '${file.parent.path}${Platform.pathSeparator}$newFileName',
          );

          try {
            await file.rename(newFile.path);
          } on FileSystemException {
            if (!context.mounted) return;
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not rename database file.')),
            );
            return;
          }

          if (!context.mounted) return;
          Navigator.of(dialogContext).pop(true);
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Rename database file'),
          content: TextFormField(
            initialValue: baseName,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Database name',
              errorText: alreadyExists
                  ? 'A database with this name already exists.'
                  : null,
            ),
            onChanged: (value) {
              nextName = value;
              if (alreadyExists) {
                alreadyExists = false;
                if (dialogElement.mounted) dialogElement.markNeedsBuild();
              }
            },
            onFieldSubmitted: (_) {
              FocusScope.of(dialogContext).unfocus();
              Future<void>.microtask(tryRename);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async => tryRename(),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    if (shouldRename == true && mounted) {
      _loadDatabaseFiles();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Database file renamed.')));
    }
  }

  Future<void> _deleteDatabaseFile(File file) async {
    final name = file.path.split(Platform.pathSeparator).last;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: const Text('Delete database file'),
        content: Text('Delete "$name" permanently? This cannot be undone.'),
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

    if (shouldDelete != true) return;

    try {
      if (file.existsSync()) {
        await file.delete();
      }
    } on FileSystemException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete database file.')),
      );
      return;
    }

    if (mounted) {
      _loadDatabaseFiles();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Database file deleted.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[100],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      'Database',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 18),
                Material(
                  color: Colors.blueGrey[100],
                  borderRadius: BorderRadius.circular(5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(5),
                    onTap: _createDatabaseFile,
                    splashColor: Colors.blueGrey[200],
                    highlightColor: Colors.blueGrey[300],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add, color: Colors.blueGrey[900]),
                          SizedBox(width: 8),
                          Text(
                            'Create Local Database',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 18),

                Material(
                  color: Colors.blueGrey[100],
                  borderRadius: BorderRadius.circular(5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(5),
                    onTap: _loadDatabaseFiles,
                    splashColor: Colors.blueGrey[200],
                    highlightColor: Colors.blueGrey[300],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.refresh, color: Colors.blueGrey[900]),
                          SizedBox(width: 8),
                          Text(
                            'Refresh',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 17),
            Expanded(
              child: _databaseFiles.isEmpty
                  ? Center(
                      child: Text(
                        'No database files yet.',
                        style: TextStyle(
                          color: Colors.blueGrey[500],
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _databaseFiles.length,
                      itemBuilder: (context, index) {
                        final file = _databaseFiles[index];
                        final fileName = file.path
                            .split(Platform.pathSeparator)
                            .last;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Material(
                            color: Colors.blueGrey[300],
                            borderRadius: BorderRadius.circular(5),
                            child: ListTile(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        Database(databaseFile: file.path),
                                  ),
                                );
                              },
                              leading: Icon(Icons.storage, color: Colors.white),
                              title: Text(
                                fileName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                    ),
                                    tooltip: 'Rename database file',
                                    onPressed: () => _renameDatabaseFile(file),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                    ),
                                    tooltip: 'Delete database file',
                                    onPressed: () => _deleteDatabaseFile(file),
                                  ),
                                ],
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
    );
  }
}
