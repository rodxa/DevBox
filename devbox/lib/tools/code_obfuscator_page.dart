import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class CodeObfuscatorPage extends StatefulWidget {
  const CodeObfuscatorPage({super.key});

  @override
  State<CodeObfuscatorPage> createState() => _CodeObfuscatorPageState();
}

class _CodeObfuscatorPageState extends State<CodeObfuscatorPage> {
  static const Set<String> _reservedWords = <String>{
    'abstract',
    'and',
    'as',
    'assert',
    'async',
    'await',
    'bool',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'do',
    'double',
    'dynamic',
    'else',
    'enum',
    'export',
    'extends',
    'false',
    'final',
    'finally',
    'for',
    'function',
    'if',
    'implements',
    'import',
    'in',
    'int',
    'interface',
    'is',
    'let',
    'library',
    'mixin',
    'new',
    'null',
    'num',
    'or',
    'override',
    'package',
    'part',
    'private',
    'protected',
    'public',
    'required',
    'return',
    'set',
    'static',
    'super',
    'switch',
    'this',
    'throw',
    'true',
    'try',
    'typedef',
    'var',
    'void',
    'while',
    'with',
    'yield',
  };

  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();

  bool _removeComments = true;
  bool _keepInputStructure = true;
  bool _renameIdentifiers = true;
  String? _inputError;

  bool get _hasValidCode {
    return _validateCode(_inputController.text) == null;
  }

  @override
  void dispose() {
    _inputController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  String? _validateCode(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return 'Paste or type code to obfuscate.';
    }

    final hasCodeKeyword = RegExp(
      r'\b(class|function|const|let|var|final|if|else|for|while|switch|return|import|export|def|public|private|void|int|string|async|await|try|catch)\b',
      caseSensitive: false,
    ).hasMatch(text);

    final hasCodeSymbols = RegExp(r'[{}();=<>\[\]]').hasMatch(text);
    final hasStructure = RegExp(r'\n|=>|::|\.|\(|\)').hasMatch(text);
    final likelySentence =
        RegExp(r'^[A-Za-z\s,.!?]+$').hasMatch(text) && !hasCodeSymbols;

    if (likelySentence ||
        !(hasCodeKeyword || (hasCodeSymbols && hasStructure))) {
      return 'Only code is allowed. Please provide source code syntax.';
    }

    return null;
  }

  void _obfuscate() {
    final validationError = _validateCode(_inputController.text);
    if (validationError != null) {
      setState(() {
        _inputError = validationError;
        _outputController.clear();
      });
      _showMessage(validationError);
      return;
    }

    String output = _inputController.text;
    if (_removeComments) {
      output = _stripComments(output);
    }
    if (_renameIdentifiers) {
      output = _obfuscateIdentifiers(output);
    }
    if (!_keepInputStructure) {
      output = _prettifyCode(output);
    }

    setState(() {
      _inputError = null;
      _outputController.text = output;
    });
  }

  String _stripComments(String input) {
    final withoutBlock = input.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    return withoutBlock.replaceAll(RegExp(r'(^|\s)//.*$', multiLine: true), '');
  }

  String _obfuscateIdentifiers(String input) {
    final tokenPattern = RegExp(r'\b[_A-Za-z][_A-Za-z0-9]*\b');
    final map = <String, String>{};
    var counter = 1;

    String replacement(Match match) {
      final token = match.group(0)!;
      if (_reservedWords.contains(token.toLowerCase())) {
        return token;
      }
      if (RegExp(r'^_+$').hasMatch(token)) {
        return token;
      }
      return map.putIfAbsent(token, () => 'v${counter++}');
    }

    return input.replaceAllMapped(tokenPattern, replacement);
  }

