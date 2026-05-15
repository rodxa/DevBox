import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Drawings extends StatefulWidget {
  const Drawings({
    super.key,
    required this.projectName,
    required this.projectFolder,
  });

  final String projectName;
  final Directory projectFolder;

  @override
  State<Drawings> createState() => _DrawingsState();
}

class _DrawingsState extends State<Drawings> {
  late final Directory _drawingsDirectory;
  List<File> _drawingFiles = const [];
  final TextEditingController _drawingNameController = TextEditingController();

  @override
  void dispose() {
    _drawingNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _drawingsDirectory = Directory(
      '${widget.projectFolder.path}${Platform.pathSeparator}Drawings',
    );
    _loadDrawings();
  }

  Future<void> _createDrawing() async {
    var alreadyExists = false;
    String? createError;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        _drawingNameController.clear();

        Future<void> tryCreate() async {
          final rawName = _drawingNameController.text.trim();
          if (rawName.isEmpty) {
            return;
          }

          if (rawName.contains(RegExp(r'[<>:"/\\|?*]'))) {
            createError = 'Name contains invalid characters.';
            (dialogContext as Element).markNeedsBuild();
            return;
          }

          final fileName = rawName.endsWith('.json')
              ? rawName
              : '$rawName.json';

          final existingNames = _drawingFiles
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
            '${_drawingsDirectory.path}${Platform.pathSeparator}$fileName',
          );

          try {
            if (!_drawingsDirectory.existsSync()) {
              _drawingsDirectory.createSync(recursive: true);
            }
            await newFile.writeAsString(
              jsonEncode(_DrawingDocument.empty().toJson()),
            );
          } on FileSystemException {
            createError = 'Could not create drawing file.';
            (dialogContext as Element).markNeedsBuild();
            return;
          }

          if (!mounted) {
            return;
          }
          Navigator.of(dialogContext).pop(true);
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('New Drawing'),
          content: TextField(
            controller: _drawingNameController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Drawing name',
              hintText: 'my-drawing',
              errorText: alreadyExists
                  ? 'A drawing with this name already exists.'
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
      _loadDrawings();
    }
  }

  Future<void> _renameDrawing(File file) async {
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
          if (raw.isEmpty || raw == baseName) {
            return;
          }

          if (raw.contains(RegExp(r'[<>:"/\\|?*]'))) {
            alreadyExists = false;
            dialogElement.markNeedsBuild();
            return;
          }

          final newFileName = raw.endsWith('.json') ? raw : '$raw.json';

          final existingNames = _drawingFiles
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
            if (dialogElement.mounted) {
              dialogElement.markNeedsBuild();
            }
            return;
          }

          final newFile = File(
            '${file.parent.path}${Platform.pathSeparator}$newFileName',
          );

          try {
            await file.rename(newFile.path);
          } on FileSystemException {
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not rename drawing.')),
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
          title: const Text('Rename drawing'),
          content: TextFormField(
            initialValue: baseName,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Drawing name',
              errorText: alreadyExists
                  ? 'A drawing with this name already exists.'
                  : null,
            ),
            onChanged: (value) {
              nextName = value;
              if (alreadyExists) {
                alreadyExists = false;
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
              onPressed: () async => tryRename(),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    if (shouldRename == true && mounted) {
      _loadDrawings();
    }
  }

  Future<void> _deleteDrawing(File file) async {
    final name = file.path.split(Platform.pathSeparator).last;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: const Text('Delete drawing'),
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

    if (shouldDelete != true) {
      return;
    }

    try {
      if (file.existsSync()) {
        await file.delete();
      }
    } on FileSystemException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete drawing.')),
      );
      return;
    }

    if (mounted) {
      _loadDrawings();
    }
  }

  void _loadDrawings() {
    if (!_drawingsDirectory.existsSync()) {
      _drawingsDirectory.createSync(recursive: true);
      setState(() {
        _drawingFiles = const [];
      });
      return;
    }

    final files =
        _drawingsDirectory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.toLowerCase().endsWith('.json'))
            .toList()
          ..sort((first, second) => first.path.compareTo(second.path));

