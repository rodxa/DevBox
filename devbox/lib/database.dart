import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

class _DbColumn {
  _DbColumn({
    required this.name,
    required this.type,
    required this.defaultValue,
  });

  final String name;
  final String type;
  final dynamic defaultValue;

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'defaultValue': defaultValue,
  };

  factory _DbColumn.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString().trim();
    final type = (json['type'] ?? 'text').toString().trim().toLowerCase();
    final normalizedType = _normalizeType(type);
    final rawDefault = json['defaultValue'];
    final coercedDefault = rawDefault == null
        ? _defaultValueForType(normalizedType)
        : _coerceValueForType(rawDefault, normalizedType);
    return _DbColumn(
      name: name,
      type: normalizedType,
      defaultValue: coercedDefault ?? _defaultValueForType(normalizedType),
    );
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
  final ScrollController _tableHeaderHorizontalScrollController =
      ScrollController();
  final ScrollController _tableBodyHorizontalScrollController =
      ScrollController();
  bool _isSyncingHorizontalScroll = false;

  _DbTable? get _selectedTable {
    if (_selectedTableIndex < 0 || _selectedTableIndex >= _tables.length) {
      return null;
    }
    return _tables[_selectedTableIndex];
  }

  @override
  void initState() {
    super.initState();
    _tableHeaderHorizontalScrollController.addListener(_syncBodyToHeaderScroll);
    _tableBodyHorizontalScrollController.addListener(_syncHeaderToBodyScroll);
    _loadDatabase();
  }

  @override
  void dispose() {
    _tableVerticalScrollController.dispose();
    _tableHeaderHorizontalScrollController.removeListener(
      _syncBodyToHeaderScroll,
    );
    _tableBodyHorizontalScrollController.removeListener(
      _syncHeaderToBodyScroll,
    );
    _tableHeaderHorizontalScrollController.dispose();
    _tableBodyHorizontalScrollController.dispose();
    super.dispose();
  }

  void _syncHeaderToBodyScroll() {
    _syncHorizontalScroll(
      source: _tableBodyHorizontalScrollController,
      target: _tableHeaderHorizontalScrollController,
    );
  }

  void _syncBodyToHeaderScroll() {
    _syncHorizontalScroll(
      source: _tableHeaderHorizontalScrollController,
      target: _tableBodyHorizontalScrollController,
    );
  }

  void _syncHorizontalScroll({
    required ScrollController source,
    required ScrollController target,
  }) {
    if (_isSyncingHorizontalScroll) return;
    if (!source.hasClients || !target.hasClients) return;

    _isSyncingHorizontalScroll = true;
    final targetOffset = source.offset.clamp(
      target.position.minScrollExtent,
      target.position.maxScrollExtent,
    );

    if ((target.offset - targetOffset).abs() > 0.5) {
      target.jumpTo(targetOffset);
    }
    _isSyncingHorizontalScroll = false;
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
          .map(
            (table) => _sanitizeForJson(table.toJson()) as Map<String, dynamic>,
          )
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
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
  }

  Future<void> _renameTable(int index) async {
    if (index < 0 || index >= _tables.length) return;
    final originalName = _tables[index].name;
    final nameController = TextEditingController(text: originalName);
    String? errorText;

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        Future<void> handleRename() async {
          final newName = nameController.text.trim();
          if (newName.isEmpty) {
            errorText = 'Table name is required.';
            (dialogContext as Element).markNeedsBuild();
            return;
          }

          if (newName == originalName) {
            Navigator.of(dialogContext).pop(false);
            return;
          }

          final exists = _tables.asMap().entries.any(
            (entry) =>
                entry.key != index &&
                entry.value.name.toLowerCase() == newName.toLowerCase(),
          );
          if (exists) {
            errorText = 'A table with this name already exists.';
            (dialogContext as Element).markNeedsBuild();
            return;
          }

          final table = _tables[index];
          setState(() {
            _tables[index] = _DbTable(
              name: newName,
              columns: table.columns,
              rows: table.rows,
            );
          });

          await _saveDatabase();
          if (!mounted) return;
          // ignore: use_build_context_synchronously
          Navigator.of(dialogContext).pop(true);
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Rename table'),
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
            onSubmitted: (_) async => handleRename(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async => handleRename(),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addColumn() async {
    final table = _selectedTable;
    if (table == null) return;

    final nameController = TextEditingController();
    final defaultValueController = TextEditingController();
    String selectedType = 'text';
    String? errorText;

    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        Future<void> handleAdd() async {
          final columnName = nameController.text.trim();
          final defaultValueRaw = defaultValueController.text.trim();
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

          final parsedDefault = defaultValueRaw.isEmpty
              ? _defaultValueForType(selectedType)
              : _parseTypedValue(selectedType, defaultValueRaw);
          if (parsedDefault == _invalidValue) {
            errorText = 'Invalid default value for type $selectedType.';
            (dialogContext as Element).markNeedsBuild();
            return;
          }

          setState(() {
            table.columns.add(
              _DbColumn(
                name: columnName,
                type: selectedType,
                defaultValue: parsedDefault,
              ),
            );
            for (final row in table.rows) {
              row[columnName] = parsedDefault;
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: defaultValueController,
                    decoration: const InputDecoration(
                      labelText: 'Default value (optional)',
                      hintText: 'Leave empty to use type default',
                    ),
                    onChanged: (_) {
                      if (errorText != null) {
                        setInnerState(() {
                          errorText = null;
                        });
                      }
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
  }

  Future<void> _addRow() async {
    final table = _selectedTable;
    if (table == null) return;

    final newRow = <String, dynamic>{};
    for (final column in table.columns) {
      newRow[column.name] = column.defaultValue;
    }

    setState(() {
      table.rows.add(newRow);
    });

    await _saveDatabase();
  }

  dynamic _coerceValueToType(dynamic value, String type) {
    return _coerceValueForType(value, type);
  }

  Future<void> _editColumn(int columnIndex) async {
    final table = _selectedTable;
    if (table == null) return;
    if (columnIndex < 0 || columnIndex >= table.columns.length) return;

    final column = table.columns[columnIndex];
    final originalName = column.name;
    final nameController = TextEditingController(text: originalName);
    final defaultValueController = TextEditingController(
      text: _stringifyDefaultValue(column.defaultValue),
    );
    String selectedType = column.type;
    String? errorText;

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            Future<void> handleSave() async {
              final newName = nameController.text.trim();
              final defaultValueRaw = defaultValueController.text.trim();
              if (newName.isEmpty) {
                setInnerState(() {
                  errorText = 'Column name is required.';
                });
                return;
              }

              final duplicate = table.columns.asMap().entries.any((entry) {
                if (entry.key == columnIndex) return false;
                return entry.value.name.toLowerCase() == newName.toLowerCase();
              });
              if (duplicate) {
                setInnerState(() {
                  errorText = 'Another column already has this name.';
                });
                return;
              }

              final parsedDefault = defaultValueRaw.isEmpty
                  ? _defaultValueForType(selectedType)
                  : _parseTypedValue(selectedType, defaultValueRaw);
              if (parsedDefault == _invalidValue) {
                setInnerState(() {
                  errorText = 'Invalid default value for type $selectedType.';
                });
                return;
              }

              final normalizedType = _normalizeType(selectedType);
              setState(() {
                table.columns[columnIndex] = _DbColumn(
                  name: newName,
                  type: normalizedType,
                  defaultValue: parsedDefault,
                );

                for (final row in table.rows) {
                  final currentValue = row[originalName];
                  if (newName != originalName) {
                    row.remove(originalName);
                  }
                  row[newName] = _coerceValueToType(
                    currentValue,
                    normalizedType,
                  );
                }
              });

              await _saveDatabase();
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              Navigator.of(dialogContext).pop('saved');
            }

            Future<void> handleDelete() async {
              final confirmed = await showDialog<bool>(
                context: dialogContext,
                builder: (confirmContext) {
                  return AlertDialog(
                    title: const Text('Delete column?'),
                    content: Text(
                      'Delete "$originalName" and all its values from every row?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(confirmContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(confirmContext).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  );
                },
              );

              if (confirmed != true) {
                return;
              }

              setState(() {
                table.columns.removeAt(columnIndex);
                for (final row in table.rows) {
                  row.remove(originalName);
                }
              });

              await _saveDatabase();
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              Navigator.of(dialogContext).pop('deleted');
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              title: Text('Edit column ${column.name}'),
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: defaultValueController,
                    decoration: const InputDecoration(
                      labelText: 'Default value (optional)',
                      hintText: 'Leave empty to use type default',
                    ),
                    onChanged: (_) {
                      if (errorText != null) {
                        setInnerState(() {
                          errorText = null;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop('cancelled'),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async => handleDelete(),
                  child: Text(
                    'Delete',
                    style: TextStyle(color: Colors.red[700]),
                  ),
                ),
                FilledButton(
                  onPressed: () async => handleSave(),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteTable(int index) async {
    if (index < 0 || index >= _tables.length) return;
    final tableName = _tables[index].name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Delete table?'),
          content: Text('Delete "$tableName" and all its data permanently?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(confirmContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(confirmContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _tables.removeAt(index);
      if (_selectedTableIndex >= _tables.length) {
        _selectedTableIndex = _tables.isEmpty ? -1 : _tables.length - 1;
      }
    });
    await _saveDatabase();
  }

  Future<void> _deleteRow(int rowIndex) async {
    final table = _selectedTable;
    if (table == null) return;
    if (rowIndex < 0 || rowIndex >= table.rows.length) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Delete row?'),
          content: const Text('Delete this row permanently?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(confirmContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(confirmContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
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

    const double dataColumnWidth = 180;
    const double actionsColumnWidth = 84;
    const double tableHorizontalMargin = 24;
    const double tableColumnSpacing = 56;
    const double headingRowHeight = 58;
    const double bodyRowHeight = 48;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportContentWidth = constraints.maxWidth > 32
            ? constraints.maxWidth - 32
            : constraints.maxWidth;

        final actionPaneWidth =
            actionsColumnWidth + (tableHorizontalMargin * 2);
        final leftViewportWidth = (viewportContentWidth - actionPaneWidth)
            .clamp(0.0, double.infinity);

        final leftTableContentWidth =
            (table.columns.length * dataColumnWidth) +
            (tableHorizontalMargin * 2) +
            ((table.columns.length > 1 ? table.columns.length - 1 : 0) *
                tableColumnSpacing);

        final effectiveLeftTableWidth =
            leftTableContentWidth > leftViewportWidth
            ? leftTableContentWidth
            : leftViewportWidth;

        return Scrollbar(
          controller: _tableBodyHorizontalScrollController,
          thumbVisibility: true,
          trackVisibility: true,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: viewportContentWidth,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: leftViewportWidth,
                        child: SingleChildScrollView(
                          controller: _tableHeaderHorizontalScrollController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: effectiveLeftTableWidth,
                            child: DataTable(
                              horizontalMargin: tableHorizontalMargin,
                              columnSpacing: tableColumnSpacing,
                              headingRowHeight: headingRowHeight,
                              dataRowMinHeight: 0,
                              dataRowMaxHeight: 0,
                              columns: [
                                ...table.columns.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final column = entry.value;
                                  return DataColumn(
                                    label: SizedBox(
                                      width: dataColumnWidth,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(4),
                                        onTap: () => _editColumn(index),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                            horizontal: 2,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      column.name,
                                                      maxLines: 1,
                                                      softWrap: false,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Icon(
                                                    Icons.edit_outlined,
                                                    size: 14,
                                                    color: Colors.blueGrey[400],
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                column.type,
                                                maxLines: 1,
                                                softWrap: false,
                                                overflow: TextOverflow.ellipsis,
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
                                    ),
                                  );
                                }),
                              ],
                              rows: const [],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: actionPaneWidth,
                        child: DataTable(
                          horizontalMargin: tableHorizontalMargin,
                          columnSpacing: tableColumnSpacing,
                          headingRowHeight: headingRowHeight,
                          dataRowMinHeight: 0,
                          dataRowMaxHeight: 0,
                          columns: [
                            DataColumn(
                              label: SizedBox(
                                width: actionsColumnWidth,
                                child: const Text('Actions'),
                              ),
                            ),
                          ],
                          rows: const [],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Scrollbar(
                    controller: _tableVerticalScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _tableVerticalScrollController,
                      child: SizedBox(
                        width: viewportContentWidth,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: leftViewportWidth,
                              child: SingleChildScrollView(
                                controller:
                                    _tableBodyHorizontalScrollController,
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: effectiveLeftTableWidth,
                                  child: DataTable(
                                    horizontalMargin: tableHorizontalMargin,
                                    columnSpacing: tableColumnSpacing,
                                    headingRowHeight: 0,
                                    dataRowMinHeight: bodyRowHeight,
                                    dataRowMaxHeight: bodyRowHeight,
                                    columns: [
                                      ...table.columns.map(
                                        (_) => DataColumn(
                                          label: SizedBox(
                                            width: dataColumnWidth,
                                            child: const SizedBox.shrink(),
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: List.generate(table.rows.length, (
                                      rowIndex,
                                    ) {
                                      final row = table.rows[rowIndex];
                                      return DataRow(
                                        cells: [
                                          ...table.columns.map((column) {
                                            final value = row[column.name];
                                            final display = value == null
                                                ? 'null'
                                                : value.toString();
                                            return DataCell(
                                              SizedBox(
                                                width: dataColumnWidth,
                                                child: Text(
                                                  display,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              onTap: () => _editCell(
                                                rowIndex: rowIndex,
                                                column: column,
                                              ),
                                            );
                                          }),
                                        ],
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: actionPaneWidth,
                              child: DataTable(
                                horizontalMargin: tableHorizontalMargin,
                                columnSpacing: tableColumnSpacing,
                                headingRowHeight: 0,
                                dataRowMinHeight: bodyRowHeight,
                                dataRowMaxHeight: bodyRowHeight,
                                columns: [
                                  DataColumn(
                                    label: SizedBox(
                                      width: actionsColumnWidth,
                                      child: const SizedBox.shrink(),
                                    ),
                                  ),
                                ],
                                rows: List.generate(table.rows.length, (
                                  rowIndex,
                                ) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        SizedBox(
                                          width: actionsColumnWidth,
                                          child: IconButton(
                                            tooltip: 'Delete row',
                                            icon: Icon(
                                              Icons.delete_outline,
                                              color: Colors.red[400],
                                            ),
                                            onPressed: () =>
                                                _deleteRow(rowIndex),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                                    padding: const EdgeInsets.only(
                                      left: 12,
                                      right: 4,
                                      top: 4,
                                      bottom: 4,
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
                                        IconButton(
                                          icon: Icon(
                                            Icons.edit_outlined,
                                            size: 16,
                                            color: Colors.blueGrey[300],
                                          ),
                                          tooltip: 'Rename table',
                                          padding: const EdgeInsets.all(6),
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _renameTable(index),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            size: 16,
                                            color: Colors.red[300],
                                          ),
                                          tooltip: 'Delete table',
                                          padding: const EdgeInsets.all(6),
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _deleteTable(index),
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

dynamic _coerceValueForType(dynamic value, String type) {
  if (value == null) {
    return null;
  }

  switch (_normalizeType(type)) {
    case 'text':
      return value.toString();
    case 'integer':
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is bool) {
        return value ? 1 : 0;
      }
      if (value is String) {
        return int.tryParse(value.trim());
      }
      return null;
    case 'decimal':
      if (value is double) {
        return value;
      }
      if (value is num) {
        return value.toDouble();
      }
      if (value is bool) {
        return value ? 1.0 : 0.0;
      }
      if (value is String) {
        return double.tryParse(value.trim());
      }
      return null;
    case 'boolean':
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final lower = value.trim().toLowerCase();
        if (lower == 'true' || lower == '1' || lower == 'yes') {
          return true;
        }
        if (lower == 'false' || lower == '0' || lower == 'no') {
          return false;
        }
      }
      return null;
    default:
      return value;
  }
}

String _stringifyDefaultValue(dynamic value) {
  if (value == null) {
    return '';
  }
  return value.toString();
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
