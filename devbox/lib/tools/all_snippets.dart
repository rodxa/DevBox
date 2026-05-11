import 'dart:io';

import 'package:devbox/snippet_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AllSnippetsPage extends StatefulWidget {
  const AllSnippetsPage({super.key, required this.contentFolder});

  final Directory contentFolder;

  @override
  State<AllSnippetsPage> createState() => _AllSnippetsPageState();
}

class _AllSnippetsPageState extends State<AllSnippetsPage> {
  static const String _allProjectsFilter = 'All projects';

  final List<_SnippetItem> _snippets = <_SnippetItem>[];
  final List<String> _projectFilters = <String>[_allProjectsFilter];
  bool _isLoading = true;
  String? _error;
  String _selectedProject = _allProjectsFilter;
  _DateFilter _selectedDateFilter = _DateFilter.all;

  @override
  void initState() {
    super.initState();
    _loadSnippets();
  }

  Future<void> _loadSnippets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (!widget.contentFolder.existsSync()) {
        setState(() {
          _snippets.clear();
          _isLoading = false;
        });
        return;
      }

      final loaded = <_SnippetItem>[];
      final globalFile = getGlobalSnippetsFile();
      if (globalFile.existsSync()) {
        try {
          final globalSnippets = readSnippetsFromFile(globalFile);
          for (final snippet in globalSnippets) {
            final title = (snippet['title'] ?? '').trim();
            final code = snippet['code'] ?? '';
            if (title.isEmpty && code.trim().isEmpty) {
              continue;
            }

            loaded.add(
              _SnippetItem(
                projectName: globalSnippetBucketName,
                title: title.isEmpty ? 'Snippet' : title,
                language: (snippet['language'] ?? '').trim(),
                code: code,
                createdAt: (snippet[snippetCreatedAtField] ?? '').trim(),
                sourceFilePath: globalFile.path,
              ),
            );
          }
        } on FormatException {
          // Ignore malformed JSON files and continue loading snippets.
        } on FileSystemException {
          // Ignore unreadable files and continue loading snippets.
        }
      }

      final projects = widget.contentFolder
          .listSync()
          .whereType<Directory>()
          .toList();

      for (final project in projects) {
        final projectName = project.path.split(Platform.pathSeparator).last;
        final candidateFiles = <String>[
          '${project.path}${Platform.pathSeparator}snippets${Platform.pathSeparator}snippets.json',
          '${project.path}${Platform.pathSeparator}Snippets${Platform.pathSeparator}snippets.json',
        ];
        final seenPaths = <String>{};

        for (final path in candidateFiles) {
          final normalizedPath = path.toLowerCase();
          if (!seenPaths.add(normalizedPath)) {
            continue;
          }

          final file = File(path);
          if (!file.existsSync()) {
            continue;
          }

          try {
            final snippets = readSnippetsFromFile(file);
            for (final map in snippets) {
              final title = (map['title'] ?? '').trim();
              final language = (map['language'] ?? '').trim();
              final code = map['code'] ?? '';

              if (title.isEmpty && code.trim().isEmpty) {
                continue;
              }

              loaded.add(
                _SnippetItem(
                  projectName: projectName,
                  title: title.isEmpty ? 'Snippet' : title,
                  language: language,
                  code: code,
                  createdAt: (map[snippetCreatedAtField] ?? '').trim(),
                  sourceFilePath: file.path,
                ),
              );
            }
          } on FormatException {
            // Ignore malformed JSON files and continue loading other projects.
          } on FileSystemException {
            // Ignore unreadable files and continue loading other projects.
          }
        }
      }

      loaded.sort((a, b) {
        final aDate = a.createdAtDate;
        final bDate = b.createdAtDate;
        if (aDate != null && bDate != null) {
          final byDate = bDate.compareTo(aDate);
          if (byDate != 0) {
            return byDate;
          }
        } else if (aDate != null) {
          return -1;
        } else if (bDate != null) {
          return 1;
        }

        final byProject = a.projectName.toLowerCase().compareTo(
          b.projectName.toLowerCase(),
        );
        if (byProject != 0) {
          return byProject;
        }
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

      setState(() {
        _snippets
          ..clear()
          ..addAll(loaded);
        _projectFilters
          ..clear()
          ..add(_allProjectsFilter)
          ..addAll(
            loaded.map((snippet) => snippet.projectName).toSet().toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
          );
        if (!_projectFilters.contains(_selectedProject)) {
          _selectedProject = _allProjectsFilter;
        }
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not load snippets.';
        _isLoading = false;
      });
    }
  }