    setState(() {
      _drawingFiles = files;
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
                          'Drawings',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[900],
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${_drawingFiles.length} ${_drawingFiles.length == 1 ? "file" : "files"}',
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
                    onTap: _createDrawing,
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
                            'New Drawing',
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
                    onTap: _loadDrawings,
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
              child: _drawingFiles.isEmpty
                  ? Center(
                      child: Text(
                        'No drawings yet.',
                        style: TextStyle(
                          color: Colors.blueGrey[500],
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _drawingFiles.length,
                      itemBuilder: (context, index) {
                        final drawingFile = _drawingFiles[index];
                        return _DrawingTile(
                          name: drawingFile.path
                              .split(Platform.pathSeparator)
                              .last
                              .split('.')
                              .first,
                          onTap: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (context) => DrawingCanvasPage(
                                      drawingFile: drawingFile,
                                    ),
                                  ),
                                )
                                .then((_) => _loadDrawings());
                          },
                          onRename: () => _renameDrawing(drawingFile),
                          onDelete: () => _deleteDrawing(drawingFile),
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

class DrawingCanvasPage extends StatefulWidget {
  const DrawingCanvasPage({super.key, required this.drawingFile});

  final File drawingFile;

  @override
  State<DrawingCanvasPage> createState() => _DrawingCanvasPageState();
}

enum _CanvasTool { pencil, eraser, hand }

class _DrawingCanvasPageState extends State<DrawingCanvasPage> {
  final List<_DrawingStroke> _strokes = [];
  _DrawingStroke? _activeStroke;
  _CanvasTool _activeTool = _CanvasTool.pencil;
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3;
  double _eraserSize = 20;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  double _canvasScale = 1.0;
  Offset _canvasOffset = Offset.zero;
  bool _isMiddlePanning = false;
  int? _middlePanPointer;
  Offset? _lastPanPosition;
  Offset? _cursorLocalPosition;
  bool _isPointerOnCanvas = false;
  final FocusNode _pageFocusNode = FocusNode();
  Timer? _viewportSaveDebounce;
  bool _viewportDirty = false;

  @override
  void dispose() {
    _viewportSaveDebounce?.cancel();
    _pageFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadDrawing();
  }

  Future<void> _loadDrawing() async {
    if (!widget.drawingFile.existsSync()) {
      setState(() {});
      return;
    }

    try {
      final document = _decodeDrawingDocument(
        await widget.drawingFile.readAsString(),
      );
      _strokes
        ..clear()
        ..addAll(document.strokes);
      _canvasScale = document.viewport.scale;
      _canvasOffset = document.viewport.offset;
    } catch (_) {
      // Keep an empty canvas when file content is invalid.
    }

    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<bool> _saveDrawing() async {
    if (_isSaving) {
      return false;
    }

    _viewportSaveDebounce?.cancel();
    _viewportSaveDebounce = null;

    if (_activeStroke != null && _activeStroke!.points.isNotEmpty) {
      _strokes.add(_activeStroke!);
      _activeStroke = null;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (!widget.drawingFile.parent.existsSync()) {
        widget.drawingFile.parent.createSync(recursive: true);
      }

      final payload = _currentDrawingDocument().toJson();
      await widget.drawingFile.writeAsString(jsonEncode(payload));

      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Drawing saved.')));
      _hasUnsavedChanges = false;
      _viewportDirty = false;
      return true;
    } on FileSystemException {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not save drawing.')));
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<bool> _confirmExitIfNeeded() async {
    if (_viewportDirty) {
      await _flushViewportState();
    }

    final hasPendingStroke =
        _activeStroke != null && _activeStroke!.points.isNotEmpty;
    if (!_hasUnsavedChanges && !hasPendingStroke) {
      return true;
    }

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Save drawing before leaving?'),
          content: const Text(
            'You have unsaved changes. Do you want to save before exiting?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('discard'),
              child: const Text('Don\'t Save'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop('save'),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (action == 'discard') {
      return true;
    }
    if (action == 'save') {
      return _saveDrawing();
    }
    return false;
  }

  void _startStroke(Offset point) {
    if (_isMiddlePanning || _activeTool != _CanvasTool.pencil) {
      return;
    }
    setState(() {
      _activeStroke = _DrawingStroke(
        color: _selectedColor,
        width: _strokeWidth,
        points: [_toWorld(point)],
      );
    });
  }

  void _appendPoint(Offset point) {
    if (_isMiddlePanning || _activeTool != _CanvasTool.pencil) {
      return;
    }
    if (_activeStroke == null) {
      return;
    }
    final current = _activeStroke!;
    setState(() {
      _activeStroke = _DrawingStroke(
        color: current.color,
        width: current.width,
        points: [...current.points, _toWorld(point)],
      );
    });
  }

  void _endStroke() {
    if (_isMiddlePanning || _activeTool != _CanvasTool.pencil) {
      return;
    }
    final stroke = _activeStroke;
    if (stroke == null || stroke.points.isEmpty) {
      return;
    }

    setState(() {
      _strokes.add(stroke);
      _activeStroke = null;
      _hasUnsavedChanges = true;
    });
  }

  void _undo() {
    if (_strokes.isEmpty) {
      return;
    }
    setState(() {
      _strokes.removeLast();
      _hasUnsavedChanges = true;
    });
  }

  void _clearCanvas() {
    if (_strokes.isEmpty && _activeStroke == null) {
      return;
    }
    setState(() {
      _strokes.clear();
      _activeStroke = null;
      _hasUnsavedChanges = true;
    });
  }

  Offset _toWorld(Offset localPoint) {
    return (localPoint - _canvasOffset) / _canvasScale;
  }

  void _panCanvas(Offset delta) {
    setState(() {
      _canvasOffset += delta;
    });
    _scheduleViewportSave();
  }

  _DrawingDocument _currentDrawingDocument() {
    return _DrawingDocument(
      strokes: List<_DrawingStroke>.unmodifiable(_strokes),
      viewport: _DrawingViewport(scale: _canvasScale, offset: _canvasOffset),
    );
  }

  _DrawingDocument _decodeDrawingDocument(String rawContent) {
    final decoded = jsonDecode(rawContent);
    if (decoded is! Map) {
      return _DrawingDocument.empty();
    }

    final document = Map<String, dynamic>.from(decoded);
    final strokes = <_DrawingStroke>[];
    final rawStrokes = document['strokes'];
    if (rawStrokes is List) {
      strokes.addAll(
        rawStrokes
            .whereType<Map>()
            .map((entry) => _DrawingStroke.fromJson(Map<String, dynamic>.from(entry)))
            .where((stroke) => stroke.points.isNotEmpty),
      );
    }

    return _DrawingDocument(
      strokes: strokes,
      viewport: _DrawingViewport.fromJson(document['viewport']),
    );
  }

  void _scheduleViewportSave() {
    _viewportDirty = true;
    _viewportSaveDebounce?.cancel();
    _viewportSaveDebounce = Timer(
      const Duration(milliseconds: 250),
      () {
        unawaited(_flushViewportState());
      },
    );
  }

  Future<void> _flushViewportState() async {
    _viewportSaveDebounce?.cancel();
    _viewportSaveDebounce = null;

    if (!_viewportDirty || _isSaving) {
      return;
    }

    try {
      if (!widget.drawingFile.parent.existsSync()) {
        widget.drawingFile.parent.createSync(recursive: true);
      }

      final document = widget.drawingFile.existsSync()
          ? _decodeDrawingDocument(await widget.drawingFile.readAsString())
          : _DrawingDocument.empty();

      final updatedDocument = document.copyWith(
        viewport: _DrawingViewport(scale: _canvasScale, offset: _canvasOffset),
      );

      await widget.drawingFile.writeAsString(jsonEncode(updatedDocument.toJson()));
      _viewportDirty = false;
    } on FileSystemException {
      // Ignore transient viewport save failures and keep the editor usable.
    } on FormatException {
      // Replace invalid files with a valid document containing the current viewport.
      final fallback = _DrawingDocument.empty().copyWith(
        viewport: _DrawingViewport(scale: _canvasScale, offset: _canvasOffset),
      );
      try {
        await widget.drawingFile.writeAsString(jsonEncode(fallback.toJson()));
        _viewportDirty = false;
      } on FileSystemException {
        // Ignore transient viewport save failures and keep the editor usable.
      }
    }
  }

  double get _cursorScreenRadius {
    if (_activeTool == _CanvasTool.eraser) {
      return _eraserSize;
    }
    return (_strokeWidth * _canvasScale) / 2;
  }

  bool get _shouldShowToolCursor {
    return _isPointerOnCanvas &&
        _cursorLocalPosition != null &&
        (_activeTool == _CanvasTool.pencil || _activeTool == _CanvasTool.eraser);
  }

  void _eraseAt(Offset localPoint) {
    final eraserWorldRadius = _eraserSize / _canvasScale;
    final target = _toWorld(localPoint);
    var changed = false;
    final nextStrokes = <_DrawingStroke>[];

    for (final stroke in _strokes) {
      final clipped = _clipStrokeByEraser(
        stroke: stroke,
        center: target,
        radius: eraserWorldRadius,
      );

      if (clipped.length != 1 || !identical(clipped.first, stroke)) {
        changed = true;
      }
      nextStrokes.addAll(clipped);
    }

    if (!changed) {
      return;
    }

    setState(() {
      _strokes
        ..clear()
        ..addAll(nextStrokes);
      _hasUnsavedChanges = true;
    });
  }

  List<_DrawingStroke> _clipStrokeByEraser({
    required _DrawingStroke stroke,
    required Offset center,
    required double radius,
  }) {
    if (stroke.points.isEmpty) {
      return <_DrawingStroke>[];
    }

    final effectiveRadius = radius + (stroke.width / 2);
    final radiusSq = effectiveRadius * effectiveRadius;

    bool isInside(Offset point) {
      final delta = point - center;
      return delta.dx * delta.dx + delta.dy * delta.dy <= radiusSq;
    }

    if (stroke.points.length == 1) {
      return isInside(stroke.points.first) ? <_DrawingStroke>[] : [stroke];
    }

    final fragments = <List<Offset>>[];
    List<Offset>? current;

    for (var i = 0; i < stroke.points.length - 1; i++) {
      final start = stroke.points[i];
      final end = stroke.points[i + 1];
      final startInside = isInside(start);
      final endInside = isInside(end);
      final intersections = _segmentCircleIntersections(
        start: start,
        end: end,
        center: center,
        radius: effectiveRadius,
      );

      if (!startInside && !endInside) {
        if (intersections.length < 2) {
          current ??= [start];
          current.add(end);
          continue;
        }

        final entry = Offset.lerp(start, end, intersections.first)!;
        final exit = Offset.lerp(start, end, intersections.last)!;

        current ??= [start];
        current.add(entry);
        if (current.length > 1) {
          fragments.add(current);
        }
        current = [exit, end];
        continue;
      }

      if (!startInside && endInside) {
        final t = intersections.isNotEmpty ? intersections.first : 1.0;
        final entry = Offset.lerp(start, end, t)!;

        current ??= [start];
        current.add(entry);
        if (current.length > 1) {
          fragments.add(current);
        }
        current = null;
        continue;
      }

      if (startInside && !endInside) {
        final t = intersections.isNotEmpty ? intersections.last : 0.0;
        final exit = Offset.lerp(start, end, t)!;
        current = [exit, end];
        continue;
      }

      // Segment remains fully inside erased area.
      current = null;
    }

    if (current != null && current.length > 1) {
      fragments.add(current);
    }

    if (fragments.isEmpty) {
      return <_DrawingStroke>[];
    }

    return fragments
        .map(
          (points) => _DrawingStroke(
            color: stroke.color,
            width: stroke.width,
            points: _dedupeAdjacentPoints(points),
          ),
        )
        .where((clipped) => clipped.points.isNotEmpty)
        .toList();
  }

  List<Offset> _dedupeAdjacentPoints(List<Offset> points) {
    if (points.isEmpty) {
      return points;
    }

    const epsilon = 0.0001;
    final deduped = <Offset>[points.first];
    for (var i = 1; i < points.length; i++) {
      final previous = deduped.last;
      final current = points[i];
      if ((current - previous).distanceSquared > epsilon) {
        deduped.add(current);
      }
    }
    return deduped;
  }

  List<double> _segmentCircleIntersections({
    required Offset start,
    required Offset end,
    required Offset center,
    required double radius,
  }) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final fx = start.dx - center.dx;
    final fy = start.dy - center.dy;

    final a = dx * dx + dy * dy;
    if (a == 0) {
      return const [];
    }

    final b = 2 * (fx * dx + fy * dy);
    final c = fx * fx + fy * fy - radius * radius;

    final discriminant = b * b - 4 * a * c;
    if (discriminant < 0) {
      return const [];
    }

    final sqrtDisc = math.sqrt(discriminant);
    final t1 = (-b - sqrtDisc) / (2 * a);
    final t2 = (-b + sqrtDisc) / (2 * a);

    const epsilon = 0.000001;
    final intersections = <double>[];
    if (t1 > epsilon && t1 < 1 - epsilon) {
      intersections.add(t1);
    }
    if (t2 > epsilon && t2 < 1 - epsilon) {
      intersections.add(t2);
    }

    intersections.sort();
    if (intersections.length == 2 &&
        (intersections[1] - intersections[0]).abs() < epsilon) {
      return [intersections.first];
    }
    return intersections;
  }

  void _startMiddlePan(PointerDownEvent event) {
    _isMiddlePanning = true;
    _middlePanPointer = event.pointer;
    _lastPanPosition = event.localPosition;
    _activeStroke = null;
    _pageFocusNode.requestFocus();
  }

  void _updateMiddlePan(PointerMoveEvent event) {
    if (!_isMiddlePanning || _middlePanPointer != event.pointer) {
      return;
    }

    final previous = _lastPanPosition;
    _lastPanPosition = event.localPosition;
    if (previous == null) {
      return;
    }

    _panCanvas(event.localPosition - previous);
  }

  void _endMiddlePan(int pointer) {
    if (_middlePanPointer != pointer) {
      return;
    }
    _isMiddlePanning = false;
    _middlePanPointer = null;
    _lastPanPosition = null;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }

    final zoomDelta = event.scrollDelta.dy < 0 ? 1.1 : 0.9;
    final nextScale = (_canvasScale * zoomDelta).clamp(0.2, 6.0);
    if (nextScale == _canvasScale) {
      return;
    }

    final cursor = event.localPosition;
    final worldAtCursor = (cursor - _canvasOffset) / _canvasScale;

    setState(() {
      _canvasScale = nextScale;
      _canvasOffset = cursor - (worldAtCursor * _canvasScale);
    });
    _scheduleViewportSave();
  }

  @override
  Widget build(BuildContext context) {
    final drawingName = widget.drawingFile.path
        .split(Platform.pathSeparator)
        .last
        .replaceAll('.json', '');

    final palette = <Color>[
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
    ];

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ):
            const _UndoCanvasIntent(),
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyZ):
            const _UndoCanvasIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _UndoCanvasIntent: CallbackAction<_UndoCanvasIntent>(
            onInvoke: (intent) {
              _undo();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          focusNode: _pageFocusNode,
          child: WillPopScope(
            onWillPop: _confirmExitIfNeeded,
            child: Scaffold(
              backgroundColor: Colors.blueGrey[50],
              appBar: AppBar(
                title: Text('Drawing - $drawingName'),
                backgroundColor: Colors.blueGrey[900],
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () async {
                    final shouldLeave = await _confirmExitIfNeeded();
                    if (!mounted || !shouldLeave) {
                      return;
                    }
                    Navigator.of(context).pop();
                  },
                ),
                actions: [
                  IconButton(
                    tooltip: 'Undo (Ctrl+Z)',
                    onPressed: _undo,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: _clearCanvas,
                    icon: const Icon(Icons.delete_sweep),
                  ),
                  IconButton(
                    tooltip: 'Save',
                    onPressed: _isSaving
                        ? null
                        : () {
                            _saveDrawing();
                          },
                    icon: const Icon(Icons.save),
                  ),
                ],
              ),
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 250,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blueGrey.shade100),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Text(
                            'Tools',
                            style: TextStyle(
                              color: Colors.blueGrey[900],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    _activeTool == _CanvasTool.pencil
                                    ? Colors.blueGrey[700]
                                    : Colors.blueGrey[500],
                              ),
                              onPressed: () {
                                setState(() {
                                  _activeTool = _CanvasTool.pencil;
                                });
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Pencil'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    _activeTool == _CanvasTool.eraser
                                    ? Colors.blueGrey[700]
                                    : Colors.blueGrey[500],
                              ),
                              onPressed: () {
                                setState(() {
                                  _activeTool = _CanvasTool.eraser;
                                  _activeStroke = null;
                                });
                              },
                              icon: const Icon(Icons.auto_fix_normal),
                              label: const Text('Eraser'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: _activeTool == _CanvasTool.hand
                                    ? Colors.blueGrey[700]
                                    : Colors.blueGrey[500],
                              ),
                              onPressed: () {
                                setState(() {
                                  _activeTool = _CanvasTool.hand;
                                  _activeStroke = null;
                                });
                              },
                              icon: const Icon(Icons.pan_tool_alt),
                              label: const Text('Hand'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _undo,
                              icon: const Icon(Icons.undo),
                              label: const Text('Undo (Ctrl+Z)'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red[700],
                              ),
                              onPressed: _clearCanvas,
                              icon: const Icon(Icons.delete_sweep),
                              label: const Text('Clear'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isSaving ? null : _saveDrawing,
                              icon: const Icon(Icons.save),
                              label: Text(_isSaving ? 'Saving...' : 'Save'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Color',
                            style: TextStyle(
                              color: Colors.blueGrey[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: palette.map((color) {
                              final selected =
                                  color.value == _selectedColor.value;
                              return InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () {
                                  setState(() {
                                    _selectedColor = color;
                                  });
                                },
                                child: Container(
                                  width: selected ? 32 : 28,
                                  height: selected ? 32 : 28,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected
                                          ? Colors.blueGrey[900]!
                                          : Colors.white,
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Brush Width',
                            style: TextStyle(
                              color: Colors.blueGrey[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Slider(
                            value: _strokeWidth,
                            min: 1,
                            max: 24,
                            label: _strokeWidth.toStringAsFixed(0),
                            onChanged: (value) {
                              setState(() {
                                _strokeWidth = value;
                              });
                            },
                          ),
                          Text(
                            'Current: ${_strokeWidth.toStringAsFixed(0)} px',
                            style: TextStyle(color: Colors.blueGrey[600]),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Eraser Size',
                            style: TextStyle(
                              color: Colors.blueGrey[800],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Slider(
                            value: _eraserSize,
                            min: 8,
                            max: 60,
                            label: _eraserSize.toStringAsFixed(0),
                            onChanged: (value) {
                              setState(() {
                                _eraserSize = value;
                              });
                            },
                          ),
                          Text(
                            'Current: ${_eraserSize.toStringAsFixed(0)} px',
                            style: TextStyle(color: Colors.blueGrey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pencil: draw\nEraser: erase area\nHand: pan\nMiddle mouse: pan\nWheel: zoom',
                            style: TextStyle(color: Colors.blueGrey[600]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Zoom: ${(_canvasScale * 100).toStringAsFixed(0)}%',
                            style: TextStyle(color: Colors.blueGrey[600]),
                          ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blueGrey.shade200),
                        ),
                        child: Listener(
                          onPointerSignal: _handlePointerSignal,
                          onPointerDown: (event) {
                            if (_activeTool == _CanvasTool.pencil ||
                                _activeTool == _CanvasTool.eraser) {
                              setState(() {
                                _cursorLocalPosition = event.localPosition;
                              });
                            }
                            if ((event.buttons & kMiddleMouseButton) != 0) {
                              _startMiddlePan(event);
                            }
                          },
                          onPointerMove: (event) {
                            if (_activeTool == _CanvasTool.pencil ||
                                _activeTool == _CanvasTool.eraser) {
                              setState(() {
                                _cursorLocalPosition = event.localPosition;
                              });
                            }
                            _updateMiddlePan(event);
                          },
                          onPointerUp: (event) => _endMiddlePan(event.pointer),
                          onPointerCancel: (event) =>
                              _endMiddlePan(event.pointer),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: MouseRegion(
                              onEnter: (event) {
                                setState(() {
                                  _isPointerOnCanvas = true;
                                  _cursorLocalPosition = event.localPosition;
                                });
                              },
                              onHover: (event) {
                                if (_activeTool != _CanvasTool.pencil &&
                                    _activeTool != _CanvasTool.eraser) {
                                  return;
                                }
                                setState(() {
                                  _cursorLocalPosition = event.localPosition;
                                });
                              },
                              onExit: (_) {
                                setState(() {
                                  _isPointerOnCanvas = false;
                                  _cursorLocalPosition = null;
                                });
                              },
                              child: GestureDetector(
                                onPanDown: (details) {
                                  _pageFocusNode.requestFocus();
                                  if (_activeTool == _CanvasTool.pencil ||
                                      _activeTool == _CanvasTool.eraser) {
                                    setState(() {
                                      _cursorLocalPosition =
                                          details.localPosition;
                                    });
                                  }
                                },
                                onPanStart: (details) {
                                  if (_isMiddlePanning) {
                                    return;
                                  }
                                  if (_activeTool == _CanvasTool.pencil ||
                                      _activeTool == _CanvasTool.eraser) {
                                    _cursorLocalPosition = details.localPosition;
                                  }
                                  if (_activeTool == _CanvasTool.hand) {
                                    return;
                                  }
                                  if (_activeTool == _CanvasTool.eraser) {
                                    _eraseAt(details.localPosition);
                                    return;
                                  }
                                  _startStroke(details.localPosition);
                                },
                                onPanUpdate: (details) {
                                  if (_isMiddlePanning) {
                                    return;
                                  }
                                  if (_activeTool == _CanvasTool.pencil ||
                                      _activeTool == _CanvasTool.eraser) {
                                    _cursorLocalPosition = details.localPosition;
                                  }
                                  if (_activeTool == _CanvasTool.hand) {
                                    _panCanvas(details.delta);
                                    return;
                                  }
                                  if (_activeTool == _CanvasTool.eraser) {
                                    _eraseAt(details.localPosition);
                                    return;
                                  }
                                  _appendPoint(details.localPosition);
                                },
                                onPanEnd: (_) {
                                  if (_isMiddlePanning) {
                                    return;
                                  }
                                  if (_activeTool != _CanvasTool.pencil) {
                                    return;
                                  }
                                  _endStroke();
                                },
                                child: CustomPaint(
                                  painter: _DrawingPainter(
                                    strokes: List<_DrawingStroke>.of(_strokes),
                                    activeStroke: _activeStroke,
                                    canvasOffset: _canvasOffset,
                                    canvasScale: _canvasScale,
                                    cursorLocalPosition: _cursorLocalPosition,
                                    cursorScreenRadius: _cursorScreenRadius,
                                    showCursor: _shouldShowToolCursor,
                                    isEraserCursor:
                                        _activeTool == _CanvasTool.eraser,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UndoCanvasIntent extends Intent {
  const _UndoCanvasIntent();
}

class _DrawingTile extends StatelessWidget {
  const _DrawingTile({
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
            leading: const Icon(Icons.brush, color: Colors.white),
            title: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  tooltip: 'Rename drawing',
                  onPressed: onRename,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  tooltip: 'Delete drawing',
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

class _DrawingStroke {
  _DrawingStroke({
    required this.color,
    required this.width,
    required this.points,
  });

  final Color color;
  final double width;
  final List<Offset> points;

  factory _DrawingStroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    final points = <Offset>[];

    if (rawPoints is List) {
      for (final point in rawPoints) {
        if (point is Map<String, dynamic>) {
          final dx = (point['x'] as num?)?.toDouble();
          final dy = (point['y'] as num?)?.toDouble();
          if (dx != null && dy != null) {
            points.add(Offset(dx, dy));
          }
        }
      }
    }

    final rawColor = json['color'];
    Color color = Colors.black;
    if (rawColor is int) {
      color = Color(rawColor);
    } else if (rawColor is String) {
      final cleaned = rawColor.startsWith('#')
          ? rawColor.substring(1)
          : rawColor;
      final parsed = int.tryParse(cleaned, radix: 16);
      if (parsed != null) {
        color = cleaned.length <= 6
            ? Color(0xFF000000 | parsed)
            : Color(parsed);
      }
    }

    final width = (json['width'] as num?)?.toDouble() ?? 3;

    return _DrawingStroke(color: color, width: width, points: points);
  }

  Map<String, dynamic> toJson() {
    return {
      'color': color.value,
      'width': width,
      'points': points
          .map((p) => <String, double>{'x': p.dx, 'y': p.dy})
          .toList(),
    };
  }
}

class _DrawingDocument {
  const _DrawingDocument({required this.strokes, required this.viewport});

  factory _DrawingDocument.empty() {
    return const _DrawingDocument(
      strokes: <_DrawingStroke>[],
      viewport: _DrawingViewport(scale: 1, offset: Offset.zero),
    );
  }

  final List<_DrawingStroke> strokes;
  final _DrawingViewport viewport;

  _DrawingDocument copyWith({
    List<_DrawingStroke>? strokes,
    _DrawingViewport? viewport,
  }) {
    return _DrawingDocument(
      strokes: strokes ?? this.strokes,
      viewport: viewport ?? this.viewport,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
      'viewport': viewport.toJson(),
    };
  }
}

class _DrawingViewport {
  const _DrawingViewport({required this.scale, required this.offset});

  factory _DrawingViewport.fromJson(Object? json) {
    if (json is! Map) {
      return const _DrawingViewport(scale: 1, offset: Offset.zero);
    }

    final data = Map<String, dynamic>.from(json);
    final scale = (data['scale'] as num?)?.toDouble() ?? 1;
    final offsetData = data['offset'];
    Offset offset = Offset.zero;
    if (offsetData is Map) {
      final typedOffset = Map<String, dynamic>.from(offsetData);
      offset = Offset(
        (typedOffset['x'] as num?)?.toDouble() ?? 0,
        (typedOffset['y'] as num?)?.toDouble() ?? 0,
      );
    }

    return _DrawingViewport(scale: scale, offset: offset);
  }

  final double scale;
  final Offset offset;

  Map<String, dynamic> toJson() {
    return {
      'scale': scale,
      'offset': {'x': offset.dx, 'y': offset.dy},
    };
  }
}

class _DrawingPainter extends CustomPainter {
  const _DrawingPainter({
    required this.strokes,
    required this.activeStroke,
    required this.canvasOffset,
    required this.canvasScale,
    required this.cursorLocalPosition,
    required this.cursorScreenRadius,
    required this.showCursor,
    required this.isEraserCursor,
  });

  final List<_DrawingStroke> strokes;
  final _DrawingStroke? activeStroke;
  final Offset canvasOffset;
  final double canvasScale;
  final Offset? cursorLocalPosition;
  final double cursorScreenRadius;
  final bool showCursor;
  final bool isEraserCursor;

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);

    canvas.save();
    canvas.translate(canvasOffset.dx, canvasOffset.dy);
    canvas.scale(canvasScale);
    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }
    if (activeStroke != null) {
      _paintStroke(canvas, activeStroke!);
    }
    canvas.restore();

    if (showCursor && cursorLocalPosition != null) {
      _paintToolCursor(canvas, cursorLocalPosition!);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    const spacing = 40.0;
    final scaledSpacing = spacing * canvasScale;
    if (scaledSpacing <= 0) {
      return;
    }

    final paint = Paint()
      ..color = const Color(0xFFE6EBF0)
      ..strokeWidth = 1;

    var startX = canvasOffset.dx % scaledSpacing;
    if (startX < 0) {
      startX += scaledSpacing;
    }
    for (var x = startX; x <= size.width; x += scaledSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    var startY = canvasOffset.dy % scaledSpacing;
    if (startY < 0) {
      startY += scaledSpacing;
    }
    for (var y = startY; y <= size.height; y += scaledSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintStroke(Canvas canvas, _DrawingStroke stroke) {
    if (stroke.points.isEmpty) {
      return;
    }

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points.first, stroke.width / 2, paint);
      return;
    }

    final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (var i = 1; i < stroke.points.length; i++) {
      final p = stroke.points[i];
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  void _paintToolCursor(Canvas canvas, Offset center) {
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = isEraserCursor
          ? const Color(0xFFE53935)
          : const Color(0xFF111827);

    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xB3FFFFFF);

    final radius = cursorScreenRadius.clamp(2.0, 160.0);
    canvas.drawCircle(center, radius, haloPaint);
    canvas.drawCircle(center, radius, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.activeStroke != activeStroke ||
        oldDelegate.canvasOffset != canvasOffset ||
        oldDelegate.canvasScale != canvasScale ||
        oldDelegate.cursorLocalPosition != cursorLocalPosition ||
        oldDelegate.cursorScreenRadius != cursorScreenRadius ||
        oldDelegate.showCursor != showCursor ||
        oldDelegate.isEraserCursor != isEraserCursor;
  }
}
