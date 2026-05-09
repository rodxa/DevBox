import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:devbox/globals.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

bool _running = false;
String? _last;

Future<void> initCapture(Function(String text) onCapture) async {
  await hotKeyManager.unregisterAll();

  final hotKey = HotKey(
    key: PhysicalKeyboardKey.keyD,
    modifiers: [HotKeyModifier.alt],
    scope: HotKeyScope.system,
  );

  await hotKeyManager.register(
    hotKey,
    keyDownHandler: (_) async {
      if (_running) return;
      _running = true;

      final text = await _capture();

      if (text != null && text.isNotEmpty && text != _last) {
        _last = text;
        onCapture(text);
      }
      _running = false;
    },
  );
}

Future<String?> _capture() async {
  print('Capturing selection...');
  final result = await Process.run(
    r'..\devbox\lib\selection_reader.exe',
    [],
  );

  print("STDOUT: ${result.stdout}");
  print("EXIT: ${result.exitCode}");

  if (result.exitCode != 0) return null;
  final text = result.stdout.toString().replaceAll('\x00', '').trim();
  return text.isEmpty ? null : text;
}

void addCapturedSnippet(String text) {
  final projectFolder = Globals().currentProjectFolder;
  if (projectFolder == null) return;

  final snippetsFile = File(
    '${projectFolder.path}${Platform.pathSeparator}snippets${Platform.pathSeparator}snippets.json',
  );

  List<dynamic> snippets = [];
  if (snippetsFile.existsSync()) {
    try {
      final content = snippetsFile.readAsStringSync();
      if (content.trim().isNotEmpty) {
        final decoded = jsonDecode(content) as Map<String, dynamic>;
        snippets = (decoded['snippets'] as List<dynamic>?) ?? [];
      }
    } on FormatException {
      // ignore malformed JSON, start fresh
    }
  }

  // Auto-generate a title from the first non-empty line
  final firstLine = text
      .split('\n')
      .firstWhere((l) => l.trim().isNotEmpty, orElse: () => 'Snippet');
  String baseTitle = firstLine.trim();
  if (baseTitle.length > 50) baseTitle = '${baseTitle.substring(0, 47)}...';

  // Ensure unique title
  String title = baseTitle;
  int counter = 1;
  while (snippets.any((s) => s is Map && s['title'] == title)) {
    title = '$baseTitle ($counter)';
    counter++;
  }

  snippets.add({'title': title, 'language': '', 'code': text});

  try {
    final snippetsDir = snippetsFile.parent;
    if (!snippetsDir.existsSync()) {
      snippetsDir.createSync(recursive: true);
    }
    snippetsFile.writeAsStringSync(jsonEncode({'snippets': snippets}));
    print('[DevBox] Snippet "$title" saved.');
  } on FileSystemException catch (e) {
    print('[DevBox] Failed to save snippet: $e');
  }
}

class Snippets extends StatefulWidget {
  const Snippets({
    super.key,
    required this.projectName,
    required this.projectFolder,
  });

  final String projectName;
  final Directory projectFolder;

  @override
  State<Snippets> createState() => _SnippetsState();
}

class _SnippetsState extends State<Snippets> {
  final List<Map<String, String>> _snippets = [];

  File get _snippetsFile => File(
    '${widget.projectFolder.path}${Platform.pathSeparator}snippets${Platform.pathSeparator}snippets.json',
  );

  @override
  void initState() {
    super.initState();
    _loadSnippets();
  }

