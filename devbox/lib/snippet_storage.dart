import 'dart:convert';
import 'dart:io';

const String devboxContentPath = 'C:/Users/Utilizador/Desktop/devbox_content';
const String globalSnippetBucketName = 'Global';
const String snippetCreatedAtField = 'createdAt';
const List<String> snippetLanguageOptions = <String>[
  '',
  'Dart',
  'JavaScript',
  'TypeScript',
  'Python',
  'Java',
  'Kotlin',
  'Swift',
  'C',
  'C++',
  'C#',
  'Go',
  'Rust',
  'PHP',
  'Ruby',
  'SQL',
  'HTML',
  'CSS',
  'JSON',
  'YAML',
  'Bash',
  'PowerShell',
];

Directory getDevboxContentFolder() {
  return Directory(devboxContentPath);
}

File getGlobalSnippetsFile() {
  return File(
    '${getDevboxContentFolder().path}${Platform.pathSeparator}global_snippets.json',
  );
}

File getProjectSnippetsFile(Directory projectFolder) {
  return File(
    '${projectFolder.path}${Platform.pathSeparator}snippets${Platform.pathSeparator}snippets.json',
  );
}

List<Directory> listProjectFolders({Directory? contentFolder}) {
  final root = contentFolder ?? getDevboxContentFolder();
  if (!root.existsSync()) {
    return <Directory>[];
  }

  return root.listSync().whereType<Directory>().toList();
}

List<Map<String, String>> readSnippetsFromFile(File file) {
  if (!file.existsSync()) {
    return <Map<String, String>>[];
  }

  try {
    final content = file.readAsStringSync();
    if (content.trim().isEmpty) {
      return <Map<String, String>>[];
    }

    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      return <Map<String, String>>[];
    }

    final list = decoded['snippets'];
    if (list is! List) {
      return <Map<String, String>>[];
    }

    final snippets = <Map<String, String>>[];
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        snippets.add({
          'title': item['title']?.toString() ?? '',
          'language': item['language']?.toString() ?? '',
          'code': item['code']?.toString() ?? '',
          snippetCreatedAtField: item[snippetCreatedAtField]?.toString() ?? '',
        });
      } else if (item is Map) {
        final mapped = Map<String, dynamic>.from(item);
        snippets.add({
          'title': mapped['title']?.toString() ?? '',
          'language': mapped['language']?.toString() ?? '',
          'code': mapped['code']?.toString() ?? '',
          snippetCreatedAtField:
              mapped[snippetCreatedAtField]?.toString() ?? '',
        });
      }
    }
    return snippets;
  } on FormatException {
    return <Map<String, String>>[];
  } on FileSystemException {
    return <Map<String, String>>[];
  }
}

String nowIsoTimestamp() {
  return DateTime.now().toUtc().toIso8601String();
}

void writeSnippetsToFile(File file, List<Map<String, String>> snippets) {
  final parent = file.parent;
  if (!parent.existsSync()) {
    parent.createSync(recursive: true);
  }
  file.writeAsStringSync(jsonEncode({'snippets': snippets}));
}

String buildSnippetTitleFromCode(String text) {
  final firstLine = text
      .split('\n')
      .firstWhere((l) => l.trim().isNotEmpty, orElse: () => 'Snippet');
  String baseTitle = firstLine.trim();
  if (baseTitle.length > 50) {
    baseTitle = '${baseTitle.substring(0, 47)}...';
  }
  return baseTitle;
}

String ensureUniqueSnippetTitle(
  List<Map<String, String>> snippets,
  String desiredTitle,
) {
  var title = desiredTitle;
  var counter = 1;
  while (snippets.any(
    (snippet) => (snippet['title'] ?? '').toLowerCase() == title.toLowerCase(),
  )) {
    title = '$desiredTitle ($counter)';
    counter++;
  }
  return title;
}

String addSnippetToFile(File destinationFile, Map<String, String> snippet) {
  final snippets = readSnippetsFromFile(destinationFile);
  final safeTitle = ensureUniqueSnippetTitle(
    snippets,
    (snippet['title'] ?? '').trim().isEmpty
        ? 'Snippet'
        : snippet['title']!.trim(),
  );

  final createdAtRaw = (snippet[snippetCreatedAtField] ?? '').trim();
  final createdAt = DateTime.tryParse(createdAtRaw) == null
      ? nowIsoTimestamp()
      : createdAtRaw;

  final entry = <String, String>{
    'title': safeTitle,
    'language': snippet['language'] ?? '',
    'code': snippet['code'] ?? '',
    snippetCreatedAtField: createdAt,
  };

  snippets.add(entry);
  writeSnippetsToFile(destinationFile, snippets);
  return safeTitle;
}

bool removeExactSnippetFromFile(File sourceFile, Map<String, String> snippet) {
  final snippets = readSnippetsFromFile(sourceFile);
  final createdAt = (snippet[snippetCreatedAtField] ?? '').trim();

  final index = snippets.indexWhere(
    (entry) =>
        (entry['title'] ?? '') == (snippet['title'] ?? '') &&
        (entry['language'] ?? '') == (snippet['language'] ?? '') &&
        (entry['code'] ?? '') == (snippet['code'] ?? '') &&
        (createdAt.isEmpty ||
            (entry[snippetCreatedAtField] ?? '') == createdAt),
  );

  if (index < 0) {
    return false;
  }

  snippets.removeAt(index);
  writeSnippetsToFile(sourceFile, snippets);
  return true;
}
