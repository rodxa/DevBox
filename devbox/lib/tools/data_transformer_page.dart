import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devbox/snippet_storage.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

class DataTransformerPage extends StatefulWidget {
  const DataTransformerPage({super.key});

  @override
  State<DataTransformerPage> createState() => _DataTransformerPageState();
}

class _DataTransformerPageState extends State<DataTransformerPage> {
  static const String _projectsFileName = 'data_transformer_projects.json';
  static const List<_ExportFormat> _exportFormats = <_ExportFormat>[
    _ExportFormat(id: 'txt', label: 'Plain text (.txt)', extension: 'txt'),
    _ExportFormat(id: 'jsonPretty', label: 'JSON pretty (.json)', extension: 'json'),
    _ExportFormat(id: 'jsonMin', label: 'JSON minified (.json)', extension: 'json'),
    _ExportFormat(id: 'csv', label: 'CSV (.csv)', extension: 'csv'),
    _ExportFormat(id: 'tsv', label: 'TSV (.tsv)', extension: 'tsv'),
    _ExportFormat(id: 'md', label: 'Markdown (.md)', extension: 'md'),
    _ExportFormat(id: 'html', label: 'HTML (.html)', extension: 'html'),
    _ExportFormat(id: 'xml', label: 'XML (.xml)', extension: 'xml'),
    _ExportFormat(id: 'log', label: 'Log (.log)', extension: 'log'),
    _ExportFormat(id: 'yaml', label: 'YAML-like (.yaml)', extension: 'yaml'),
  ];
  static const List<String> _changeTemplates = <String>[
    'uppercase',
    'lowercase',
    'trim lines',
    'remove empty lines',
    'remove duplicate lines',
    'keep line(s)',
    'remove line(s)',
    'keep lines containing',
    'remove lines containing',
    'sort lines',
    'replace',
    'insert text',
    'prefix',
    'suffix',
    'json pretty',
    'json minify',
  ];

  final JsonEncoder _encoder = const JsonEncoder.withIndent('  ');
  final TextEditingController _inputController = TextEditingController();

  List<_TransformerProject> _projects = <_TransformerProject>[];
  String? _selectedProjectId;
  bool _isLoading = true;
  bool _isDropActive = false;
  String? _error;
  TextSelection _inputSelection = const TextSelection.collapsed(offset: 0);
  Timer? _pendingInputSave;
  bool _isSyncingInputController = false;

  _TransformerProject? get _selectedProject {
    final selectedId = _selectedProjectId;
    if (selectedId == null) return null;
    for (final project in _projects) {
      if (project.id == selectedId) {
        return project;
      }
    }
    return null;
  }

  File get _projectsFile => File(
    '${getDevboxContentFolder().path}${Platform.pathSeparator}$_projectsFileName',
  );

  String get _outputPreview {
    final project = _selectedProject;
    if (project == null) return '';
    return _applyChanges(project.inputContent, project.changeRequests);
  }