  String _prettifyCode(String input) {
    final buffer = StringBuffer();
    var indent = 0;
    var pendingSpace = false;
    var lineStart = true;
    var inSingleQuote = false;
    var inDoubleQuote = false;
    var inBacktick = false;
    var escaped = false;

    void writeIndent() {
      buffer.write('  ' * indent);
      lineStart = false;
    }

    String? nextNonWhitespace(int start) {
      for (var i = start; i < input.length; i++) {
        final ch = input[i];
        if (!RegExp(r'\s').hasMatch(ch)) {
          return ch;
        }
      }
      return null;
    }

    for (var i = 0; i < input.length; i++) {
      final ch = input[i];

      if (inSingleQuote || inDoubleQuote || inBacktick) {
        if (lineStart) {
          writeIndent();
        }
        buffer.write(ch);
        if (escaped) {
          escaped = false;
          continue;
        }
        if (ch == r'\\') {
          escaped = true;
          continue;
        }
        if (inSingleQuote && ch == "'") {
          inSingleQuote = false;
        } else if (inDoubleQuote && ch == '"') {
          inDoubleQuote = false;
        } else if (inBacktick && ch == '`') {
          inBacktick = false;
        }
        continue;
      }

      if (ch == "'" || ch == '"' || ch == '`') {
        if (lineStart) {
          writeIndent();
        }
        if (pendingSpace) {
          buffer.write(' ');
          pendingSpace = false;
        }
        buffer.write(ch);
        lineStart = false;
        inSingleQuote = ch == "'";
        inDoubleQuote = ch == '"';
        inBacktick = ch == '`';
        continue;
      }

      if (RegExp(r'\s').hasMatch(ch)) {
        pendingSpace = true;
        continue;
      }

      if (ch == '{') {
        if (lineStart) {
          writeIndent();
        }
        if (pendingSpace) {
          buffer.write(' ');
          pendingSpace = false;
        }
        buffer.write('{\n');
        indent++;
        lineStart = true;
        continue;
      }

      if (ch == '}') {
        if (!lineStart) {
          buffer.write('\n');
        }
        indent = indent > 0 ? indent - 1 : 0;
        writeIndent();
        buffer.write('}');
        pendingSpace = false;

        final nextChar = nextNonWhitespace(i + 1);
        if (nextChar != null && nextChar != ';' && nextChar != ',' && nextChar != ')') {
          buffer.write('\n');
          lineStart = true;
        }
        continue;
      }

      if (ch == ';') {
        if (lineStart) {
          writeIndent();
        }
        buffer.write(';');
        final nextChar = nextNonWhitespace(i + 1);
        if (nextChar != null) {
          buffer.write('\n');
          lineStart = true;
        }
        pendingSpace = false;
        continue;
      }

      if (ch == ',') {
        if (lineStart) {
          writeIndent();
        }
        buffer.write(', ');
        pendingSpace = false;
        lineStart = false;
        continue;
      }

      if (lineStart) {
        writeIndent();
      }
      if (pendingSpace) {
        buffer.write(' ');
        pendingSpace = false;
      }
      buffer.write(ch);
      lineStart = false;
    }

    return buffer.toString().trim();
  }

  Future<void> _copyOutput() async {
    final text = _outputController.text;
    if (text.trim().isEmpty) {
      _showMessage('Nothing to copy yet.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    _showMessage('Obfuscated code copied to clipboard.');
  }

  void _clearAll() {
    setState(() {
      _inputController.clear();
      _outputController.clear();
      _inputError = null;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 240,
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
                          'Code Obfuscator',
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Options',
                    style: TextStyle(
                      color: Colors.blueGrey[100],
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  dense: true,
                  title: const Text(
                    'Remove comments',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: _removeComments,
                  onChanged: (value) => setState(() => _removeComments = value),
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text(
                    'Rename identifiers',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: _renameIdentifiers,
                  onChanged: (value) =>
                      setState(() => _renameIdentifiers = value),
                ),
                SwitchListTile(
                  dense: true,
                  title: const Text(
                    'Keep input structure',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: _keepInputStructure,
                  onChanged: (value) =>
                      setState(() => _keepInputStructure = value),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Input is validated as code before obfuscation.',
                    style: TextStyle(color: Colors.blueGrey[200], height: 1.4),
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
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey[100],
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Code Obfuscator',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[900],
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _hasValidCode ? _obfuscate : null,
                            icon: const Icon(Icons.shield),
                            label: const Text('Obfuscate'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _copyOutput,
                            icon: const Icon(Icons.copy_all),
                            label: const Text('Copy output'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _clearAll,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Clear'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _EditorCard(
                              title: 'Input code',
                              errorText: _inputError,
                              child: TextField(
                                controller: _inputController,
                                onChanged: (_) {
                                  setState(() {
                                    _inputError = _validateCode(
                                      _inputController.text,
                                    );
                                  });
                                },
                                expands: true,
                                maxLines: null,
                                minLines: null,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Paste code here...',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _EditorCard(
                              title: 'Obfuscated output',
                              child: TextField(
                                controller: _outputController,
                                expands: true,
                                maxLines: null,
                                minLines: null,
                                readOnly: true,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  height: 1.3,
                                ),
                                decoration: const InputDecoration(
                                  hintText:
                                      'Obfuscated code will appear here...',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(12),
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
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({required this.title, required this.child, this.errorText});

  final String title;
  final Widget child;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
              ),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.blueGrey[900],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                errorText!,
                style: TextStyle(color: Colors.red[700], fontSize: 12),
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
