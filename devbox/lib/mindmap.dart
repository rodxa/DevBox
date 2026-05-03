import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class MindmapNode {
  MindmapNode({
    required this.id,
    required this.type,
    required this.position,
    this.label = '',
    this.textAreaContent = '',
    List<String>? listItems,
    this.imagePath = '',
    this.hyperlinkUrl = '',
    this.hyperlinkLabel = '',
    this.colorValue,
  }) : listItems = listItems ?? [];

  static const double nodeWidth = 180.0;
  static const double nodeHeight = 56.0;

  final int id;
  final String type;
  String label;
  String textAreaContent;
  String imagePath;
  String hyperlinkUrl;
  String hyperlinkLabel;
  int? colorValue;
  final List<String> listItems;
  Offset position;

  String get displayLabel => label.isNotEmpty ? label : type;

  MindmapNode copyWith({
    int? id,
    String? type,
    String? label,
    String? textAreaContent,
    String? imagePath,
    String? hyperlinkUrl,
    String? hyperlinkLabel,
    int? colorValue,
    List<String>? listItems,
    Offset? position,
  }) {
    return MindmapNode(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      textAreaContent: textAreaContent ?? this.textAreaContent,
      imagePath: imagePath ?? this.imagePath,
      hyperlinkUrl: hyperlinkUrl ?? this.hyperlinkUrl,
      hyperlinkLabel: hyperlinkLabel ?? this.hyperlinkLabel,
      colorValue: colorValue ?? this.colorValue,
      listItems: listItems ?? List<String>.from(this.listItems),
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'label': label,
    'textAreaContent': textAreaContent,
    'imagePath': imagePath,
    'hyperlinkUrl': hyperlinkUrl,
    'hyperlinkLabel': hyperlinkLabel,
    'colorValue': colorValue,
    'listItems': listItems,
    'position': {'x': position.dx, 'y': position.dy},
  };

  static MindmapNode fromJson(Map<String, dynamic> n) => MindmapNode(
    id: n['id'] as int,
    type: n['type'] as String,
    label: (n['label'] as String?) ?? '',
    textAreaContent: (n['textAreaContent'] as String?) ?? '',
    imagePath: (n['imagePath'] as String?) ?? '',
    hyperlinkUrl: (n['hyperlinkUrl'] as String?) ?? '',
    hyperlinkLabel: (n['hyperlinkLabel'] as String?) ?? '',
    colorValue: n['colorValue'] as int?,
    listItems: ((n['listItems'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList(),
    position: Offset(
      (n['position']['x'] as num).toDouble(),
      (n['position']['y'] as num).toDouble(),
    ),
  );
}

class MindmapEdge {
  const MindmapEdge({required this.fromId, required this.toId});
  final int fromId;
  final int toId;

  @override
  bool operator ==(Object other) =>
      other is MindmapEdge && other.fromId == fromId && other.toId == toId;

  @override
  int get hashCode => Object.hash(fromId, toId);
}

double _measureTextHeight({
  required String text,
  required TextStyle style,
  required double maxWidth,
  int? maxLines,
}) {
  if (text.trim().isEmpty) return 0;
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: maxLines,
    ellipsis: maxLines != null ? '...' : null,
  )..layout(maxWidth: maxWidth);
  return tp.height;
}

double _nodeHeaderHeight(MindmapNode node) {
  final measured = _measureTextHeight(
    text: node.displayLabel,
    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
    maxWidth: MindmapNode.nodeWidth - 16,
  );
  return math.max(MindmapNode.nodeHeight, measured + 18);
}

// Extra body height below the header for expanded content
double _nodeExtraHeight(MindmapNode node) {
  if (node.type == 'TextArea') {
    final content = node.textAreaContent.trim();
    if (content.isEmpty) return 0;
    final measured = _measureTextHeight(
      text: content,
      style: const TextStyle(color: Colors.white, fontSize: 12),
      maxWidth: MindmapNode.nodeWidth - 16,
    );
    return measured + 12;
  }
  if (node.type == 'List' && node.listItems.isNotEmpty) {
    return node.listItems.length * 20.0 + 8;
  }
  if (node.type == 'Image' && node.imagePath.isNotEmpty) {
    return 80.0;
  }
  if (node.type == 'Hyperlink') {
    return 48.0;
  }
  return 0;
}

Rect _nodeBodyRect(MindmapNode node, Offset canvasOffset) {
  final center = node.position + canvasOffset;
  final headerH = _nodeHeaderHeight(node);
  final extraH = _nodeExtraHeight(node);
  final totalH = headerH + extraH;
  return Rect.fromCenter(
    center: Offset(center.dx, center.dy + (totalH - MindmapNode.nodeHeight) / 2),
    width: MindmapNode.nodeWidth,
    height: totalH,
  );
}

Rect _hyperlinkButtonRect(MindmapNode node, Offset canvasOffset) {
  final nodeRect = _nodeBodyRect(node, canvasOffset);
  final headerH = _nodeHeaderHeight(node);
  return Rect.fromLTWH(
    nodeRect.left + 10,
    nodeRect.top + headerH + 10,
    nodeRect.width - 20,
    28,
  );
}

// Returns the canvas-local position of a node's connector dot.
// Top edge stays anchored by base nodeHeight while total height grows downward.
Offset _nodeDotPosition(MindmapNode node, Offset canvasOffset) {
  final center = node.position + canvasOffset;
  final headerH = _nodeHeaderHeight(node);
  return Offset(
    center.dx + MindmapNode.nodeWidth / 2 + 8,
    center.dy - MindmapNode.nodeHeight / 2 + headerH / 2,
  );
}

// Compute the bezier control points for an edge between two rendered node bodies.
// Returns (fromPt, cp1, cp2, toPt).
_EdgePath _computeEdgePath(MindmapNode fromNode, MindmapNode toNode) {
  final fromRect = _nodeBodyRect(fromNode, Offset.zero);
  final toRect = _nodeBodyRect(toNode, Offset.zero);
  final fromCenter = fromRect.center;
  final toCenter = toRect.center;

  final dx = toCenter.dx - fromCenter.dx;
  final dy = toCenter.dy - fromCenter.dy;

  final Offset fromPt;
  final Offset toPt;
  if (dx.abs() >= dy.abs()) {
    final s = dx >= 0 ? 1.0 : -1.0;
    fromPt = Offset(
      s > 0 ? fromRect.right : fromRect.left,
      fromRect.center.dy,
    );
    toPt = Offset(
      s > 0 ? toRect.left : toRect.right,
      toRect.center.dy,
    );
  } else {
    final s = dy >= 0 ? 1.0 : -1.0;
    fromPt = Offset(
      fromRect.center.dx,
      s > 0 ? fromRect.bottom : fromRect.top,
    );
    toPt = Offset(
      toRect.center.dx,
      s > 0 ? toRect.top : toRect.bottom,
    );
  }

  final midX = (fromPt.dx + toPt.dx) / 2;
  final midY = (fromPt.dy + toPt.dy) / 2;
  final Offset cp1;
  final Offset cp2;
  if (dx.abs() >= dy.abs()) {
    cp1 = Offset(midX, fromPt.dy);
    cp2 = Offset(midX, toPt.dy);
  } else {
    cp1 = Offset(fromPt.dx, midY);
    cp2 = Offset(toCenter.dx, midY);
  }
  return _EdgePath(fromPt, cp1, cp2, toPt);
}

class _EdgePath {
  const _EdgePath(this.fromPt, this.cp1, this.cp2, this.toPt);
  final Offset fromPt, cp1, cp2, toPt;

  Path toPath() => Path()
    ..moveTo(fromPt.dx, fromPt.dy)
    ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, toPt.dx, toPt.dy);

  // Sample the cubic bezier and return min distance to [point]
  double minDistanceTo(Offset point, {int samples = 60}) {
    double minD = double.infinity;
    for (int i = 0; i <= samples; i++) {
      final t = i / samples;
      final mt = 1 - t;
      final px = mt*mt*mt*fromPt.dx + 3*mt*mt*t*cp1.dx + 3*mt*t*t*cp2.dx + t*t*t*toPt.dx;
      final py = mt*mt*mt*fromPt.dy + 3*mt*mt*t*cp1.dy + 3*mt*t*t*cp2.dy + t*t*t*toPt.dy;
      final d = (Offset(px, py) - point).distance;
      if (d < minD) minD = d;
    }
    return minD;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main widget
// ─────────────────────────────────────────────────────────────────────────────

class Mindmap extends StatefulWidget {
  const Mindmap({Key? key, required this.mindmapFile}) : super(key: key);
  final File mindmapFile;

  @override
  State<Mindmap> createState() => _MindmapState();
}

class _MindmapState extends State<Mindmap> {
  final List<String> _nodeTypes = ['Label', 'TextArea', 'Image', 'List', 'Hyperlink'];

  final List<MindmapNode> _nodes = [];
  final List<MindmapEdge> _edges = [];

  Offset _canvasOffset = Offset.zero;
  double _canvasScale = 1.0;
  Size _canvasSize = Size.zero;
  Offset _lastSavedViewportOffset = Offset.zero;
  double _lastSavedViewportScale = 1.0;

  bool _isMiddleDragging = false;
  int? _draggingNodeId;

  bool _isSaving = false;
  bool _isDirty = false;

  // Connect-by-drag state
  bool _connectDragActive = false;
  int? _connectDragSourceId;
  Offset? _connectDragCurrentPos; // world position

  // Hyperlink button interaction state
  int? _hoverHyperlinkNodeId;
  int? _pressedHyperlinkNodeId;

  // Image cache: imagePath → decoded ui.Image
  final Map<String, ui.Image> _imageCache = {};

  Future<void> _loadImages() async {
    final paths = _nodes
        .where((n) => n.type == 'Image' && n.imagePath.isNotEmpty)
        .map((n) => n.imagePath)
        .toSet();
    _imageCache.removeWhere((k, _) => !paths.contains(k));
    for (final path in paths) {
      if (_imageCache.containsKey(path)) continue;
      try {
        final bytes = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes,
            targetWidth: MindmapNode.nodeWidth.toInt() * 2);
        final frame = await codec.getNextFrame();
        if (mounted) {
          _imageCache[path] = frame.image;
          setState(() {});
        }
      } catch (_) {}
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFromFile();
  }

  void _loadFromFile() {
    try {
      if (!widget.mindmapFile.existsSync()) return;
      final content = widget.mindmapFile.readAsStringSync();
      if (content.trim().isEmpty) return;
      final data = jsonDecode(content) as Map<String, dynamic>;
      final nodeList = data['nodes'] as List<dynamic>? ?? [];
      final edgeList = data['edges'] as List<dynamic>? ?? [];
      final viewport = data['viewport'] as Map<String, dynamic>?;
      final offset = viewport?['offset'] as Map<String, dynamic>?;
      final loadedOffset = Offset(
        ((offset?['x'] as num?) ?? 0).toDouble(),
        ((offset?['y'] as num?) ?? 0).toDouble(),
      );
      final loadedScale = ((viewport?['scale'] as num?) ?? 1.0).toDouble().clamp(0.3, 3.0);
      setState(() {
        _nodes.clear();
        for (final n in nodeList) _nodes.add(MindmapNode.fromJson(n as Map<String, dynamic>));
        _edges.clear();
        for (final e in edgeList) _edges.add(MindmapEdge(fromId: e['fromId'] as int, toId: e['toId'] as int));
        _canvasOffset = loadedOffset;
        _canvasScale = loadedScale;
        _lastSavedViewportOffset = loadedOffset;
        _lastSavedViewportScale = loadedScale;
      });
      _loadImages();
    } catch (_) {}
  }

  Future<void> _saveToFile() async {
    setState(() => _isSaving = true);
    try {
      final data = {
        'nodes': _nodes.map((n) => n.toJson()).toList(),
        'edges': _edges.map((e) => {'fromId': e.fromId, 'toId': e.toId}).toList(),
        'viewport': {
          'offset': {'x': _canvasOffset.dx, 'y': _canvasOffset.dy},
          'scale': _canvasScale,
        },
      };
      await widget.mindmapFile.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      if (mounted) setState(() => _isDirty = false);
      _lastSavedViewportOffset = _canvasOffset;
      _lastSavedViewportScale = _canvasScale;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool get _hasViewportChanges {
    return (_canvasOffset - _lastSavedViewportOffset).distance > 0.01 ||
        (_canvasScale - _lastSavedViewportScale).abs() > 0.0001;
  }

  Future<void> _saveViewportOnlyIfChanged() async {
    if (!_hasViewportChanges) return;
    try {
      Map<String, dynamic> data = <String, dynamic>{};
      if (widget.mindmapFile.existsSync()) {
        final content = widget.mindmapFile.readAsStringSync();
        if (content.trim().isNotEmpty) {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            data = decoded;
          }
        }
      }

      data['viewport'] = {
        'offset': {'x': _canvasOffset.dx, 'y': _canvasOffset.dy},
        'scale': _canvasScale,
      };

      if (!data.containsKey('nodes')) data['nodes'] = const [];
      if (!data.containsKey('edges')) data['edges'] = const [];

      await widget.mindmapFile.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      _lastSavedViewportOffset = _canvasOffset;
      _lastSavedViewportScale = _canvasScale;
    } catch (_) {}
  }

  Future<void> _maybeLeave() async {
    if (!_isDirty) {
      await _saveViewportOnlyIfChanged();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: const Text('Unsaved changes'),
        content: const Text('You have unsaved changes. Do you want to save before leaving?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop('cancel'), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop('discard'), child: const Text('Discard')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop('save'), child: const Text('Save')),
        ],
      ),
    );
    if (!mounted) return;
    if (result == 'save') {
      await _saveToFile();
      if (mounted) Navigator.of(context).pop();
    } else if (result == 'discard') {
      await _saveViewportOnlyIfChanged();
      if (mounted) Navigator.of(context).pop();
    }
  }

  // ── Node editing dialogs ───────────────────────────────────────────────────

  Future<void> _editNode(MindmapNode node) async {
    switch (node.type) {
      case 'List':
        await _editListNode(node);
        break;
      case 'TextArea':
        await _editTextAreaNode(node);
        break;
      case 'Image':
        await _editImageNode(node);
        break;
      case 'Hyperlink':
        await _editHyperlinkNode(node);
        break;
      default:
        await _editLabelDialog(node);
    }
  }

  Future<void> _editTextAreaNode(MindmapNode node) async {
    final index = _nodes.indexWhere((n) => n.id == node.id);
    if (index < 0) return;
    final labelCtrl = TextEditingController(text: node.label);
    final contentCtrl = TextEditingController(text: node.textAreaContent);
    double hue = _initialHueForNode(node);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSB) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Edit TextArea node'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Node label',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentCtrl,
                  minLines: 6,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Text content',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                _buildColorSlider(hue, (v) => setSB(() => hue = v)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _nodes[index].label = labelCtrl.text.trim();
                  _nodes[index].textAreaContent = contentCtrl.text.trim();
                  _nodes[index].colorValue = _colorFromHue(hue).value;
                  _isDirty = true;
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editHyperlinkNode(MindmapNode node) async {
    final index = _nodes.indexWhere((n) => n.id == node.id);
    if (index < 0) return;
    final urlCtrl = TextEditingController(text: node.hyperlinkUrl);
    final labelCtrl = TextEditingController(text: node.hyperlinkLabel);
    double hue = _initialHueForNode(node);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSB) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Edit Hyperlink node'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL',
                    hintText: 'https://example.com',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL label',
                    hintText: 'Open website',
                    border: OutlineInputBorder(),
                  ),
                ),
                _buildColorSlider(hue, (v) => setSB(() => hue = v)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final rawUrl = urlCtrl.text.trim();
                setState(() {
                  _nodes[index].hyperlinkUrl = rawUrl.isNotEmpty && !rawUrl.contains('://') ? 'https://$rawUrl' : rawUrl;
                  _nodes[index].hyperlinkLabel = labelCtrl.text.trim();
                  _nodes[index].colorValue = _colorFromHue(hue).value;
                  _isDirty = true;
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openHyperlink(String url) async {
    final clean = url.trim();
    if (clean.isEmpty) return;
    try {
      if (Platform.isWindows) {
        final escaped = clean.replaceAll('"', '""');
        await Process.run('powershell', [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          'Start-Process "$escaped"',
        ]);
      } else {
        await Process.start(clean, []);
      }
    } catch (_) {}
  }

  Offset _toWorld(Offset screenPos) {
    return Offset(
      (screenPos.dx - _canvasOffset.dx) / _canvasScale,
      (screenPos.dy - _canvasOffset.dy) / _canvasScale,
    );
  }

  void _applyZoomAt(Offset screenPos, double factor) {
    final oldScale = _canvasScale;
    final newScale = (oldScale * factor).clamp(0.3, 3.0);
    if (newScale == oldScale) return;
    final worldUnderCursor = _toWorld(screenPos);
    setState(() {
      _canvasScale = newScale;
      _canvasOffset = screenPos - worldUnderCursor * newScale;
    });
  }

  Color _defaultTypeColor(String type) {
    switch (type) {
      case 'Label':
        return const Color(0xFF5C8DDE);
      case 'TextArea':
        return const Color(0xFF4EAD8A);
      case 'Image':
        return const Color(0xFFE08A45);
      case 'List':
        return const Color(0xFF9B6DB5);
      case 'Hyperlink':
        return const Color(0xFF4EA8C8);
      default:
        return const Color(0xFF607D8B);
    }
  }

  Color _colorFromHue(double hue) {
    return HSLColor.fromAHSL(1, hue, 0.55, 0.5).toColor();
  }

  double _initialHueForNode(MindmapNode node) {
    final base = node.colorValue != null ? Color(node.colorValue!) : _defaultTypeColor(node.type);
    return HSLColor.fromColor(base).hue;
  }

  Widget _buildColorSlider(double hue, void Function(double) onChanged) {
    final color = _colorFromHue(hue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3), border: Border.all(color: Colors.black12)),
            ),
            const SizedBox(width: 8),
            const Text('Node color', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        Slider(
          min: 0,
          max: 360,
          divisions: 360,
          value: hue,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _editLabelDialog(MindmapNode node) async {
    final index = _nodes.indexWhere((n) => n.id == node.id);
    if (index < 0) return;
    final controller = TextEditingController(text: node.displayLabel);
    double hue = _initialHueForNode(node);
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSB) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Edit node label'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Label', border: OutlineInputBorder()),
                ),
                _buildColorSlider(hue, (v) => setSB(() => hue = v)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _nodes[index].label = controller.text.trim();
                  _nodes[index].colorValue = _colorFromHue(hue).value;
                  _isDirty = true;
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editListNode(MindmapNode node) async {
    final index = _nodes.indexWhere((n) => n.id == node.id);
    if (index < 0) return;
    final items = List<String>.from(node.listItems);
    final labelCtrl = TextEditingController(text: node.label);
    final addCtrl = TextEditingController();
    double hue = _initialHueForNode(node);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setS) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            title: const Text('Edit List node'),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(labelText: 'Node label', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const Align(alignment: Alignment.centerLeft, child: Text('List items', style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        return ListTile(
                          key: ValueKey(i),
                          dense: true,
                          title: Text(items[i]),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, size: 18),
                            onPressed: () => setS(() => items.removeAt(i)),
                          ),
                        );
                      },
                      onReorder: (oldI, newI) {
                        setS(() {
                          if (newI > oldI) newI--;
                          final item = items.removeAt(oldI);
                          items.insert(newI, item);
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: addCtrl,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(hintText: 'New item…', isDense: true, border: OutlineInputBorder()),
                          onSubmitted: (v) {
                            if (v.trim().isNotEmpty) setS(() { items.add(v.trim()); addCtrl.clear(); });
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          if (addCtrl.text.trim().isNotEmpty) setS(() { items.add(addCtrl.text.trim()); addCtrl.clear(); });
                        },
                      ),
                    ],
                  ),
                  _buildColorSlider(hue, (v) => setS(() => hue = v)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _nodes[index].label = labelCtrl.text.trim();
                    _nodes[index].listItems
                      ..clear()
                      ..addAll(items);
                    _nodes[index].colorValue = _colorFromHue(hue).value;
                    _isDirty = true;
                  });
                  Navigator.of(ctx).pop();
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Opens the native Windows file dialog via PowerShell (no plugin needed)
  Future<String?> _pickImageFile() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile', '-NonInteractive', '-Command',
        r'''
Add-Type -AssemblyName System.Windows.Forms
$d = New-Object System.Windows.Forms.OpenFileDialog
$d.Title  = "Select image"
$d.Filter = "Image files|*.png;*.jpg;*.jpeg;*.gif;*.webp;*.bmp|All files|*.*"
$d.Multiselect = $false
if ($d.ShowDialog() -eq "OK") { Write-Output $d.FileName }
''',
      ]);
      final path = result.stdout.toString().trim();
      return path.isNotEmpty ? path : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _editImageNode(MindmapNode node) async {
    final index = _nodes.indexWhere((n) => n.id == node.id);
    if (index < 0) return;
    final labelCtrl = TextEditingController(text: node.label);
    String pickedPath = node.imagePath;
    double hue = _initialHueForNode(node);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSB) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Edit Image node'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Node label', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                // File picker row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          pickedPath.isNotEmpty ? pickedPath.split(RegExp(r'[\\/]')).last : 'No image selected',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: pickedPath.isNotEmpty ? Colors.black87 : Colors.grey[500], fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Browse'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                      onPressed: () async {
                        final path = await _pickImageFile();
                        if (path != null) setSB(() => pickedPath = path);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Preview
                if (pickedPath.isNotEmpty && File(pickedPath).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: Image.file(File(pickedPath), height: 140, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox()),
                  ),
                _buildColorSlider(hue, (v) => setSB(() => hue = v)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _nodes[index].label = labelCtrl.text.trim();
                  _nodes[index].imagePath = pickedPath;
                  _nodes[index].colorValue = _colorFromHue(hue).value;
                  _isDirty = true;
                });
                _loadImages();
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteNode(int nodeId) {
    setState(() {
      _nodes.removeWhere((n) => n.id == nodeId);
      _edges.removeWhere((e) => e.fromId == nodeId || e.toId == nodeId);
      _isDirty = true;
      if (_connectDragSourceId == nodeId) { _connectDragActive = false; _connectDragSourceId = null; _connectDragCurrentPos = null; }
    });
  }

  void _deleteEdge(MindmapEdge edge) {
    setState(() { _edges.remove(edge); _isDirty = true; });
  }

  void _showEdgeContextMenu(MindmapEdge edge, Offset globalPos) {
    final nodeById = {for (final n in _nodes) n.id: n};
    final fromNode = nodeById[edge.fromId];
    final toNode   = nodeById[edge.toId];
    final label = '"${fromNode?.displayLabel ?? edge.fromId}"  →  "${toNode?.displayLabel ?? edge.toId}"';

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(globalPos.dx, globalPos.dy, globalPos.dx + 1, globalPos.dy + 1),
      items: [
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            Icon(Icons.link_off, size: 18, color: Colors.red[700]),
            const SizedBox(width: 8),
            Flexible(child: Text('Delete: $label', overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.red[700]))),
          ]),
        ),
      ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ).then((v) { if (v == 'delete') _deleteEdge(edge); });
  }

  void _showNodeContextMenu(MindmapNode node, Offset globalPos) {
    final connectedEdges = _edges.where((e) => e.fromId == node.id || e.toId == node.id).toList();
    final nodeById = {for (final n in _nodes) n.id: n};

    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
      PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete node', style: TextStyle(color: Colors.red))])),
    ];

    if (connectedEdges.isNotEmpty) {
      items.add(const PopupMenuDivider());
      for (final edge in connectedEdges) {
        final otherId = edge.fromId == node.id ? edge.toId : edge.fromId;
        final other = nodeById[otherId];
        if (other == null) continue;
        items.add(PopupMenuItem(
          value: 'disconnect_${edge.fromId}_${edge.toId}',
          child: Row(children: [
            const Icon(Icons.link_off, size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text('Disconnect "${other.displayLabel}"', overflow: TextOverflow.ellipsis)),
          ]),
        ));
      }
    }

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(globalPos.dx, globalPos.dy, globalPos.dx + 1, globalPos.dy + 1),
      items: items,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ).then((value) {
      if (value == null) return;
      if (value == 'edit') _editNode(node);
      else if (value == 'delete') _deleteNode(node.id);
      else if (value.startsWith('disconnect_')) {
        final parts = value.split('_');
        _deleteEdge(MindmapEdge(fromId: int.parse(parts[1]), toId: int.parse(parts[2])));
      }
    });
  }

  // ── Pointer helpers ────────────────────────────────────────────────────────

  MindmapNode? _findHitNode(Offset localPosition) {
    for (var i = _nodes.length - 1; i >= 0; i--) {
      final node = _nodes[i];
      final rect = _nodeBodyRect(node, Offset.zero);
      if (rect.contains(localPosition)) return node;
    }
    return null;
  }

  MindmapNode? _findHyperlinkButtonHit(Offset localPosition) {
    for (var i = _nodes.length - 1; i >= 0; i--) {
      final node = _nodes[i];
      if (node.type != 'Hyperlink' || node.hyperlinkUrl.trim().isEmpty) continue;
      if (_hyperlinkButtonRect(node, Offset.zero).contains(localPosition)) return node;
    }
    return null;
  }

  // Hit-test the connector dot (accounts for extra height on List/Image nodes)
  int? _findConnectorDotHit(Offset localPos) {
    for (var i = _nodes.length - 1; i >= 0; i--) {
      final node = _nodes[i];
      final dotCenter = _nodeDotPosition(node, Offset.zero);
      if ((localPos - dotCenter).distance < 12) return node.id;
    }
    return null;
  }

  // Find the edge whose bezier curve is closest to [localPos] within threshold
  MindmapEdge? _findHitEdge(Offset localPos, {double threshold = 8.0}) {
    final nodeById = {for (final n in _nodes) n.id: n};
    MindmapEdge? best;
    double bestDist = threshold;
    for (final edge in _edges) {
      final from = nodeById[edge.fromId];
      final to   = nodeById[edge.toId];
      if (from == null || to == null) continue;
      final ep = _computeEdgePath(from, to);
      final d = ep.minDistanceTo(localPos);
      if (d < bestDist) { bestDist = d; best = edge; }
    }
    return best;
  }

  Offset _defaultNodePosition() {
    if (_canvasSize.width <= 0 || _canvasSize.height <= 0) {
      return _clampNodePosition(_toWorld(const Offset(120, 90)));
    }
    return _clampNodePosition(_toWorld(Offset(_canvasSize.width / 2, _canvasSize.height / 2)));
  }

  Offset _clampNodePosition(Offset position) {
    if (_canvasSize.width <= 0 || _canvasSize.height <= 0) return position;
    const halfW = MindmapNode.nodeWidth / 2;
    const halfH = MindmapNode.nodeHeight / 2;
    final minX = (-_canvasOffset.dx) / _canvasScale + halfW;
    final maxX = (_canvasSize.width - _canvasOffset.dx) / _canvasScale - halfW;
    final minY = (-_canvasOffset.dy) / _canvasScale + halfH;
    final maxY = (_canvasSize.height - _canvasOffset.dy) / _canvasScale - halfH;
    return Offset(
      position.dx.clamp(minX, maxX).toDouble(),
      position.dy.clamp(minY, maxY).toDouble(),
    );
  }

  void _finishConnectDrag(Offset localPos) {
    if (!_connectDragActive || _connectDragSourceId == null) return;
    final hit = _findHitNode(localPos);
    if (hit != null && hit.id != _connectDragSourceId) {
      final newEdge = MindmapEdge(fromId: _connectDragSourceId!, toId: hit.id);
      final rev = MindmapEdge(fromId: hit.id, toId: _connectDragSourceId!);
      if (!_edges.contains(newEdge) && !_edges.contains(rev)) {
        setState(() { _edges.add(newEdge); _isDirty = true; });
      }
    }
    setState(() { _connectDragActive = false; _connectDragSourceId = null; _connectDragCurrentPos = null; });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async { if (!didPop) await _maybeLeave(); },
      child: Scaffold(
        body: Row(
          children: [
            // ── Sidebar ────────────────────────────────────────────────────
            Container(
              width: 220,
              color: Colors.blueGrey[900],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: Row(children: [
                      IconButton(icon: const Icon(Icons.arrow_back), color: Colors.white, onPressed: _maybeLeave),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Mindmap', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _nodeTypes.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: Material(
                          color: Colors.blueGrey[800],
                          borderRadius: BorderRadius.circular(5),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(5),
                            hoverColor: Colors.blueGrey[700],
                            onTap: () => setState(() {
                              _nodes.add(MindmapNode(id: DateTime.now().microsecondsSinceEpoch, type: _nodeTypes[index], position: _defaultNodePosition()));
                              _isDirty = true;
                            }),
                            child: ListTile(
                              leading: const Icon(Icons.circle, size: 12, color: Colors.white70),
                              title: Text(_nodeTypes[index], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.blueGrey[700], borderRadius: BorderRadius.circular(5)),
                            child: const Text(
                              'Drag the  ●  dot on a node\nto connect it to another.\nUse mouse wheel to zoom.\nRight-click for options.',
                              style: TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── Canvas ─────────────────────────────────────────────────────
            Expanded(
              child: Container(
                color: Colors.blueGrey[50],
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.blueGrey[100], borderRadius: BorderRadius.circular(5)),
                        child: Row(
                          children: [
                            Expanded(child: Text('Mindmap Canvas', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey[900]))),
                            _isSaving
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                : IconButton(icon: const Icon(Icons.save), color: Colors.blueGrey[800], tooltip: 'Save mindmap', onPressed: _saveToFile),
                          ],
                        ),
                      ),
                      const SizedBox(height: 17),
                      Expanded(
                        child: Container(
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.blueGrey.shade200)),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                              return Listener(
                                onPointerSignal: (event) {
                                  if (event is PointerScrollEvent) {
                                    if (event.scrollDelta.dy < 0) {
                                      _applyZoomAt(event.localPosition, 1.1);
                                    } else if (event.scrollDelta.dy > 0) {
                                      _applyZoomAt(event.localPosition, 0.9);
                                    }
                                  }
                                },
                                onPointerDown: (event) {
                                  final worldPos = _toWorld(event.localPosition);
                                  final isPrimaryLike =
                                      (event.buttons & kPrimaryMouseButton) != 0 ||
                                      event.buttons == 0;

                                  // Right-click → context menu (node or edge)
                                  if (event.kind == PointerDeviceKind.mouse && (event.buttons & kSecondaryMouseButton) != 0) {
                                    final box = context.findRenderObject() as RenderBox?;
                                    final gPos = box != null ? box.localToGlobal(event.localPosition) : event.position;
                                    final hit = _findHitNode(worldPos);
                                    if (hit != null) {
                                      _showNodeContextMenu(hit, gPos);
                                    } else {
                                      final hitEdge = _findHitEdge(worldPos);
                                      if (hitEdge != null) _showEdgeContextMenu(hitEdge, gPos);
                                    }
                                    return;
                                  }

                                  if (event.kind == PointerDeviceKind.mouse && isPrimaryLike) {
                                    final linkNode = _findHyperlinkButtonHit(worldPos);
                                    if (linkNode != null) {
                                      setState(() {
                                        _pressedHyperlinkNodeId = linkNode.id;
                                        _hoverHyperlinkNodeId = linkNode.id;
                                      });
                                      return;
                                    }

                                    // Check connector dot first
                                    final dotSourceId = _findConnectorDotHit(worldPos);
                                    if (dotSourceId != null) {
                                      setState(() {
                                        _connectDragActive = true;
                                        _connectDragSourceId = dotSourceId;
                                        _connectDragCurrentPos = worldPos;
                                      });
                                      return;
                                    }

                                    final hit = _findHitNode(worldPos);
                                    if (hit != null) {
                                      setState(() => _draggingNodeId = hit.id);
                                    }
                                  }

                                  if (event.kind == PointerDeviceKind.mouse && (event.buttons & kMiddleMouseButton) != 0) {
                                    setState(() => _isMiddleDragging = true);
                                  }
                                },
                                onPointerHover: (event) {
                                  if (event.kind != PointerDeviceKind.mouse) return;
                                  final hoverNode = _findHyperlinkButtonHit(_toWorld(event.localPosition));
                                  final hoverId = hoverNode?.id;
                                  if (hoverId != _hoverHyperlinkNodeId) {
                                    setState(() => _hoverHyperlinkNodeId = hoverId);
                                  }
                                },
                                onPointerMove: (event) {
                                  final worldPos = _toWorld(event.localPosition);
                                  if (event.kind == PointerDeviceKind.mouse) {
                                    final hoverNode = _findHyperlinkButtonHit(worldPos);
                                    final hoverId = hoverNode?.id;
                                    if (hoverId != _hoverHyperlinkNodeId) {
                                      setState(() => _hoverHyperlinkNodeId = hoverId);
                                    }
                                  }

                                  if (_pressedHyperlinkNodeId != null) {
                                    return;
                                  }

                                  if (_connectDragActive) {
                                    setState(() => _connectDragCurrentPos = worldPos);
                                    return;
                                  }
                                  if (_isMiddleDragging && (event.buttons & kMiddleMouseButton) != 0) {
                                    setState(() => _canvasOffset += event.delta);
                                    return;
                                  }
                                  if (_draggingNodeId != null && (event.buttons & kPrimaryMouseButton) != 0) {
                                    setState(() {
                                      final index = _nodes.indexWhere((n) => n.id == _draggingNodeId);
                                      if (index >= 0) {
                                        _nodes[index].position = _clampNodePosition(
                                          _nodes[index].position + (event.delta / _canvasScale),
                                        );
                                        _isDirty = true;
                                      }
                                    });
                                  }
                                },
                                onPointerUp: (event) {
                                  final worldPos = _toWorld(event.localPosition);
                                  if (_pressedHyperlinkNodeId != null) {
                                    final hit = _findHyperlinkButtonHit(worldPos);
                                    final shouldOpen = hit != null && hit.id == _pressedHyperlinkNodeId;
                                    setState(() => _pressedHyperlinkNodeId = null);
                                    if (shouldOpen) {
                                      _openHyperlink(hit.hyperlinkUrl);
                                    }
                                    return;
                                  }

                                  if (_connectDragActive) {
                                    _finishConnectDrag(worldPos);
                                    return;
                                  }
                                  setState(() { _draggingNodeId = null; _isMiddleDragging = false; });
                                },
                                onPointerCancel: (_) {
                                  setState(() {
                                    _connectDragActive = false; _connectDragSourceId = null; _connectDragCurrentPos = null;
                                    _draggingNodeId = null; _isMiddleDragging = false;
                                    _pressedHyperlinkNodeId = null;
                                    _hoverHyperlinkNodeId = null;
                                  });
                                },
                                child: CustomPaint(
                                  painter: CanvasPainter(
                                    canvasOffset: _canvasOffset,
                                    canvasScale: _canvasScale,
                                    nodes: _nodes,
                                    edges: _edges,
                                    connectDragSourceId: _connectDragSourceId,
                                    connectDragPos: _connectDragCurrentPos,
                                    imageCache: _imageCache,
                                    hoverHyperlinkNodeId: _hoverHyperlinkNodeId,
                                    pressedHyperlinkNodeId: _pressedHyperlinkNodeId,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              );
                            },
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Canvas painter
// ─────────────────────────────────────────────────────────────────────────────

class CanvasPainter extends CustomPainter {
  const CanvasPainter({
    required this.canvasOffset,
    required this.canvasScale,
    required this.nodes,
    required this.edges,
    this.connectDragSourceId,
    this.connectDragPos,
    required this.imageCache,
    this.hoverHyperlinkNodeId,
    this.pressedHyperlinkNodeId,
  });

  final Offset canvasOffset;
  final double canvasScale;
  final List<MindmapNode> nodes;
  final List<MindmapEdge> edges;
  final int? connectDragSourceId;
  final Offset? connectDragPos;
  final Map<String, ui.Image> imageCache;
  final int? hoverHyperlinkNodeId;
  final int? pressedHyperlinkNodeId;

  static const Map<String, Color> _typeColors = {
    'Label': Color(0xFF5C8DDE),
    'TextArea': Color(0xFF4EAD8A),
    'Image': Color(0xFFE08A45),
    'List': Color(0xFF9B6DB5),
    'Hyperlink': Color(0xFF4EA8C8),
  };
  static const Color _defaultColor = Color(0xFF607D8B);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    _drawGrid(canvas, size);

    canvas.save();
    canvas.translate(canvasOffset.dx, canvasOffset.dy);
    canvas.scale(canvasScale);

    final nodeById = {for (final n in nodes) n.id: n};

    // Committed edges
    for (final edge in edges) {
      final from = nodeById[edge.fromId];
      final to   = nodeById[edge.toId];
      if (from == null || to == null) continue;
      _drawEdge(canvas, from, to);
    }

    // In-progress drag edge — from the dot to the cursor
    if (connectDragSourceId != null && connectDragPos != null) {
      final src = nodeById[connectDragSourceId!];
      if (src != null) {
        final dotPos = _nodeDotPosition(src, Offset.zero);
        final toPos  = connectDragPos!;
        final dx = toPos.dx - dotPos.dx;
        final dy = toPos.dy - dotPos.dy;
        final cp1 = Offset(dotPos.dx + dx * 0.5, dotPos.dy);
        final cp2 = Offset(toPos.dx - dx * 0.5, toPos.dy - dy * 0.1);
        final path = Path()
          ..moveTo(dotPos.dx, dotPos.dy)
          ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, toPos.dx, toPos.dy);
        _drawDashedPath(canvas, path, Paint()
          ..color = const Color(0xFF90A4AE)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
      }
    }

    // Nodes
    for (final node in nodes) {
      _drawNode(canvas, node, size);
    }

    canvas.restore();
    canvas.restore();
  }

  void _drawGrid(Canvas canvas, Size size) {
    final double step = 40 * canvasScale;
    final paint = Paint()..color = const Color(0xFFDDE4EA)..strokeWidth = 1;
    final sx = canvasOffset.dx % step;
    final sy = canvasOffset.dy % step;
    for (double x = sx - step; x <= size.width + step; x += step) {
      if (x >= 0 && x <= size.width) canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = sy - step; y <= size.height + step; y += step) {
      if (y >= 0 && y <= size.height) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawEdge(Canvas canvas, MindmapNode fromNode, MindmapNode toNode) {
    final ep = _computeEdgePath(fromNode, toNode);
    canvas.drawPath(ep.toPath(), Paint()
      ..color = const Color(0xFF90A4AE)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);

    final mid = _pointOnCubic(ep, 0.5);
    final tangent = _tangentOnCubic(ep, 0.5);
    if (tangent.distanceSquared > 0.0001) {
      final dir = tangent / tangent.distance;
      _drawArrowhead(canvas, mid - dir * 10, mid);
    }
  }

  Offset _pointOnCubic(_EdgePath ep, double t) {
    final mt = 1 - t;
    return Offset(
      mt * mt * mt * ep.fromPt.dx +
          3 * mt * mt * t * ep.cp1.dx +
          3 * mt * t * t * ep.cp2.dx +
          t * t * t * ep.toPt.dx,
      mt * mt * mt * ep.fromPt.dy +
          3 * mt * mt * t * ep.cp1.dy +
          3 * mt * t * t * ep.cp2.dy +
          t * t * t * ep.toPt.dy,
    );
  }

  Offset _tangentOnCubic(_EdgePath ep, double t) {
    final mt = 1 - t;
    return Offset(
      3 * mt * mt * (ep.cp1.dx - ep.fromPt.dx) +
          6 * mt * t * (ep.cp2.dx - ep.cp1.dx) +
          3 * t * t * (ep.toPt.dx - ep.cp2.dx),
      3 * mt * mt * (ep.cp1.dy - ep.fromPt.dy) +
          6 * mt * t * (ep.cp2.dy - ep.cp1.dy) +
          3 * t * t * (ep.toPt.dy - ep.cp2.dy),
    );
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashLen = 6.0;
    const gapLen = 4.0;
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double dist = 0;
      bool draw = true;
      while (dist < metric.length) {
        final len = draw ? dashLen : gapLen;
        if (draw) {
          canvas.drawPath(metric.extractPath(dist, math.min(dist + len, metric.length)), paint);
        }
        dist += len;
        draw = !draw;
      }
    }
  }

  void _drawArrowhead(Canvas canvas, Offset from, Offset to) {
    const sz = 10.0;
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(to.dx - sz * math.cos(angle - 0.7), to.dy - sz * math.sin(angle - 0.7))
      ..moveTo(to.dx, to.dy)
      ..lineTo(to.dx - sz * math.cos(angle + 0.7), to.dy - sz * math.sin(angle + 0.7));
    canvas.drawPath(path, Paint()..color = const Color(0xFF90A4AE)..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }

  void _drawNode(Canvas canvas, MindmapNode node, Size canvasSize) {
    // Dynamic dimensions
    final headerH = _nodeHeaderHeight(node);
    final extraH = _extraNodeHeight(node);

    final nodeRect = _nodeBodyRect(node, Offset.zero);

    final isConnSrc = node.id == connectDragSourceId;
    final nodeColor = node.colorValue != null
      ? Color(node.colorValue!)
      : (_typeColors[node.type] ?? _defaultColor);

    // Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(nodeRect.translate(0, 3), const Radius.circular(8)),
      Paint()..color = const Color(0x1F000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(nodeRect, const Radius.circular(8)),
      Paint()..color = isConnSrc ? const Color(0xFFF59E0B) : nodeColor,
    );

    // Header label at top
    final headerRect = Rect.fromLTWH(nodeRect.left, nodeRect.top, nodeRect.width, headerH);
    final tp = TextPainter(
      text: TextSpan(text: node.displayLabel, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: MindmapNode.nodeWidth - 16);
    tp.paint(canvas, Offset(headerRect.left + (headerRect.width - tp.width) / 2, headerRect.top + (headerRect.height - tp.height) / 2));

    // List items
    if (node.type == 'List' && node.listItems.isNotEmpty) {
      final dividerPaint = Paint()..color = Colors.white24..strokeWidth = 1;
      canvas.drawLine(Offset(nodeRect.left + 8, nodeRect.top + headerH), Offset(nodeRect.right - 8, nodeRect.top + headerH), dividerPaint);

      double y = nodeRect.top + headerH + 6;
      for (final item in node.listItems) {
        // bullet
        canvas.drawCircle(Offset(nodeRect.left + 14, y + 7), 3, Paint()..color = Colors.white70);
        final itp = TextPainter(
          text: TextSpan(text: item, style: const TextStyle(color: Colors.white, fontSize: 12)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: nodeRect.width - 30);
        itp.paint(canvas, Offset(nodeRect.left + 22, y));
        y += 20;
      }
    }

    // TextArea content
    if (node.type == 'TextArea') {
      final bodyRect = Rect.fromLTWH(
        nodeRect.left + 8,
        nodeRect.top + headerH + 6,
        nodeRect.width - 16,
        extraH - 12,
      );
      final content = node.textAreaContent.trim();
      if (content.isNotEmpty) {
        final tpBody = TextPainter(
          text: TextSpan(
            text: content,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: bodyRect.width);
        tpBody.paint(canvas, bodyRect.topLeft);
      }
    }

    // Image preview inside node
    if (node.type == 'Image' && node.imagePath.isNotEmpty) {
      final imgRect = Rect.fromLTWH(nodeRect.left + 4, nodeRect.top + headerH + 4, nodeRect.width - 8, extraH - 8);
      _paintImage(canvas, node.imagePath, imgRect);
    }

    // Hyperlink button inside node
    if (node.type == 'Hyperlink') {
      final btnRect = _hyperlinkButtonRect(node, Offset.zero);
      final hasUrl = node.hyperlinkUrl.trim().isNotEmpty;
      final isHover = node.id == hoverHyperlinkNodeId;
      final isPressed = node.id == pressedHyperlinkNodeId;
      final label = node.hyperlinkLabel.trim().isNotEmpty
          ? node.hyperlinkLabel.trim()
          : (hasUrl ? 'Open link' : 'Set URL');

      canvas.drawRRect(
        RRect.fromRectAndRadius(btnRect, const Radius.circular(5)),
        Paint()
          ..color = isPressed
              ? const Color(0xFFE8EEF3)
              : (isHover
                  ? const Color(0xFFF4F8FB)
                  : (hasUrl ? Colors.white : const Color(0x66FFFFFF))),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(btnRect, const Radius.circular(5)),
        Paint()
          ..color = isHover ? const Color(0x66000000) : const Color(0x33000000)
          ..style = PaintingStyle.stroke,
      );

      final bt = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: hasUrl ? nodeColor.withOpacity(0.95) : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: btnRect.width - 20);
      bt.paint(canvas, Offset(btnRect.left + (btnRect.width - bt.width) / 2, btnRect.top + (btnRect.height - bt.height) / 2));
    }

    // Connector dot (right edge, aligned with header vertical center)
    final dotCenter = _nodeDotPosition(node, Offset.zero);
    canvas.drawCircle(dotCenter, 6, Paint()..color = Colors.white..style = PaintingStyle.fill);
    canvas.drawCircle(dotCenter, 6, Paint()..color = nodeColor..strokeWidth = 2..style = PaintingStyle.stroke);
    canvas.drawCircle(dotCenter, 3, Paint()..color = nodeColor..style = PaintingStyle.fill);
  }

  double _extraNodeHeight(MindmapNode node) => _nodeExtraHeight(node);

  void _paintImage(Canvas canvas, String path, Rect rect) {
    final img = imageCache[path];
    if (img != null) {
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)));
      // Keep full image visible inside the node bounds instead of cropping.
      paintImage(
        canvas: canvas,
        rect: rect,
        image: img,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.low,
      );
      canvas.restore();
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()..color = const Color(0x33000000),
      );
      final tp = TextPainter(
        text: const TextSpan(text: '🖼', style: TextStyle(fontSize: 22)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) => true;
}