  String get _inputCaretLabel {
    final location = _linePositionFromOffset(
      _inputController.text,
      _inputSelection.extentOffset,
    );
    return 'Ln ${location.line}, Pos ${location.position}';
  }

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_handleInputControllerChanged);
    _loadProjects();
  }

  @override
  void dispose() {
    _pendingInputSave?.cancel();
    _inputController.removeListener(_handleInputControllerChanged);
    _inputController.dispose();
    super.dispose();
  }

  void _handleInputControllerChanged() {
    final selection = _inputController.selection;

    if (_isSyncingInputController) {
      if (selection != _inputSelection && mounted) {
        setState(() {
          _inputSelection = selection;
        });
      }
      return;
    }

    final selectedProject = _selectedProject;
    final text = _inputController.text;
    final selectionChanged = selection != _inputSelection;
    final textChanged =
        selectedProject != null && text != selectedProject.inputContent;

    if (!selectionChanged && !textChanged) {
      return;
    }

    setState(() {
      if (selectionChanged) {
        _inputSelection = selection;
      }
      if (textChanged) {
        _projects = _projects.map((project) {
          if (project.id != selectedProject.id) {
            return project;
          }
          return project.copyWith(inputContent: text);
        }).toList();
      }
    });

    if (textChanged) {
      _scheduleInputSave();
    }
  }

  void _scheduleInputSave() {
    _pendingInputSave?.cancel();
    _pendingInputSave = Timer(const Duration(milliseconds: 300), () async {
      try {
        await _saveProjects();
      } catch (_) {
        // Ignore transient save issues while typing.
      }
    });
  }

  void _syncInputControllerToSelectedProject() {
    final content = _selectedProject?.inputContent ?? '';

    _isSyncingInputController = true;
    _inputController.value = TextEditingValue(
      text: content,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _isSyncingInputController = false;

    if (!mounted) {
      return;
    }

    setState(() {
      _inputSelection = _inputController.selection;
    });
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = _projectsFile;
      if (!file.existsSync()) {
        await file.create(recursive: true);
        await file.writeAsString('{"projects":[]}');
      }

      final raw = await file.readAsString();
      final decoded = raw.trim().isEmpty
          ? <String, dynamic>{'projects': <dynamic>[]}
          : jsonDecode(raw);

      if (decoded is! Map) {
        throw const FormatException('Invalid projects JSON');
      }

      final payload = Map<String, dynamic>.from(decoded);
      final rawProjects = payload['projects'];
      final loaded = <_TransformerProject>[];

      if (rawProjects is List) {
        for (final item in rawProjects) {
          if (item is Map<String, dynamic>) {
            final parsed = _TransformerProject.fromJson(item);
            if (parsed.name.isNotEmpty) {
              loaded.add(parsed);
            }
          } else if (item is Map) {
            final parsed = _TransformerProject.fromJson(
              Map<String, dynamic>.from(item),
            );
            if (parsed.name.isNotEmpty) {
              loaded.add(parsed);
            }
          }
        }
      }

      setState(() {
        _projects = loaded;
        _selectedProjectId = loaded.isEmpty ? null : loaded.first.id;
        _isLoading = false;
      });
      _syncInputControllerToSelectedProject();
    } catch (_) {
      setState(() {
        _isLoading = false;
        _error = 'Could not load data transformer projects.';
      });
      _syncInputControllerToSelectedProject();
    }
  }

  Future<void> _saveProjects() async {
    final payload = <String, dynamic>{
      'projects': _projects.map((project) => project.toJson()).toList(),
    };
    await _projectsFile.writeAsString(_encoder.convert(payload));
  }

  Future<void> _createProject(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      _showMessage('Please enter a project name.');
      return;
    }

    final exists = _projects.any(
      (project) => project.name.toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      _showMessage('A project with this name already exists.');
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = '${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}_$now';
    final project = _TransformerProject(
      id: id,
      name: name,
      sourceFilePath: '',
      inputContent: '',
      changeRequests: <_ChangeBlock>[],
      createdAt: DateTime.now().toIso8601String(),
    );

    setState(() {
      _projects = [..._projects, project];
      _selectedProjectId = project.id;
    });
    _syncInputControllerToSelectedProject();

    await _saveProjects();
    _showMessage('Project "$name" created.');
  }

  Future<void> _showCreateProjectDialog() async {
    var nameValue = '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Add project'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Project name',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => nameValue = value,
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(nameValue),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (name == null) return;
    await _createProject(name);
  }

  Future<void> _renameProject(_TransformerProject project) async {
    var nameValue = project.name;
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Rename project'),
          content: TextFormField(
            initialValue: project.name,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Project name',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => nameValue = value,
            onFieldSubmitted: (value) => Navigator.of(dialogContext).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(nameValue),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (name == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _showMessage('Project name cannot be empty.');
      return;
    }

    final duplicate = _projects.any(
      (entry) =>
          entry.id != project.id &&
          entry.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) {
      _showMessage('A project with this name already exists.');
      return;
    }

    setState(() {
      _projects = _projects.map((entry) {
        if (entry.id != project.id) return entry;
        return entry.copyWith(name: trimmed);
      }).toList();
    });

    await _saveProjects();
    _showMessage('Project renamed.');
  }

  Future<void> _deleteProject(_TransformerProject project) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: const Text('Delete project'),
        content: Text('Delete "${project.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
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
      _projects = _projects.where((entry) => entry.id != project.id).toList();
      if (_selectedProjectId == project.id) {
        _selectedProjectId = _projects.isEmpty ? null : _projects.first.id;
      }
    });
    _syncInputControllerToSelectedProject();

    await _saveProjects();
    _showMessage('Project deleted.');
  }

  Future<void> _uploadFromDroppedItems(List<DropItem> items) async {
    final selectedProject = _selectedProject;
    if (selectedProject == null) {
      _showMessage('Create/select a project first.');
      return;
    }

    String? path;
    for (final item in items) {
      final filePath = item.path;
      if (filePath.trim().isNotEmpty) {
        path = filePath;
        break;
      }
    }

    if (path == null) {
      _showMessage('Could not read dropped file path.');
      return;
    }

    await _uploadFromPath(path);
  }

  Future<void> _uploadFromPath(String rawPath) async {
    final selectedProject = _selectedProject;
    if (selectedProject == null) {
      _showMessage('Create/select a project first.');
      return;
    }

    final path = rawPath.trim();
    if (path.isEmpty) {
      _showMessage('Enter a valid file path.');
      return;
    }

    try {
      final file = File(path);
      if (!file.existsSync()) {
        _showMessage('File not found.');
        return;
      }

      final content = await file.readAsString();

      setState(() {
        _projects = _projects.map((project) {
          if (project.id != selectedProject.id) {
            return project;
          }
          return project.copyWith(
            sourceFilePath: file.path,
            inputContent: content,
          );
        }).toList();
      });
      _syncInputControllerToSelectedProject();

      await _saveProjects();
      _showMessage('File uploaded to ${selectedProject.name}.');
    } catch (_) {
      _showMessage('Could not read that file.');
    }
  }

  Future<void> _pickAndUploadFile() async {
    final selectedProject = _selectedProject;
    if (selectedProject == null) {
      _showMessage('Create/select a project first.');
      return;
    }

    try {
      final file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[],
        confirmButtonText: 'Upload',
      );

      if (file == null) {
        return;
      }

      final path = file.path;
      if (path.trim().isEmpty) {
        return;
      }

      await _uploadFromPath(path);
    } catch (_) {
      _showMessage('Could not open file picker.');
    }
  }

  Future<void> _exportOutput() async {
    final selectedProject = _selectedProject;
    if (selectedProject == null) {
      _showMessage('Create/select a project first.');
      return;
    }

    final output = _outputPreview;

    final selectedFormat = await _showExportFormatDialog();
    if (selectedFormat == null) {
      return;
    }

    final content = _buildExportContent(output, selectedFormat.id);

    try {
      final location = await getSaveLocation(
        suggestedName:
            '${selectedProject.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_output.${selectedFormat.extension}',
        confirmButtonText: 'Export',
      );

      if (location == null) {
        return;
      }

      var savePath = location.path;
      if (!savePath.toLowerCase().endsWith('.${selectedFormat.extension}')) {
        savePath = '$savePath.${selectedFormat.extension}';
      }

      final file = File(savePath);
      await file.writeAsString(content);
      _showMessage('Output exported to $savePath');
    } catch (_) {
      _showMessage('Could not export output file.');
    }
  }

  Future<_ExportFormat?> _showExportFormatDialog() async {
    var selected = _exportFormats.first;

    return showDialog<_ExportFormat>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Export format'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return DropdownButtonFormField<_ExportFormat>(
                initialValue: selected,
                decoration: const InputDecoration(
                  labelText: 'Format',
                  border: OutlineInputBorder(),
                ),
                items: _exportFormats
                    .map(
                      (format) => DropdownMenuItem<_ExportFormat>(
                        value: format,
                        child: Text(format.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    selected = value;
                  });
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(selected),
              child: const Text('Export'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addChangeRequest(String rawType) async {
    final selectedProject = _selectedProject;
    if (selectedProject == null) {
      _showMessage('Create/select a project first.');
      return;
    }

    final type = rawType.trim().toLowerCase();
    if (type.isEmpty) {
      return;
    }

    final block = _ChangeBlock.fromType(type);

    setState(() {
      _projects = _projects.map((project) {
        if (project.id != selectedProject.id) {
          return project;
        }
        final updated = [...project.changeRequests, block];
        return project.copyWith(changeRequests: updated);
      }).toList();
    });

    await _saveProjects();
  }

  Future<void> _showAddChangeDialog() async {
    final selectedProject = _selectedProject;
    if (selectedProject == null) {
      _showMessage('Create/select a project first.');
      return;
    }

    var selectedType = _changeTemplates.first;
    final change = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Add change block'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return DropdownButtonFormField<String>(
                initialValue: selectedType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Block type',
                  border: OutlineInputBorder(),
                ),
                items: _changeTemplates
                    .map(
                      (type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(
                          _displayType(type),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() {
                    selectedType = value;
                  });
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(selectedType),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (change == null) return;
    await _addChangeRequest(change);
  }

  Future<void> _updateChangeRequest(int index, _ChangeBlock updatedBlock) async {
    final selectedProject = _selectedProject;
    if (selectedProject == null ||
        index < 0 ||
        index >= selectedProject.changeRequests.length) {
      return;
    }

    setState(() {
      _projects = _projects.map((project) {
        if (project.id != selectedProject.id) {
          return project;
        }
        final list = [...project.changeRequests];
        list[index] = updatedBlock;
        return project.copyWith(changeRequests: list);
      }).toList();
    });

    await _saveProjects();
  }

  Future<void> _removeChangeRequest(int index) async {
    final selectedProject = _selectedProject;
    if (selectedProject == null) return;

    setState(() {
      _projects = _projects.map((project) {
        if (project.id != selectedProject.id) {
          return project;
        }
        final updated = [...project.changeRequests]..removeAt(index);
        return project.copyWith(changeRequests: updated);
      }).toList();
    });

    await _saveProjects();
  }

  Future<void> _duplicateChangeRequest(int index) async {
    final selectedProject = _selectedProject;
    if (selectedProject == null ||
        index < 0 ||
        index >= selectedProject.changeRequests.length) {
      return;
    }

    setState(() {
      _projects = _projects.map((project) {
        if (project.id != selectedProject.id) {
          return project;
        }
        final updated = [...project.changeRequests];
        final clone = updated[index].copyWith();
        updated.insert(index + 1, clone);
        return project.copyWith(changeRequests: updated);
      }).toList();
    });

    await _saveProjects();
  }

  Future<void> _moveChangeRequest(int fromIndex, int toIndex) async {
    final selectedProject = _selectedProject;
    if (selectedProject == null) return;
    if (fromIndex == toIndex || fromIndex < 0 || toIndex < 0) return;
    if (fromIndex >= selectedProject.changeRequests.length ||
        toIndex >= selectedProject.changeRequests.length) {
      return;
    }

    setState(() {
      _projects = _projects.map((project) {
        if (project.id != selectedProject.id) {
          return project;
        }
        final updated = [...project.changeRequests];
        final block = updated.removeAt(fromIndex);
        updated.insert(toIndex, block);
        return project.copyWith(changeRequests: updated);
      }).toList();
    });

    await _saveProjects();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          color: Colors.blueGrey[50],
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Container(
          color: Colors.blueGrey[50],
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loadProjects,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final selectedProject = _selectedProject;

    return Scaffold(
      body: Row(
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
                      Expanded(
                        child: Text(
                          'Data Transformer',
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
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _showCreateProjectDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add project'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _projects.isEmpty
                      ? const Center(
                          child: Text(
                            'No projects yet.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _projects.length,
                          itemBuilder: (context, index) {
                            final project = _projects[index];
                            final isSelected = project.id == _selectedProjectId;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 3,
                              ),
                              child: Material(
                                color: isSelected
                                    ? Colors.blueGrey[600]
                                    : Colors.blueGrey[800],
                                borderRadius: BorderRadius.circular(5),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(5),
                                  onTap: () {
                                    setState(() {
                                      _selectedProjectId = project.id;
                                    });
                                    _syncInputControllerToSelectedProject();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      left: 12,
                                      right: 4,
                                      top: 4,
                                      bottom: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.folder_open,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            project.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.edit_outlined,
                                            size: 16,
                                            color: Colors.blueGrey[300],
                                          ),
                                          tooltip: 'Rename project',
                                          padding: const EdgeInsets.all(6),
                                          constraints: const BoxConstraints(),
                                          onPressed: () =>
                                              _renameProject(project),
                                        ),
                                        IconButton(
                                          tooltip: 'Delete project',
                                          icon: Icon(
                                            Icons.delete_outline,
                                            size: 16,
                                            color: Colors.red[300],
                                          ),
                                          padding: const EdgeInsets.all(6),
                                          constraints: const BoxConstraints(),
                                          onPressed: () =>
                                              _deleteProject(project),
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
          Expanded(
            child: Container(
              color: Colors.blueGrey[50],
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
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
                          Expanded(
                            child: Text(
                              selectedProject == null
                                  ? 'Data Transformer'
                                  : 'Project: ${selectedProject.name}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[900],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (selectedProject != null)
                            FilledButton.icon(
                              onPressed: _pickAndUploadFile,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Upload file'),
                            ),
                          if (selectedProject != null) ...[
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _exportOutput,
                              icon: const Icon(Icons.download),
                              label: const Text('Export output'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _showAddChangeDialog,
                              icon: const Icon(Icons.playlist_add),
                              label: const Text('Add change'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 17),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.blueGrey.shade200),
                        ),
                        child: selectedProject == null
                            ? const Center(
                                child: Text(
                                  'Create a project to start transforming data.',
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    DropTarget(
                                      onDragEntered: (_) {
                                        setState(() {
                                          _isDropActive = true;
                                        });
                                      },
                                      onDragExited: (_) {
                                        setState(() {
                                          _isDropActive = false;
                                        });
                                      },
                                      onDragDone: (details) async {
                                        setState(() {
                                          _isDropActive = false;
                                        });
                                        await _uploadFromDroppedItems(
                                          details.files,
                                        );
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: _isDropActive
                                                ? Colors.blueGrey
                                                : Colors.blueGrey.shade200,
                                            width: _isDropActive ? 2 : 1,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(5),
                                          color: _isDropActive
                                              ? Colors.blueGrey.shade50
                                              : Colors.white,
                                        ),
                                        child: Text(
                                          _isDropActive
                                              ? 'Drop file to upload'
                                              : 'Drop a file here to upload it to this project',
                                          style: TextStyle(
                                            color: Colors.blueGrey[700],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      selectedProject.sourceFilePath.isEmpty
                                          ? 'Source: No file uploaded yet'
                                          : 'Source: ${selectedProject.sourceFilePath}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.blueGrey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.blueGrey.shade200,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    width: double.infinity,
                                                    padding:
                                                        const EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.blueGrey[50],
                                                      borderRadius:
                                                          const BorderRadius.only(
                                                        topLeft:
                                                            Radius.circular(5),
                                                        topRight:
                                                            Radius.circular(5),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      'Requested Changes (${selectedProject.changeRequests.length})',
                                                      style: TextStyle(
                                                        color: Colors
                                                            .blueGrey[900],
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: selectedProject
                                                            .changeRequests
                                                            .isEmpty
                                                        ? const Center(
                                                            child: Text(
                                                              'No changes added yet.',
                                                            ),
                                                          )
                                                        : ListView.builder(
                                                            itemCount:
                                                                selectedProject
                                                                    .changeRequests
                                                                    .length,
                                                            itemBuilder:
                                                                (context, index) {
                                                              final block =
                                                                  selectedProject
                                                                          .changeRequests[
                                                                      index];
                                                              return Padding(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                                child: Container(
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        10,
                                                                    vertical: 8,
                                                                  ),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .blueGrey[50],
                                                                    border:
                                                                        Border.all(
                                                                      color: Colors
                                                                          .blueGrey
                                                                          .shade200,
                                                                    ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                      5,
                                                                    ),
                                                                  ),
                                                                  child:
                                                                      _ChangeBlockEditor(
                                                                    block:
                                                                        block,
                                                                    canMoveUp:
                                                                      index >
                                                                      0,
                                                                    canMoveDown:
                                                                      index <
                                                                      selectedProject.changeRequests.length -
                                                                        1,
                                                                    onTypeChanged:
                                                                        (type) => _updateChangeRequest(
                                                                      index,
                                                                      _ChangeBlock.fromType(
                                                                        type,
                                                                      ),
                                                                    ),
                                                                    onValueChanged:
                                                                        (value) => _updateChangeRequest(
                                                                      index,
                                                                      block.copyWith(
                                                                        value:
                                                                            value,
                                                                      ),
                                                                    ),
                                                                    onFromChanged:
                                                                        (value) => _updateChangeRequest(
                                                                      index,
                                                                      block.copyWith(
                                                                        from:
                                                                            value,
                                                                      ),
                                                                    ),
                                                                    onToChanged:
                                                                        (value) => _updateChangeRequest(
                                                                      index,
                                                                      block.copyWith(
                                                                        to:
                                                                            value,
                                                                      ),
                                                                    ),
                                                                    onEnabledChanged:
                                                                        (value) => _updateChangeRequest(
                                                                      index,
                                                                      block.copyWith(
                                                                        enabled:
                                                                            value,
                                                                      ),
                                                                    ),
                                                                    onCaseSensitiveChanged:
                                                                        (value) => _updateChangeRequest(
                                                                      index,
                                                                      block.copyWith(
                                                                        caseSensitive:
                                                                            value,
                                                                      ),
                                                                    ),
                                                                    onUseRegexChanged:
                                                                        (value) => _updateChangeRequest(
                                                                      index,
                                                                      block.copyWith(
                                                                        useRegex:
                                                                            value,
                                                                      ),
                                                                    ),
                                                                    onNonEmptyOnlyChanged:
                                                                        (value) => _updateChangeRequest(
                                                                      index,
                                                                      block.copyWith(
                                                                        nonEmptyOnly:
                                                                            value,
                                                                      ),
                                                                    ),
                                                                    onDescendingChanged:
                                                                        (value) => _updateChangeRequest(
                                                                      index,
                                                                      block.copyWith(
                                                                        descending:
                                                                            value,
                                                                      ),
                                                                    ),
                                                                    onMoveUp: () =>
                                                                        _moveChangeRequest(
                                                                      index,
                                                                      index -
                                                                          1,
                                                                    ),
                                                                    onMoveDown: () =>
                                                                        _moveChangeRequest(
                                                                      index,
                                                                      index +
                                                                          1,
                                                                    ),
                                                                    onDuplicate: () =>
                                                                        _duplicateChangeRequest(
                                                                      index,
                                                                    ),
                                                                    onRemove: () =>
                                                                        _removeChangeRequest(
                                                                      index,
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
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  child: _EditableDataCard(
                                                    title: 'Input',
                                                    controller: _inputController,
                                                    positionLabel:
                                                        _inputCaretLabel,
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Expanded(
                                                  child: _DataPreviewCard(
                                                    title: 'Output',
                                                    content: _outputPreview,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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
            ),
          ),
        ],
      ),
    );
  }
}

class _DataPreviewCard extends StatefulWidget {
  const _DataPreviewCard({required this.title, required this.content});

  final String title;
  final String content;

  @override
  State<_DataPreviewCard> createState() => _DataPreviewCardState();
}

class _DataPreviewCardState extends State<_DataPreviewCard> {
  late final TextEditingController _controller;
  TextSelection _selection = const TextSelection.collapsed(offset: 0);
  bool _isSyncingController = false;

  String get _positionLabel {
    final location = _linePositionFromOffset(
      _controller.text,
      _selection.extentOffset,
    );
    return 'Ln ${location.line}, Pos ${location.position}';
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _DataPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content == widget.content) {
      return;
    }

    final clampedOffset = _selection.extentOffset.clamp(0, widget.content.length);
    _isSyncingController = true;
    _controller.value = TextEditingValue(
      text: widget.content,
      selection: TextSelection.collapsed(offset: clampedOffset),
    );
    _isSyncingController = false;

    if (_selection.extentOffset != clampedOffset) {
      setState(() {
        _selection = TextSelection.collapsed(offset: clampedOffset);
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (_isSyncingController) {
      return;
    }

    final selection = _controller.selection;
    if (selection == _selection || !mounted) {
      return;
    }

    setState(() {
      _selection = selection;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueGrey.shade200),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: Colors.blueGrey[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _positionLabel,
                  style: TextStyle(
                    color: Colors.blueGrey[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: _controller,
                readOnly: true,
                showCursor: true,
                expands: true,
                maxLines: null,
                minLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  isCollapsed: true,
                  hintText: '(empty)',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontFamily: 'monospace', height: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableDataCard extends StatelessWidget {
  const _EditableDataCard({
    required this.title,
    required this.controller,
    required this.positionLabel,
  });

  final String title;
  final TextEditingController controller;
  final String positionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueGrey.shade200),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.blueGrey[900],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  positionLabel,
                  style: TextStyle(
                    color: Colors.blueGrey[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: controller,
                readOnly: true,
                showCursor: true,
                expands: true,
                maxLines: null,
                minLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  isCollapsed: true,
                  hintText: '(empty)',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontFamily: 'monospace', height: 1.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeBlockEditor extends StatelessWidget {
  const _ChangeBlockEditor({
    required this.block,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onTypeChanged,
    required this.onValueChanged,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onEnabledChanged,
    required this.onCaseSensitiveChanged,
    required this.onUseRegexChanged,
    required this.onNonEmptyOnlyChanged,
    required this.onDescendingChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDuplicate,
    required this.onRemove,
  });

  final _ChangeBlock block;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onValueChanged;
  final ValueChanged<String> onFromChanged;
  final ValueChanged<String> onToChanged;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool> onCaseSensitiveChanged;
  final ValueChanged<bool> onUseRegexChanged;
  final ValueChanged<bool> onNonEmptyOnlyChanged;
  final ValueChanged<bool> onDescendingChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: block.type,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
              items: _DataTransformerPageState._changeTemplates
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type,
                      child: Text(
                        _displayType(type),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                onTypeChanged(value);
              },
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 2,
              runSpacing: 2,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  tooltip: 'Move up',
                  onPressed: canMoveUp ? onMoveUp : null,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  tooltip: 'Move down',
                  onPressed: canMoveDown ? onMoveDown : null,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.content_copy, size: 18),
                  tooltip: 'Duplicate change',
                  onPressed: onDuplicate,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  tooltip: 'Remove change',
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('Enabled'),
              selected: block.enabled,
              onSelected: onEnabledChanged,
            ),
            if (_supportsCaseSensitive(block.type))
              FilterChip(
                label: const Text('Case sensitive'),
                selected: block.caseSensitive,
                onSelected: onCaseSensitiveChanged,
              ),
            if (_supportsRegex(block.type))
              FilterChip(
                label: const Text('Regex'),
                selected: block.useRegex,
                onSelected: onUseRegexChanged,
              ),
            if (_supportsNonEmptyOnly(block.type))
              FilterChip(
                label: const Text('Ignore empty lines'),
                selected: block.nonEmptyOnly,
                onSelected: onNonEmptyOnlyChanged,
              ),
            if (_supportsDescending(block.type))
              FilterChip(
                label: const Text('Descending'),
                selected: block.descending,
                onSelected: onDescendingChanged,
              ),
          ],
        ),
        if (block.type == 'replace') ...[
          const SizedBox(height: 8),
          TextFormField(
            initialValue: block.from,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'From',
              helperText: 'Supports Enter and \\n',
              border: OutlineInputBorder(),
            ),
            onChanged: onFromChanged,
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: block.to,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'To',
              helperText: 'Supports Enter and \\n',
              border: OutlineInputBorder(),
            ),
            onChanged: onToChanged,
          ),
        ],
        if (block.type == 'insert text') ...[
          const SizedBox(height: 8),
          TextFormField(
            initialValue: block.from,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Line (1-based)',
              helperText: 'Lines beyond the text clamp to the end',
              border: OutlineInputBorder(),
            ),
            onChanged: onFromChanged,
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: block.to,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Position in line (1-based)',
              helperText: '1 inserts at the start of the target line',
              border: OutlineInputBorder(),
            ),
            onChanged: onToChanged,
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: block.value,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Text to insert',
              helperText: 'Supports Enter',
              border: OutlineInputBorder(),
            ),
            onChanged: onValueChanged,
          ),
        ],
        if (block.type == 'keep line(s)' || block.type == 'remove line(s)') ...[
          const SizedBox(height: 8),
          TextFormField(
            initialValue: block.from,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Start line (1-based)',
              border: OutlineInputBorder(),
            ),
            onChanged: onFromChanged,
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: block.to,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'End line (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: onToChanged,
          ),
        ],
        if (block.type == 'prefix' || block.type == 'suffix') ...[
          const SizedBox(height: 8),
          TextFormField(
            initialValue: block.value,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              isDense: true,
              labelText: block.type == 'prefix' ? 'Prefix text' : 'Suffix text',
              helperText: 'Supports Enter and \\n',
              border: const OutlineInputBorder(),
            ),
            onChanged: onValueChanged,
          ),
        ],
        if (block.type == 'keep lines containing' ||
            block.type == 'remove lines containing') ...[
          const SizedBox(height: 8),
          TextFormField(
            initialValue: block.value,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Text to match',
              border: OutlineInputBorder(),
            ),
            onChanged: onValueChanged,
          ),
        ],
      ],
    );
  }
}

class _TransformerProject {
  const _TransformerProject({
    required this.id,
    required this.name,
    required this.sourceFilePath,
    required this.inputContent,
    required this.changeRequests,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String sourceFilePath;
  final String inputContent;
  final List<_ChangeBlock> changeRequests;
  final String createdAt;

  _TransformerProject copyWith({
    String? id,
    String? name,
    String? sourceFilePath,
    String? inputContent,
    List<_ChangeBlock>? changeRequests,
    String? createdAt,
  }) {
    return _TransformerProject(
      id: id ?? this.id,
      name: name ?? this.name,
      sourceFilePath: sourceFilePath ?? this.sourceFilePath,
      inputContent: inputContent ?? this.inputContent,
      changeRequests: changeRequests ?? this.changeRequests,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sourceFilePath': sourceFilePath,
    'inputContent': inputContent,
    'changeRequests': changeRequests.map((block) => block.toJson()).toList(),
    'createdAt': createdAt,
  };

  factory _TransformerProject.fromJson(Map<String, dynamic> json) {
    final rawRequests = json['changeRequests'];
    final requests = <_ChangeBlock>[];
    if (rawRequests is List) {
      for (final entry in rawRequests) {
        if (entry is String) {
          requests.add(_ChangeBlock.fromLegacyString(entry));
          continue;
        }
        if (entry is Map<String, dynamic>) {
          requests.add(_ChangeBlock.fromJson(entry));
          continue;
        }
        if (entry is Map) {
          requests.add(_ChangeBlock.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }

    return _TransformerProject(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString().trim(),
      sourceFilePath: (json['sourceFilePath'] ?? '').toString(),
      inputContent: (json['inputContent'] ?? '').toString(),
      changeRequests: requests,
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }
}

class _ChangeBlock {
  const _ChangeBlock({
    required this.type,
    this.value = '',
    this.from = '',
    this.to = '',
    this.enabled = true,
    this.caseSensitive = false,
    this.useRegex = false,
    this.nonEmptyOnly = false,
    this.descending = false,
  });

  final String type;
  final String value;
  final String from;
  final String to;
  final bool enabled;
  final bool caseSensitive;
  final bool useRegex;
  final bool nonEmptyOnly;
  final bool descending;

  _ChangeBlock copyWith({
    String? type,
    String? value,
    String? from,
    String? to,
    bool? enabled,
    bool? caseSensitive,
    bool? useRegex,
    bool? nonEmptyOnly,
    bool? descending,
  }) {
    return _ChangeBlock(
      type: type ?? this.type,
      value: value ?? this.value,
      from: from ?? this.from,
      to: to ?? this.to,
      enabled: enabled ?? this.enabled,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      useRegex: useRegex ?? this.useRegex,
      nonEmptyOnly: nonEmptyOnly ?? this.nonEmptyOnly,
      descending: descending ?? this.descending,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'value': value,
    'from': from,
    'to': to,
    'enabled': enabled,
    'caseSensitive': caseSensitive,
    'useRegex': useRegex,
    'nonEmptyOnly': nonEmptyOnly,
    'descending': descending,
  };

  factory _ChangeBlock.fromJson(Map<String, dynamic> json) {
    return _ChangeBlock(
      type: _normalizeBlockType((json['type'] ?? '').toString()),
      value: (json['value'] ?? '').toString(),
      from: (json['from'] ?? '').toString(),
      to: (json['to'] ?? '').toString(),
      enabled: _toBool(json['enabled'], fallback: true),
      caseSensitive: _toBool(json['caseSensitive']),
      useRegex: _toBool(json['useRegex']),
      nonEmptyOnly: _toBool(json['nonEmptyOnly']),
      descending: _toBool(json['descending']),
    );
  }

  factory _ChangeBlock.fromType(String type) {
    return _ChangeBlock(type: _normalizeBlockType(type));
  }

  factory _ChangeBlock.fromLegacyString(String rule) {
    final normalized = rule.trim().toLowerCase();

    if (normalized == 'uppercase' ||
        normalized == 'lowercase' ||
        normalized == 'trim lines' ||
        normalized == 'remove empty lines' ||
        normalized == 'remove duplicate lines' ||
        normalized == 'keep line(s)' ||
        normalized == 'remove line(s)' ||
        normalized == 'keep lines containing' ||
        normalized == 'remove lines containing' ||
        normalized == 'sort lines' ||
        normalized == 'insert text') {
      return _ChangeBlock(type: normalized);
    }

    final replaceMatch = RegExp(
      r'^replace\s+(.+?)\s*->\s*(.*)$',
      caseSensitive: false,
    ).firstMatch(rule);
    if (replaceMatch != null) {
      return _ChangeBlock(
        type: 'replace',
        from: replaceMatch.group(1) ?? '',
        to: replaceMatch.group(2) ?? '',
      );
    }

    final prefixMatch = RegExp(
      r'^prefix\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(rule);
    if (prefixMatch != null) {
      return _ChangeBlock(type: 'prefix', value: prefixMatch.group(1) ?? '');
    }

    final suffixMatch = RegExp(
      r'^suffix\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(rule);
    if (suffixMatch != null) {
      return _ChangeBlock(type: 'suffix', value: suffixMatch.group(1) ?? '');
    }

    return const _ChangeBlock(type: 'trim lines');
  }
}

String _normalizeBlockType(String type) {
  switch (type.trim().toLowerCase()) {
    case 'uppercase':
    case 'lowercase':
    case 'trim lines':
    case 'remove empty lines':
    case 'remove duplicate lines':
    case 'keep line(s)':
    case 'remove line(s)':
    case 'keep lines containing':
    case 'remove lines containing':
    case 'sort lines':
    case 'replace':
    case 'insert text':
    case 'prefix':
    case 'suffix':
    case 'json pretty':
    case 'json minify':
      return type.trim().toLowerCase();
    default:
      return 'trim lines';
  }
}

String _displayType(String type) {
  switch (type) {
    case 'trim lines':
      return 'Trim lines';
    case 'remove empty lines':
      return 'Remove empty lines';
    case 'remove duplicate lines':
      return 'Remove duplicate lines';
    case 'keep line(s)':
      return 'Keep line(s)';
    case 'remove line(s)':
      return 'Remove line(s)';
    case 'keep lines containing':
      return 'Keep lines containing';
    case 'remove lines containing':
      return 'Remove lines containing';
    case 'sort lines':
      return 'Sort lines';
    case 'uppercase':
      return 'Uppercase';
    case 'lowercase':
      return 'Lowercase';
    case 'replace':
      return 'Replace';
    case 'insert text':
      return 'Insert text';
    case 'prefix':
      return 'Prefix';
    case 'suffix':
      return 'Suffix';
    case 'json pretty':
      return 'JSON pretty';
    case 'json minify':
      return 'JSON minify';
    default:
      return type;
  }
}

bool _toBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is String) {
    final lowered = value.trim().toLowerCase();
    if (lowered == 'true') return true;
    if (lowered == 'false') return false;
  }
  return fallback;
}

bool _supportsCaseSensitive(String type) {
  return type == 'replace' ||
      type == 'keep lines containing' ||
      type == 'remove lines containing';
}

bool _supportsRegex(String type) {
  return type == 'replace';
}

bool _supportsNonEmptyOnly(String type) {
  return type == 'prefix' || type == 'suffix';
}

bool _supportsDescending(String type) {
  return type == 'sort lines';
}

String _applyChanges(String input, List<_ChangeBlock> changes) {
  var output = input;

  for (final block in changes) {
    if (!block.enabled) {
      continue;
    }

    final normalized = block.type;

    if (normalized == 'uppercase') {
      output = output.toUpperCase();
      continue;
    }

    if (normalized == 'lowercase') {
      output = output.toLowerCase();
      continue;
    }

    if (normalized == 'trim lines') {
      output = output
          .split('\n')
          .map((line) => line.trim())
          .join('\n');
      continue;
    }

    if (normalized == 'remove empty lines') {
      output = output
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .join('\n');
      continue;
    }

    if (normalized == 'remove duplicate lines') {
      final lines = output.split('\n');
      final seen = <String>{};
      final unique = <String>[];
      for (final line in lines) {
        if (seen.add(line)) {
          unique.add(line);
        }
      }
      output = unique.join('\n');
      continue;
    }

    if (normalized == 'keep line(s)' || normalized == 'remove line(s)') {
      final lines = output.split('\n');
      final start = int.tryParse(block.from.trim());
      final end = int.tryParse(block.to.trim());
      if (start == null || start <= 0) {
        continue;
      }

      var fromLine = start;
      var toLine = end ?? start;
      if (toLine <= 0) {
        toLine = start;
      }
      if (toLine < fromLine) {
        final temp = fromLine;
        fromLine = toLine;
        toLine = temp;
      }

      final result = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final lineNumber = i + 1;
        final inRange = lineNumber >= fromLine && lineNumber <= toLine;
        if (normalized == 'keep line(s)') {
          if (inRange) {
            result.add(lines[i]);
          }
        } else {
          if (!inRange) {
            result.add(lines[i]);
          }
        }
      }

      output = result.join('\n');
      continue;
    }

    if (normalized == 'keep lines containing') {
      final query = block.value;
      if (query.isEmpty) continue;
      output = output
          .split('\n')
          .where((line) => _matchesContains(line, query, block.caseSensitive))
          .join('\n');
      continue;
    }

    if (normalized == 'remove lines containing') {
      final query = block.value;
      if (query.isEmpty) continue;
      output = output
          .split('\n')
          .where((line) => !_matchesContains(line, query, block.caseSensitive))
          .join('\n');
      continue;
    }

    if (normalized == 'sort lines') {
      final lines = output.split('\n')..sort();
      output = block.descending ? lines.reversed.join('\n') : lines.join('\n');
      continue;
    }

    if (normalized == 'json pretty') {
      try {
        final parsed = jsonDecode(output);
        output = const JsonEncoder.withIndent('  ').convert(parsed);
      } catch (_) {
        // Leave output unchanged if content is not valid JSON.
      }
      continue;
    }

    if (normalized == 'json minify') {
      try {
        final parsed = jsonDecode(output);
        output = jsonEncode(parsed);
      } catch (_) {
        // Leave output unchanged if content is not valid JSON.
      }
      continue;
    }

    if (normalized == 'insert text') {
      final insertText = block.value;
      final lineNumber = int.tryParse(block.from.trim());
      final positionInLine = int.tryParse(block.to.trim());
      if (insertText.isEmpty || lineNumber == null || positionInLine == null) {
        continue;
      }

      final clampedPosition = _offsetFromLineAndPosition(
        output,
        lineNumber,
        positionInLine,
      );
      output =
          '${output.substring(0, clampedPosition)}$insertText${output.substring(clampedPosition)}';
      continue;
    }

    if (normalized == 'replace') {
      final replacement = _decodeEscapedText(block.to);

      if (block.useRegex) {
        if (block.from.isEmpty) {
          continue;
        }

        try {
          final pattern = RegExp(
            block.from,
            caseSensitive: block.caseSensitive,
            multiLine: true,
          );
          output = output.replaceAll(pattern, replacement);
        } catch (_) {
          // Ignore invalid regex and keep output unchanged.
        }
        continue;
      }

      final fromText = _decodeEscapedText(block.from);
      if (fromText.isEmpty) {
        continue;
      }

      if (block.caseSensitive) {
        output = output.replaceAll(fromText, replacement);
      } else {
        output = output.replaceAllMapped(
          RegExp(RegExp.escape(fromText), caseSensitive: false),
          (_) => replacement,
        );
      }
      continue;
    }

    if (normalized == 'prefix') {
      final prefix = _decodeEscapedText(block.value);
      output = output
          .split('\n')
          .map((line) {
            if (block.nonEmptyOnly && line.isEmpty) {
              return line;
            }
            return '$prefix$line';
          })
          .join('\n');
      continue;
    }

    if (normalized == 'suffix') {
      final suffix = _decodeEscapedText(block.value);
      output = output
          .split('\n')
          .map((line) {
            if (block.nonEmptyOnly && line.isEmpty) {
              return line;
            }
            return '$line$suffix';
          })
          .join('\n');
      continue;
    }
  }

  return output;
}

String _decodeEscapedText(String value) {
  return value
      .replaceAll('\\r\\n', '\r\n')
      .replaceAll('\\n', '\n')
      .replaceAll('\\r', '\r')
      .replaceAll('\\t', '\t');
}

_LinePosition _linePositionFromOffset(String text, int offset) {
  final safeOffset = offset.clamp(0, text.length);
  var line = 1;
  var position = 1;

  for (var index = 0; index < safeOffset; index++) {
    final codeUnit = text.codeUnitAt(index);
    if (codeUnit == 13) {
      continue;
    }
    if (codeUnit == 10) {
      line++;
      position = 1;
      continue;
    }
    position++;
  }

  return _LinePosition(line, position);
}

int _offsetFromLineAndPosition(
  String text,
  int lineNumber,
  int positionInLine,
) {
  final targetLine = lineNumber < 1 ? 1 : lineNumber;
  final targetPosition = positionInLine < 1 ? 1 : positionInLine;

  var currentLine = 1;
  var lineStart = 0;

  for (var index = 0; index < text.length && currentLine < targetLine; index++) {
    if (text.codeUnitAt(index) == 10) {
      currentLine++;
      lineStart = index + 1;
    }
  }

  if (currentLine < targetLine) {
    return text.length;
  }

  var lineEnd = text.length;
  for (var index = lineStart; index < text.length; index++) {
    if (text.codeUnitAt(index) == 10) {
      lineEnd = index;
      break;
    }
  }

  if (lineEnd > lineStart && text.codeUnitAt(lineEnd - 1) == 13) {
    lineEnd--;
  }

  final clampedPosition = targetPosition.clamp(1, lineEnd - lineStart + 1);
  return lineStart + clampedPosition - 1;
}

class _LinePosition {
  const _LinePosition(this.line, this.position);

  final int line;
  final int position;
}

bool _matchesContains(String input, String query, bool caseSensitive) {
  if (caseSensitive) {
    return input.contains(query);
  }
  return input.toLowerCase().contains(query.toLowerCase());
}

String _buildExportContent(String output, String formatId) {
  switch (formatId) {
    case 'txt':
    case 'log':
      return output;
    case 'jsonPretty':
      try {
        return const JsonEncoder.withIndent('  ').convert(jsonDecode(output));
      } catch (_) {
        return output;
      }
    case 'jsonMin':
      try {
        return jsonEncode(jsonDecode(output));
      } catch (_) {
        return output;
      }
    case 'csv':
      return _toDelimited(output, delimiter: ',');
    case 'tsv':
      return _toDelimited(output, delimiter: '\t');
    case 'md':
      return '## Exported Output\n\n```text\n$output\n```\n';
    case 'html':
      return '<!doctype html>\n<html><head><meta charset="utf-8"><title>Exported Output</title></head><body><pre>${const HtmlEscape().convert(output)}</pre></body></html>\n';
    case 'xml':
      return _toXml(output);
    case 'yaml':
      return _toYamlLike(output);
    default:
      return output;
  }
}

String _toDelimited(String output, {required String delimiter}) {
  dynamic parsed;
  try {
    parsed = jsonDecode(output);
  } catch (_) {
    parsed = null;
  }

  if (parsed is List && parsed.isNotEmpty && parsed.first is Map) {
    final headers = <String>[];
    for (final item in parsed) {
      if (item is Map) {
        for (final key in item.keys) {
          final keyString = key.toString();
          if (!headers.contains(keyString)) {
            headers.add(keyString);
          }
        }
      }
    }

    final lines = <String>[];
    lines.add(headers.map((h) => _escapeCell(h, delimiter)).join(delimiter));

    for (final item in parsed) {
      final rowMap = item is Map ? item : <dynamic, dynamic>{};
      final row = headers
          .map((header) => _escapeCell('${rowMap[header] ?? ''}', delimiter))
          .join(delimiter);
      lines.add(row);
    }
    return lines.join('\n');
  }

  if (parsed is Map) {
    final lines = <String>[
      ['key', 'value'].map((v) => _escapeCell(v, delimiter)).join(delimiter),
    ];
    for (final entry in parsed.entries) {
      lines.add(
        [_escapeCell('${entry.key}', delimiter), _escapeCell('${entry.value}', delimiter)]
            .join(delimiter),
      );
    }
    return lines.join('\n');
  }

  final rawLines = output.split('\n');
  final lines = <String>[
    _escapeCell('value', delimiter),
    ...rawLines.map((line) => _escapeCell(line, delimiter)),
  ];
  return lines.join('\n');
}

String _escapeCell(String value, String delimiter) {
  final needsQuote =
      value.contains('"') || value.contains('\n') || value.contains(delimiter);
  if (!needsQuote) {
    return value;
  }
  return '"${value.replaceAll('"', '""')}"';
}

String _toXml(String output) {
  final escaped = const HtmlEscape(HtmlEscapeMode.element).convert(output);
  final lines = output.split('\n');
  final body = lines
      .asMap()
      .entries
      .map(
        (entry) =>
            '  <line number="${entry.key + 1}">${const HtmlEscape(HtmlEscapeMode.element).convert(entry.value)}</line>',
      )
      .join('\n');
  return '<?xml version="1.0" encoding="UTF-8"?>\n<export>\n  <raw>$escaped</raw>\n  <lines>\n$body\n  </lines>\n</export>\n';
}

String _toYamlLike(String output) {
  final lines = output.split('\n');
  final escapedLines = lines
      .map((line) => '  - "${line.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"')
      .join('\n');
  return 'output:\n$escapedLines\n';
}

class _ExportFormat {
  const _ExportFormat({
    required this.id,
    required this.label,
    required this.extension,
  });

  final String id;
  final String label;
  final String extension;
}