  Future<void> _copySnippet(_SnippetItem item) async {
    await Clipboard.setData(ClipboardData(text: item.code));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied "${item.title}" from ${item.projectName}.'),
      ),
    );
  }

  Future<void> _moveSnippet(_SnippetItem item) async {
    final allTargets = <_MoveTarget>[const _MoveTarget.global()];
    for (final folder in listProjectFolders(
      contentFolder: widget.contentFolder,
    )) {
      final name = folder.path.split(Platform.pathSeparator).last;
      allTargets.add(_MoveTarget.project(name: name, folder: folder));
    }

    final targets = allTargets.where((target) {
      final destinationFile = target.isGlobal
          ? getGlobalSnippetsFile()
          : getProjectSnippetsFile(target.folder!);
      return destinationFile.path.toLowerCase() !=
          item.sourceFilePath.toLowerCase();
    }).toList();

    if (targets.isEmpty) {
      return;
    }

    final selectedTarget = await showDialog<_MoveTarget>(
      context: context,
      builder: (dialogContext) {
        _MoveTarget currentTarget = targets.first;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            title: const Text('Move snippet'),
            content: DropdownButtonFormField<_MoveTarget>(
              initialValue: currentTarget,
              decoration: const InputDecoration(labelText: 'Destination'),
              items: targets
                  .map(
                    (target) => DropdownMenuItem<_MoveTarget>(
                      value: target,
                      child: Text(target.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setDialogState(() {
                  currentTarget = value;
                });
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(currentTarget),
                child: const Text('Move'),
              ),
            ],
          ),
        );
      },
    );

    if (selectedTarget == null) {
      return;
    }

    final sourceFile = File(item.sourceFilePath);
    final destinationFile = selectedTarget.isGlobal
        ? getGlobalSnippetsFile()
        : getProjectSnippetsFile(selectedTarget.folder!);

    final snippetData = <String, String>{
      'title': item.title,
      'language': item.language,
      'code': item.code,
      snippetCreatedAtField: item.createdAt,
    };

    final removed = removeExactSnippetFromFile(sourceFile, snippetData);
    if (!removed) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not move snippet from source file.'),
        ),
      );
      return;
    }

    final savedTitle = addSnippetToFile(destinationFile, snippetData);
    await _loadSnippets();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Moved "$savedTitle" to ${selectedTarget.name}.')),
    );
  }

  Future<void> _deleteSnippet(_SnippetItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: const Text('Delete snippet'),
        content: Text(
          'Delete "${item.title}" from ${item.projectName}? This cannot be undone.',
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
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    final sourceFile = File(item.sourceFilePath);
    final removed = removeExactSnippetFromFile(sourceFile, {
      'title': item.title,
      'language': item.language,
      'code': item.code,
      snippetCreatedAtField: item.createdAt,
    });

    if (!removed) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete snippet.')),
      );
      return;
    }

    await _loadSnippets();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Deleted "${item.title}".')));
  }

  Future<void> _editSnippet(_SnippetItem item) async {
    final sourceFile = File(item.sourceFilePath);
    final existingTitles = readSnippetsFromFile(sourceFile)
        .where(
          (snippet) =>
              (snippet['title'] ?? '') != item.title ||
              (snippet['language'] ?? '') != item.language ||
              (snippet['code'] ?? '') != item.code ||
              (snippet[snippetCreatedAtField] ?? '') != item.createdAt,
        )
        .map((snippet) => (snippet['title'] ?? '').trim())
        .toList();

    final edited = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _AllSnippetsEditorDialog(
        initialTitle: item.title,
        initialLanguage: item.language,
        initialCode: item.code,
        existingTitles: existingTitles,
      ),
    );

    if (edited == null) {
      return;
    }

    final oldSnippetData = <String, String>{
      'title': item.title,
      'language': item.language,
      'code': item.code,
      snippetCreatedAtField: item.createdAt,
    };

    final removed = removeExactSnippetFromFile(sourceFile, oldSnippetData);
    if (!removed) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update snippet.')),
      );
      return;
    }

    final savedTitle = addSnippetToFile(sourceFile, {
      ...edited,
      snippetCreatedAtField: item.createdAt,
    });
    await _loadSnippets();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Updated "$savedTitle".')));
  }

  _MoveTarget? _targetFromSelectedProject() {
    final selected = _selectedProject;
    if (selected == _allProjectsFilter) {
      return null;
    }
    if (selected == globalSnippetBucketName) {
      return const _MoveTarget.global();
    }

    final folders = listProjectFolders(contentFolder: widget.contentFolder);
    for (final folder in folders) {
      final name = folder.path.split(Platform.pathSeparator).last;
      if (name.toLowerCase() == selected.toLowerCase()) {
        return _MoveTarget.project(name: name, folder: folder);
      }
    }

    return null;
  }

  Future<_MoveTarget?> _pickAddTarget() async {
    final preselected = _targetFromSelectedProject();
    if (preselected != null) {
      return preselected;
    }

    final targets = <_MoveTarget>[const _MoveTarget.global()];
    for (final folder in listProjectFolders(
      contentFolder: widget.contentFolder,
    )) {
      final name = folder.path.split(Platform.pathSeparator).last;
      targets.add(_MoveTarget.project(name: name, folder: folder));
    }

    if (targets.isEmpty) {
      return null;
    }

    return showDialog<_MoveTarget>(
      context: context,
      builder: (dialogContext) {
        _MoveTarget currentTarget = targets.first;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            title: const Text('Add snippet to'),
            content: DropdownButtonFormField<_MoveTarget>(
              initialValue: currentTarget,
              decoration: const InputDecoration(labelText: 'Destination'),
              items: targets
                  .map(
                    (target) => DropdownMenuItem<_MoveTarget>(
                      value: target,
                      child: Text(target.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setDialogState(() {
                  currentTarget = value;
                });
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(currentTarget),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addSnippet() async {
    final target = await _pickAddTarget();
    if (target == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final destinationFile = target.isGlobal
        ? getGlobalSnippetsFile()
        : getProjectSnippetsFile(target.folder!);

    final existingTitles = readSnippetsFromFile(destinationFile)
        .map((snippet) => (snippet['title'] ?? '').trim())
        .where((title) => title.isNotEmpty)
        .toList();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _AllSnippetsEditorDialog(
        initialTitle: '',
        initialLanguage: '',
        initialCode: '',
        existingTitles: existingTitles,
      ),
    );

    if (result == null) {
      return;
    }

    final savedTitle = addSnippetToFile(destinationFile, {
      ...result,
      snippetCreatedAtField: nowIsoTimestamp(),
    });

    await _loadSnippets();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "$savedTitle" to ${target.name}.')),
    );
  }

  List<_SnippetItem> get _filteredSnippets {
    return _snippets.where((snippet) {
      final matchesProject =
          _selectedProject == _allProjectsFilter ||
          snippet.projectName == _selectedProject;
      if (!matchesProject) {
        return false;
      }

      switch (_selectedDateFilter) {
        case _DateFilter.all:
          return true;
        case _DateFilter.today:
          final created = snippet.createdAtDate;
          if (created == null) {
            return false;
          }
          final now = DateTime.now();
          return created.year == now.year &&
              created.month == now.month &&
              created.day == now.day;
        case _DateFilter.last7Days:
          final created = snippet.createdAtDate;
          if (created == null) {
            return false;
          }
          return created.isAfter(
            DateTime.now().subtract(const Duration(days: 7)),
          );
        case _DateFilter.last30Days:
          final created = snippet.createdAtDate;
          if (created == null) {
            return false;
          }
          return created.isAfter(
            DateTime.now().subtract(const Duration(days: 30)),
          );
        case _DateFilter.noDate:
          return snippet.createdAtDate == null;
      }
    }).toList();
  }

  String _dateFilterLabel(_DateFilter filter) {
    switch (filter) {
      case _DateFilter.all:
        return 'All dates';
      case _DateFilter.today:
        return 'Today';
      case _DateFilter.last7Days:
        return 'Last 7 days';
      case _DateFilter.last30Days:
        return 'Last 30 days';
      case _DateFilter.noDate:
        return 'No date';
    }
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return 'unknown';
    }
    final local = dateTime.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Widget _buildToolbarAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.blueGrey[100],
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onTap,
        splashColor: Colors.blueGrey[200],
        highlightColor: Colors.blueGrey[300],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: Colors.blueGrey[900]),
              const SizedBox(width: 8),
              Text(
                label,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSnippets;

    return Scaffold(
      body: Container(
        color: Colors.blueGrey[50],
        child: Row(
          children: [
            Container(
              width: 220,
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
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          color: Colors.white,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'All snippets',
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${filtered.length} shown',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedProject,
                      decoration: InputDecoration(
                        labelText: 'Project',
                        labelStyle: TextStyle(color: Colors.blueGrey[100]),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: BorderSide(
                            color: Colors.blueGrey.shade600,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: BorderSide(
                            color: Colors.blueGrey.shade300,
                          ),
                        ),
                      ),
                      dropdownColor: Colors.blueGrey[800],
                      style: const TextStyle(color: Colors.white),
                      items: _projectFilters
                          .map(
                            (project) => DropdownMenuItem<String>(
                              value: project,
                              child: Text(project),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedProject = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonFormField<_DateFilter>(
                      initialValue: _selectedDateFilter,
                      decoration: InputDecoration(
                        labelText: 'Date added',
                        labelStyle: TextStyle(color: Colors.blueGrey[100]),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: BorderSide(
                            color: Colors.blueGrey.shade600,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: BorderSide(
                            color: Colors.blueGrey.shade300,
                          ),
                        ),
                      ),
                      dropdownColor: Colors.blueGrey[800],
                      style: const TextStyle(color: Colors.white),
                      items: _DateFilter.values
                          .map(
                            (filter) => DropdownMenuItem<_DateFilter>(
                              value: filter,
                              child: Text(_dateFilterLabel(filter)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedDateFilter = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey[800],
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filters',
                              style: TextStyle(
                                color: Colors.blueGrey[100],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Use project and date filters to narrow the snippet list.',
                              style: TextStyle(color: Colors.blueGrey[300]),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Use',
                              style: TextStyle(
                                color: Colors.blueGrey[100],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'for adding snippets, select text on any application and use Alt + D or press the add snippet button.',
                              style: TextStyle(color: Colors.blueGrey[300]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
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
                              _error != null
                                  ? 'All snippets'
                                  : '${filtered.length} shown of ${_snippets.length} ${_snippets.length == 1 ? 'snippet' : 'snippets'}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[900],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        _buildToolbarAction(
                          icon: Icons.add,
                          label: 'Add Snippet',
                          onTap: _addSnippet,
                        ),
                        const SizedBox(width: 18),
                        _buildToolbarAction(
                          icon: Icons.refresh,
                          label: 'Refresh',
                          onTap: _loadSnippets,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _error!,
                                    style: TextStyle(color: Colors.red[700]),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: _loadSnippets,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _snippets.isEmpty
                          ? Center(
                              child: Text(
                                'No snippets yet.',
                                style: TextStyle(
                                  color: Colors.blueGrey[500],
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No snippets match the selected filters.',
                                style: TextStyle(
                                  color: Colors.blueGrey[600],
                                  fontSize: 15,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                final preview = item.code
                                    .split('\n')
                                    .where((line) => line.trim().isNotEmpty)
                                    .take(2)
                                    .join(' ');
                                final language = item.language.isEmpty
                                    ? 'unknown'
                                    : item.language;
                                final details =
                                    '$language  •  ${item.projectName}  •  added ${_formatDate(item.createdAtDate)}';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Material(
                                    color: Colors.blueGrey[200],
                                    borderRadius: BorderRadius.circular(5),
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.code,
                                        color: Colors.blueGrey[800],
                                      ),
                                      title: Text(
                                        item.title,
                                        style: TextStyle(
                                          color: Colors.blueGrey[900],
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        preview.isEmpty
                                            ? details
                                            : '$details\n$preview',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.blueGrey[700],
                                          fontSize: 13,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Copy snippet code',
                                            onPressed: () => _copySnippet(item),
                                            icon: Icon(
                                              Icons.copy,
                                              color: Colors.blueGrey[600],
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Edit snippet',
                                            onPressed: () => _editSnippet(item),
                                            icon: Icon(
                                              Icons.edit,
                                              color: Colors.blueGrey[600],
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Move snippet',
                                            onPressed: () => _moveSnippet(item),
                                            icon: Icon(
                                              Icons.drive_file_move_outline,
                                              color: Colors.blueGrey[600],
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: 'Delete snippet',
                                            onPressed: () =>
                                                _deleteSnippet(item),
                                            icon: Icon(
                                              Icons.delete,
                                              color: Colors.blueGrey[700],
                                            ),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _SnippetItem {
  const _SnippetItem({
    required this.projectName,
    required this.title,
    required this.language,
    required this.code,
    required this.createdAt,
    required this.sourceFilePath,
  });

  final String projectName;
  final String title;
  final String language;
  final String code;
  final String createdAt;
  final String sourceFilePath;

  DateTime? get createdAtDate => DateTime.tryParse(createdAt);
}

class _MoveTarget {
  const _MoveTarget.global()
    : name = globalSnippetBucketName,
      folder = null,
      isGlobal = true;

  const _MoveTarget.project({required this.name, required this.folder})
    : isGlobal = false;

  final String name;
  final Directory? folder;
  final bool isGlobal;
}

enum _DateFilter { all, today, last7Days, last30Days, noDate }

class _AllSnippetsEditorDialog extends StatefulWidget {
  const _AllSnippetsEditorDialog({
    required this.initialTitle,
    required this.initialLanguage,
    required this.initialCode,
    required this.existingTitles,
  });

  final String initialTitle;
  final String initialLanguage;
  final String initialCode;
  final List<String> existingTitles;

  @override
  State<_AllSnippetsEditorDialog> createState() =>
      _AllSnippetsEditorDialogState();
}

class _AllSnippetsEditorDialogState extends State<_AllSnippetsEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _codeController;
  late String _selectedLanguage;
  String? _titleError;

  List<String> get _languageOptions {
    final options = <String>[...snippetLanguageOptions];
    final current = _selectedLanguage.trim();
    final hasCurrent = options.any(
      (option) => option.toLowerCase() == current.toLowerCase(),
    );
    if (current.isNotEmpty && !hasCurrent) {
      options.add(current);
    }
    return options;
  }

  String _normalizeLanguage(String value) {
    final trimmed = value.trim();
    for (final option in snippetLanguageOptions) {
      if (option.toLowerCase() == trimmed.toLowerCase()) {
        return option;
      }
    }
    return trimmed;
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _codeController = TextEditingController(text: widget.initialCode);
    _selectedLanguage = _normalizeLanguage(widget.initialLanguage);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final language = _normalizeLanguage(_selectedLanguage);
    final code = _codeController.text;

    if (title.isEmpty) {
      setState(() {
        _titleError = 'Title is required.';
      });
      return;
    }

    final isDuplicate = widget.existingTitles.any(
      (existing) => existing.toLowerCase() == title.toLowerCase(),
    );
    if (isDuplicate) {
      setState(() {
        _titleError = 'A snippet with this title already exists.';
      });
      return;
    }

    Navigator.of(
      context,
    ).pop({'title': title, 'language': language, 'code': code});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      title: const Text('Edit snippet'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Title',
                errorText: _titleError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              onChanged: (_) {
                if (_titleError != null) {
                  setState(() {
                    _titleError = null;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedLanguage,
              decoration: InputDecoration(
                labelText: 'Language (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              items: _languageOptions
                  .map(
                    (language) => DropdownMenuItem<String>(
                      value: language,
                      child: Text(language.isEmpty ? 'None' : language),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedLanguage = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Flexible(
              child: TextField(
                controller: _codeController,
                minLines: 10,
                maxLines: 16,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: 'Code',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
