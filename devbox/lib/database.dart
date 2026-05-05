import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

class _DbColumn {
  _DbColumn({required this.name, required this.type});

  final String name;
  final String type;

  Map<String, dynamic> toJson() => {'name': name, 'type': type};

  factory _DbColumn.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString().trim();
    final type = (json['type'] ?? 'text').toString().trim().toLowerCase();
    return _DbColumn(name: name, type: _normalizeType(type));
  }
}

class _DbTable {
  _DbTable({required this.name, required this.columns, required this.rows});

  final String name;
  final List<_DbColumn> columns;
  final List<Map<String, dynamic>> rows;

  Map<String, dynamic> toJson() => {
    'name': name,
    'columns': columns.map((column) => column.toJson()).toList(),
    'rows': rows,
  };

  factory _DbTable.fromJson(Map<String, dynamic> json) {
    final rawColumns = json['columns'];
    final rawRows = json['rows'];

    final columns = <_DbColumn>[];
    if (rawColumns is List) {
      for (final item in rawColumns) {
        if (item is Map<String, dynamic>) {
          final parsed = _DbColumn.fromJson(item);
          if (parsed.name.isNotEmpty) {
            columns.add(parsed);
          }
        } else if (item is Map) {
          final parsed = _DbColumn.fromJson(Map<String, dynamic>.from(item));
          if (parsed.name.isNotEmpty) {
            columns.add(parsed);
          }
        }
      }
    }

    final rows = <Map<String, dynamic>>[];
    if (rawRows is List) {
      for (final row in rawRows) {
        if (row is Map<String, dynamic>) {
          rows.add(Map<String, dynamic>.from(row));
        } else if (row is Map) {
          rows.add(Map<String, dynamic>.from(row));
        }
      }
    }

    return _DbTable(
      name: (json['name'] ?? '').toString(),
      columns: columns,
      rows: rows,
    );
  }
}

const Object _invalidValue = Object();

String _normalizeType(String type) {
  switch (type) {
    case 'integer':
    case 'decimal':
    case 'boolean':
    case 'text':
      return type;
    default:
      return 'text';
  }
}

const List<String> _columnTypes = ['text', 'integer', 'decimal', 'boolean'];

class Database extends StatefulWidget {
  const Database({super.key, required this.databaseFile});
  final String databaseFile;

  @override
  State<Database> createState() => _DatabaseState();
}

class _DatabaseState extends State<Database> {
  List<_DbTable> _tables = <_DbTable>[];
  int _selectedTableIndex = -1;
  bool _isLoading = true;
  String? _error;
  final ScrollController _tableVerticalScrollController = ScrollController();

  _DbTable? get _selectedTable {
    if (_selectedTableIndex < 0 || _selectedTableIndex >= _tables.length) {
      return null;
    }
    return _tables[_selectedTableIndex];
  }

  @override
  void initState() {
    super.initState();
    _loadDatabase();
  }