  void _loadSnippets() {
    try {
      if (!_snippetsFile.existsSync()) {
        setState(() {
          _snippets.clear();
        });
        return;
      }

      final content = _snippetsFile.readAsStringSync();
      if (content.trim().isEmpty) {
        setState(() {
          _snippets.clear();
        });
        return;
      }

      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final list = decoded['snippets'] as List<dynamic>?;

      setState(() {
        _snippets.clear();
        if (list == null) {
          return;
        }

        for (final item in list) {
          if (item is Map<String, dynamic>) {
            _snippets.add({
              'title': item['title']?.toString() ?? '',
              'language': item['language']?.toString() ?? '',
              'code': item['code']?.toString() ?? '',
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

  void _saveSnippets() {
    try {
      final snippetsDir = _snippetsFile.parent;
      if (!snippetsDir.existsSync()) {
        snippetsDir.createSync(recursive: true);
      }

      final encoded = jsonEncode({'snippets': _snippets});
      _snippetsFile.writeAsStringSync(encoded);
    } on FileSystemException {
      // ignore write errors
    }
  }

  Future<void> _showSnippetDialog({int? editIndex}) async {
    final isEditing = editIndex != null;
    final currentSnippet = isEditing ? _snippets[editIndex] : null;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => _SnippetDialog(
        isEditing: isEditing,
        initialTitle: currentSnippet?['title'] ?? '',
        initialLanguage: currentSnippet?['language'] ?? '',
        initialCode: currentSnippet?['code'] ?? '',
        existingTitles: _snippets
            .asMap()
            .entries
            .where((e) => e.key != editIndex)
            .map((e) => e.value['title'] ?? '')
            .toList(),
      ),
    );

    if (result == null) return;

    setState(() {
      if (isEditing) {
        _snippets[editIndex] = result;
      } else {
        _snippets.add(result);
      }
    });

    _saveSnippets();
  }

  Future<void> _deleteSnippet(int index) async {
    final title = _snippets[index]['title'] ?? 'Snippet';

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: const Text('Delete snippet'),
        content: Text('Delete "$title" permanently? This cannot be undone.'),
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
      _snippets.removeAt(index);
    });
    _saveSnippets();
  }

  Future<void> _copySnippetToClipboard(int index) async {
    final snippet = _snippets[index];
    final code = snippet['code'] ?? '';
    final title = snippet['title'] ?? 'Snippet';

    await Clipboard.setData(ClipboardData(text: code));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Copied "$title" code.')));
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
                          'Snippets',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[900],
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${_snippets.length} ${_snippets.length == 1 ? 'snippet' : 'snippets'}',
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
                    onTap: () => _showSnippetDialog(),
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
                            'Add Snippet',
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
                    onTap: _loadSnippets,
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
            SizedBox(height: 16),
            Expanded(
              child: _snippets.isEmpty
                  ? Center(
                      child: Text(
                        'No snippets yet.',
                        style: TextStyle(
                          color: Colors.blueGrey[500],
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _snippets.length,
                      itemBuilder: (context, index) {
                        final snippet = _snippets[index];
                        final title = (snippet['title'] ?? '').trim();
                        final language = (snippet['language'] ?? '').trim();
                        final code = snippet['code'] ?? '';

                        final lines = code.split('\n');
                        final preview = lines.take(2).join(' ');

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Material(
                            color: Colors.blueGrey[200],
                            borderRadius: BorderRadius.circular(5),
                            child: ListTile(
                              leading: Icon(
                                Icons.code,
                                color: Colors.blueGrey[800],
                              ),
                              title: Text(
                                title,
                                style: TextStyle(
                                  color: Colors.blueGrey[900],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                language.isEmpty
                                    ? preview
                                    : '$language  •  $preview',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.blueGrey[700],
                                  fontSize: 13,
                                ),
                              ),
                              onTap: () => _showSnippetDialog(editIndex: index),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.copy,
                                      color: Colors.blueGrey[600],
                                    ),
                                    tooltip: 'Copy snippet code',
                                    onPressed: () =>
                                        _copySnippetToClipboard(index),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      color: Colors.blueGrey[600],
                                    ),
                                    tooltip: 'Edit snippet',
                                    onPressed: () =>
                                        _showSnippetDialog(editIndex: index),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: Colors.blueGrey[700],
                                    ),
                                    tooltip: 'Delete snippet',
                                    onPressed: () => _deleteSnippet(index),
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
class _SnippetDialog extends StatefulWidget {
  const _SnippetDialog({
    required this.isEditing,
    required this.initialTitle,
    required this.initialLanguage,
    required this.initialCode,
    required this.existingTitles,
  });

  final bool isEditing;
  final String initialTitle;
  final String initialLanguage;
  final String initialCode;
  final List<String> existingTitles;

  @override
  State<_SnippetDialog> createState() => _SnippetDialogState();
}

class _SnippetDialogState extends State<_SnippetDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _languageController;
  late final TextEditingController _codeController;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _languageController = TextEditingController(text: widget.initialLanguage);
    _codeController = TextEditingController(text: widget.initialCode);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _languageController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _trySubmit() {
    final title = _titleController.text.trim();
    final language = _languageController.text.trim();
    final code = _codeController.text;

    if (title.isEmpty) {
      setState(() {
        _titleError = 'Title is required.';
      });
      return;
    }

    final isDuplicate = widget.existingTitles.any(
      (t) => t.toLowerCase() == title.toLowerCase(),
    );
    if (isDuplicate) {
      setState(() {
        _titleError = 'A snippet with this title already exists.';
      });
      return;
    }

    Navigator.of(context).pop({
      'title': title,
      'language': language,
      'code': code,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      title: Text(widget.isEditing ? 'Edit Snippet' : 'Add Snippet'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. HTTP GET helper',
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
              SizedBox(height: 12),
              TextField(
                controller: _languageController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Language (optional)',
                  hintText: 'e.g. dart, javascript, sql',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _codeController,
                minLines: 10,
                maxLines: 16,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: 'Code',
                  alignLabelWithHint: true,
                  hintText: 'Paste or write your code snippet here',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _trySubmit,
          child: Text(widget.isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}