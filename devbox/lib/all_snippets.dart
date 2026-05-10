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
              value: currentTarget,
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSnippets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All snippets'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Refresh snippets',
              onPressed: _loadSnippets,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: Container(
        color: Colors.blueGrey[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red[700]),
                  ),
                )
              : _snippets.isEmpty
              ? Center(
                  child: Text(
                    'No snippets found in project JSON files.',
                    style: TextStyle(color: Colors.blueGrey[600], fontSize: 16),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${filtered.length} shown of ${_snippets.length} ${_snippets.length == 1 ? 'snippet' : 'snippets'}',
                      style: TextStyle(
                        color: Colors.blueGrey[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedProject,
                            decoration: const InputDecoration(
                              labelText: 'Project',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _projectFilters
                                .map(
                                  (project) => DropdownMenuItem<String>(
                                    value: project,
                                    child: Text(project),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedProject = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<_DateFilter>(
                            value: _selectedDateFilter,
                            decoration: const InputDecoration(
                              labelText: 'Date added',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _DateFilter.values
                                .map(
                                  (filter) => DropdownMenuItem<_DateFilter>(
                                    value: filter,
                                    child: Text(_dateFilterLabel(filter)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedDateFilter = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
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
                                    .join('  ');

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    title: Text(
                                      item.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            Chip(
                                              label: Text(item.projectName),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            Chip(
                                              label: Text(
                                                'added ${_formatDate(item.createdAtDate)}',
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            Chip(
                                              label: Text(
                                                item.language.isEmpty
                                                    ? 'unknown'
                                                    : item.language,
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          preview.isEmpty
                                              ? '(empty code)'
                                              : preview,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            color: Colors.blueGrey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Copy code',
                                          onPressed: () => _copySnippet(item),
                                          icon: const Icon(Icons.copy),
                                        ),
                                        IconButton(
                                          tooltip: 'Move snippet',
                                          onPressed: () => _moveSnippet(item),
                                          icon: const Icon(
                                            Icons.drive_file_move_outline,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Edit snippet',
                                          onPressed: () => _editSnippet(item),
                                          icon: const Icon(Icons.edit),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete snippet',
                                          onPressed: () => _deleteSnippet(item),
                                          icon: const Icon(Icons.delete),
                                        ),
                                      ],
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
              value: _selectedLanguage,
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