  @override
  void dispose() {
    _tableVerticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDatabase() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final file = File(widget.databaseFile);
      if (!file.existsSync()) {
        await file.create(recursive: true);
        await file.writeAsString('{"tables":[]}');
      }

      final content = await file.readAsString();
      Map<String, dynamic> payload;
      if (content.trim().isEmpty) {
        payload = <String, dynamic>{'tables': <dynamic>[]};
      } else {
        final decoded = jsonDecode(content);
        if (decoded is! Map) {
          throw const FormatException('Invalid database JSON format.');
        }
        payload = Map<String, dynamic>.from(decoded);
      }

      final rawTables = payload['tables'];
      final parsedTables = <_DbTable>[];
      if (rawTables is List) {
        for (final entry in rawTables) {
          if (entry is Map<String, dynamic>) {
            final table = _DbTable.fromJson(entry);
            if (table.name.trim().isNotEmpty) {
              parsedTables.add(table);
            }
          } else if (entry is Map) {
            final table = _DbTable.fromJson(Map<String, dynamic>.from(entry));
            if (table.name.trim().isNotEmpty) {
              parsedTables.add(table);
            }
          }
        }
      }

      setState(() {
        _tables = parsedTables;
        _selectedTableIndex = parsedTables.isEmpty ? -1 : 0;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _error = 'Could not load database file.';
      });
    }
  }

  Future<void> _saveDatabase() async {
    final payload = <String, dynamic>{
      'tables': _tables
          .map((table) => _sanitizeForJson(table.toJson()) as Map<String, dynamic>)
          .toList(),
    };

    final encoder = const JsonEncoder.withIndent('  ');
    final file = File(widget.databaseFile);
    await file.writeAsString(encoder.convert(payload));
  }

  Future<void> _addTable() async {
    final nameController = TextEditingController();
    String? errorText;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        Future<void> handleCreate() async {
          final name = nameController.text.trim();
          if (name.isEmpty) {
            errorText = 'Table name is required.';
            (dialogContext as Element).markNeedsBuild();
            return;
          }

          final exists = _tables.any(
            (table) => table.name.toLowerCase() == name.toLowerCase(),
          );
          if (exists) {
            errorText = 'A table with this name already exists.';
            (dialogContext as Element).markNeedsBuild();
            return;
          }

          setState(() {
            _tables.add(
              _DbTable(
                name: name,
                columns: <_DbColumn>[],
                rows: <Map<String, dynamic>>[],
              ),
            );
            _selectedTableIndex = _tables.length - 1;
          });

          await _saveDatabase();
          if (!mounted) return;
          // ignore: use_build_context_synchronously
          Navigator.of(dialogContext).pop(true);
        }

        return AlertDialog(
          title: const Text('Add table'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Table name',
              errorText: errorText,
            ),
            onChanged: (_) {
              if (errorText != null) {
                errorText = null;
                (dialogContext as Element).markNeedsBuild();
              }
            },
            onSubmitted: (_) async => handleCreate(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async => handleCreate(),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Table added.')));
    }
  }

  Future<void> _addColumn() async {
    final table = _selectedTable;
    if (table == null) return;

    final nameController = TextEditingController();
    String selectedType = 'text';
    String? errorText;

    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        Future<void> handleAdd() async {
          final columnName = nameController.text.trim();
          if (columnName.isEmpty) {
            errorText = 'Column name is required.';
            (dialogContext as Element).markNeedsBuild();
            return;
          }

          final exists = table.columns.any(
            (column) => column.name.toLowerCase() == columnName.toLowerCase(),
          );
          if (exists) {
            errorText = 'Column already exists in this table.';
            (dialogContext as Element).markNeedsBuild();
            return;
          }

          setState(() {
            table.columns.add(_DbColumn(name: columnName, type: selectedType));
            for (final row in table.rows) {
              row[columnName] = null;
            }
          });

          await _saveDatabase();
          if (!mounted) return;
          // ignore: use_build_context_synchronously
          Navigator.of(dialogContext).pop(true);
        }

        return StatefulBuilder(
          builder: (context, setInnerState) {
            return AlertDialog(
              title: const Text('Add column'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Column name',
                      errorText: errorText,
                    ),
                    onChanged: (_) {
                      if (errorText != null) {
                        setInnerState(() {
                          errorText = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: _columnTypes
                        .map(
                          (type) => DropdownMenuItem<String>(
                            value: type,
                            child: Text(type),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setInnerState(() {
                        selectedType = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async => handleAdd(),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (added == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Column added.')));
    }
  }

  Future<void> _addRow() async {
    final table = _selectedTable;
    if (table == null) return;

    if (table.columns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one column first.')),
      );
      return;
    }

    final newRow = <String, dynamic>{};
    for (final column in table.columns) {
      newRow[column.name] = _defaultValueForType(column.type);
    }

    setState(() {
      table.rows.add(newRow);
    });

    await _saveDatabase();
  }

  Future<void> _deleteRow(int rowIndex) async {
    final table = _selectedTable;
    if (table == null) return;
    if (rowIndex < 0 || rowIndex >= table.rows.length) return;

    setState(() {
      table.rows.removeAt(rowIndex);
    });
    await _saveDatabase();
  }

  Future<void> _editCell({
    required int rowIndex,
    required _DbColumn column,
  }) async {
    final table = _selectedTable;
    if (table == null) return;
    if (rowIndex < 0 || rowIndex >= table.rows.length) return;

    final row = table.rows[rowIndex];
    final currentValue = row[column.name];

    if (column.type == 'boolean') {
      bool? selected;
      if (currentValue is bool) {
        selected = currentValue;
      } else if (currentValue == null) {
        selected = null;
      } else {
        selected = currentValue.toString().toLowerCase() == 'true';
      }

      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setInnerState) {
              return AlertDialog(
                title: Text('Edit ${column.name}'),
                content: DropdownButtonFormField<bool?>(
                  value: selected,
                  decoration: const InputDecoration(labelText: 'Value'),
                  items: const [
                    DropdownMenuItem<bool?>(value: null, child: Text('null')),
                    DropdownMenuItem<bool?>(value: true, child: Text('true')),
                    DropdownMenuItem<bool?>(value: false, child: Text('false')),
                  ],
                  onChanged: (value) {
                    setInnerState(() {
                      selected = value;
                    });
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (saved == true) {
        setState(() {
          row[column.name] = selected;
        });
        await _saveDatabase();
      }
      return;
    }

    final controller = TextEditingController(
      text: currentValue == null ? '' : currentValue.toString(),
    );
    String? errorText;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        Future<void> handleSave() async {
          final raw = controller.text.trim();
          final parsed = _parseTypedValue(column.type, raw);
          if (parsed == _invalidValue) {
            errorText = 'Invalid value for type ${column.type}.';
            (dialogContext as Element).markNeedsBuild();
            return;
          }

          setState(() {
            row[column.name] = parsed;
          });

          await _saveDatabase();
          if (!mounted) return;
          // ignore: use_build_context_synchronously
          Navigator.of(dialogContext).pop(true);
        }

        return AlertDialog(
          title: Text('Edit ${column.name}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Value (${column.type})',
              errorText: errorText,
            ),
            onChanged: (_) {
              if (errorText != null) {
                errorText = null;
                (dialogContext as Element).markNeedsBuild();
              }
            },
            onSubmitted: (_) async => handleSave(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async => handleSave(),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved == true && mounted) {
      setState(() {});
    }
  }

  Widget _buildMainPanel() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600),
        ),
      );
    }

    if (_tables.isEmpty) {
      return Center(
        child: Text(
          'No tables yet. Click "Add table" on the left bar.',
          style: TextStyle(color: Colors.blueGrey[500], fontSize: 16),
        ),
      );
    }

    final table = _selectedTable;
    if (table == null) {
      return Center(
        child: Text(
          'Select a table from the left bar.',
          style: TextStyle(color: Colors.blueGrey[500], fontSize: 16),
        ),
      );
    }

    if (table.columns.isEmpty) {
      return Center(
        child: Text(
          'This table has no columns yet. Click "Add column".',
          style: TextStyle(color: Colors.blueGrey[500], fontSize: 16),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Scrollbar(
      controller: _tableVerticalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _tableVerticalScrollController,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              ...table.columns.map(
                (column) => DataColumn(
                  label: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(column.name),
                      Text(
                        column.type,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blueGrey[500],
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const DataColumn(label: Text('Actions')),
            ],
            rows: List.generate(table.rows.length, (rowIndex) {
              final row = table.rows[rowIndex];
              return DataRow(
                cells: [
                  ...table.columns.map((column) {
                    final value = row[column.name];
                    final display = value == null ? 'null' : value.toString();
                    return DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 100,
                          maxWidth: 220,
                        ),
                        child: Text(display, overflow: TextOverflow.ellipsis),
                      ),
                      onTap: () =>
                          _editCell(rowIndex: rowIndex, column: column),
                    );
                  }),
                  DataCell(
                    IconButton(
                      tooltip: 'Delete row',
                      icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                      onPressed: () => _deleteRow(rowIndex),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedTable = _selectedTable;

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
                          widget.databaseFile
                              .split(RegExp(r'[\\/]'))
                              .last
                              .replaceAll(RegExp(r'\.[^.]+$'), ''),
                          style: const TextStyle(
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
                      onPressed: _addTable,
                      icon: const Icon(Icons.add),
                      label: const Text('Add table'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _tables.length,
                          itemBuilder: (context, index) {
                            final table = _tables[index];
                            final isSelected = index == _selectedTableIndex;
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
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
                                      _selectedTableIndex = index;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.table_chart,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            table.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
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
          Expanded(
            child: Container(
              color: Colors.blueGrey[50],
              child: Padding(
                padding: const EdgeInsets.all(24.0),
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
                              selectedTable == null
                                  ? 'Database'
                                  : 'Table: ${selectedTable.name}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[900],
                              ),
                            ),
                          ),
                          if (selectedTable != null) ...[
                            FilledButton.icon(
                              onPressed: _addColumn,
                              icon: const Icon(Icons.view_column),
                              label: const Text('Add column'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _addRow,
                              icon: const Icon(Icons.add),
                              label: const Text('Add row'),
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
                        child: _buildMainPanel(),
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

dynamic _sanitizeForJson(dynamic value) {
  if (identical(value, _invalidValue)) {
    return null;
  }
  if (value is Map) {
    return value.map((key, entryValue) {
      return MapEntry(key.toString(), _sanitizeForJson(entryValue));
    });
  }
  if (value is List) {
    return value.map(_sanitizeForJson).toList();
  }
  return value;
}

dynamic _defaultValueForType(String type) {
  switch (_normalizeType(type)) {
    case 'integer':
      return 0;
    case 'decimal':
      return 0.0;
    case 'boolean':
      return false;
    case 'text':
      return '';
    default:
      return null;
  }
}

dynamic _parseTypedValue(String type, String rawValue) {
  if (rawValue.isEmpty) {
    return null;
  }

  switch (_normalizeType(type)) {
    case 'text':
      return rawValue;
    case 'integer':
      return int.tryParse(rawValue) ?? _invalidValue;
    case 'decimal':
      return double.tryParse(rawValue) ?? _invalidValue;
    case 'boolean':
      final lower = rawValue.toLowerCase();
      if (lower == 'true' || lower == '1' || lower == 'yes') {
        return true;
      }
      if (lower == 'false' || lower == '0' || lower == 'no') {
        return false;
      }
      return _invalidValue;
    default:
      return rawValue;
  }
}
