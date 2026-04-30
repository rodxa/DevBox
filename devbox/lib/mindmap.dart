import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class Mindmap extends StatefulWidget {
  const Mindmap({Key? key, required this.mindmapFile}) : super(key: key);

  final File mindmapFile;

  @override
  State<Mindmap> createState() => _MindmapState();
}

class _MindmapState extends State<Mindmap> {
  final List<String> items = [
    'Label',
    'TextArea',
    'Image',
    'List',
    'Hyperlink',
  ];
  final List<MindmapNode> _nodes = [];
  Offset _canvasOffset = Offset.zero;
  Size _canvasSize = Size.zero;
  bool _isMiddleDragging = false;
  int? _draggingNodeId;
  bool _isSaving = false;
  bool _isDirty = false;

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
      setState(() {
        _nodes.clear();
        for (final n in nodeList) {
          _nodes.add(
            MindmapNode(
              id: n['id'] as int,
              type: n['type'] as String,
              position: Offset(
                (n['position']['x'] as num).toDouble(),
                (n['position']['y'] as num).toDouble(),
              ),
            ),
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _saveToFile() async {
    setState(() => _isSaving = true);
    try {
      final data = {
        'nodes': _nodes.map((n) => {
          'id': n.id,
          'type': n.type,
          'position': {'x': n.position.dx, 'y': n.position.dy},
        }).toList(),
      };
      await widget.mindmapFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
      );
      if (mounted) setState(() => _isDirty = false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _maybeLeave() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        title: const Text('Unsaved changes'),
        content: const Text(
          'You have unsaved changes. Do you want to save before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (result == 'save') {
      await _saveToFile();
      if (mounted) Navigator.of(context).pop();
    } else if (result == 'discard') {
      Navigator.of(context).pop();
    }
    // 'cancel' or null: do nothing
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _maybeLeave();
      },
      child: Scaffold(
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
                        onPressed: _maybeLeave,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Mindmap',
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
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: Material(
                          color: Colors.blueGrey[800],
                          borderRadius: BorderRadius.circular(5),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(5),
                            hoverColor: Colors.blueGrey[700],
                            onTap: () {
                              setState(() {
                                _nodes.add(
                                  MindmapNode(
                                    id: DateTime.now().microsecondsSinceEpoch,
                                    type: items[index],
                                    position: _defaultNodePosition(),
                                  ),
                                );
                                _isDirty = true;
                              });
                            },
                            child: ListTile(
                              leading: const Icon(
                                Icons.circle,
                                size: 12,
                                color: Colors.white70,
                              ),
                              title: Text(
                                items[index],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
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
                              'Mindmap Canvas',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[900],
                              ),
                            ),
                          ),
                          _isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.save),
                                  color: Colors.blueGrey[800],
                                  tooltip: 'Save mindmap',
                                  onPressed: _saveToFile,
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 17),
                    Expanded(
                      child: Container(
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.blueGrey.shade200),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            _canvasSize = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );

                            return Listener(
                              onPointerDown: (event) {
                                if (event.kind == PointerDeviceKind.mouse &&
                                    (event.buttons & kPrimaryMouseButton) !=
                                        0) {
                                  final hitNode = _findHitNode(
                                    event.localPosition,
                                  );
                                  if (hitNode != null) {
                                    setState(() {
                                      _draggingNodeId = hitNode.id;
                                    });
                                    return;
                                  }
                                }

                                if (event.kind == PointerDeviceKind.mouse &&
                                    (event.buttons & kMiddleMouseButton) != 0) {
                                  setState(() {
                                    _isMiddleDragging = true;
                                  });
                                }
                              },
                              onPointerMove: (event) {
                                if (_isMiddleDragging &&
                                    event.kind == PointerDeviceKind.mouse &&
                                    (event.buttons & kMiddleMouseButton) != 0) {
                                  setState(() {
                                    _canvasOffset += event.delta;
                                  });
                                  return;
                                }

                                if (_draggingNodeId != null &&
                                    event.kind == PointerDeviceKind.mouse &&
                                    (event.buttons & kPrimaryMouseButton) !=
                                        0) {
                                  setState(() {
                                    final index = _nodes.indexWhere(
                                      (node) => node.id == _draggingNodeId,
                                    );
                                    if (index >= 0) {
                                      final node = _nodes[index];
                                      _nodes[index] = node.copyWith(
                                        position: _clampNodePosition(
                                          node.position + event.delta,
                                        ),
                                      );
                                      _isDirty = true;
                                    }
                                  });
                                }
                              },
                              onPointerUp: (_) {
                                if (_draggingNodeId != null) {
                                  setState(() {
                                    _draggingNodeId = null;
                                  });
                                }
                                if (_isMiddleDragging) {
                                  setState(() {
                                    _isMiddleDragging = false;
                                  });
                                }
                              },
                              onPointerCancel: (_) {
                                if (_draggingNodeId != null) {
                                  setState(() {
                                    _draggingNodeId = null;
                                  });
                                }
                                if (_isMiddleDragging) {
                                  setState(() {
                                    _isMiddleDragging = false;
                                  });
                                }
                              },
                              child: CustomPaint(
                                painter: CanvasPainter(
                                  canvasOffset: _canvasOffset,
                                  nodes: _nodes,
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
      )
    );
  }

  MindmapNode? _findHitNode(Offset localPosition) {
    for (var i = _nodes.length - 1; i >= 0; i--) {
      final node = _nodes[i];
      final rect = Rect.fromCenter(
        center: node.position + _canvasOffset,
        width: MindmapNode.nodeWidth,
        height: MindmapNode.nodeHeight,
      );
      if (rect.contains(localPosition)) {
        return node;
      }
    }
    return null;
  }

  Offset _defaultNodePosition() {
    if (_canvasSize.width <= 0 || _canvasSize.height <= 0) {
      return _clampNodePosition(-_canvasOffset + const Offset(120, 90));
    }

    final visibleCenter = Offset(_canvasSize.width / 2, _canvasSize.height / 2);
    return _clampNodePosition(visibleCenter - _canvasOffset);
  }

  Offset _clampNodePosition(Offset position) {
    if (_canvasSize.width <= 0 || _canvasSize.height <= 0) {
      return position;
    }

    final halfW = MindmapNode.nodeWidth / 2;
    final halfH = MindmapNode.nodeHeight / 2;

    final minX = halfW - _canvasOffset.dx;
    final maxX = _canvasSize.width - halfW - _canvasOffset.dx;
    final minY = halfH - _canvasOffset.dy;
    final maxY = _canvasSize.height - halfH - _canvasOffset.dy;

    return Offset(
      position.dx.clamp(minX, maxX).toDouble(),
      position.dy.clamp(minY, maxY).toDouble(),
    );
  }
}

class CanvasPainter extends CustomPainter {
  const CanvasPainter({required this.canvasOffset, required this.nodes});

  final Offset canvasOffset;
  final List<MindmapNode> nodes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    const double gridStep = 50;
    final paint = Paint()
      ..strokeWidth = 2
      ..color = Colors.blueGrey[300]!;

    final gridPaint = Paint()..color = const Color.fromARGB(255, 158, 128, 128);

    final shiftedX = canvasOffset.dx % gridStep;
    final shiftedY = canvasOffset.dy % gridStep;

    for (
      double x = shiftedX - gridStep;
      x <= size.width + gridStep;
      x += gridStep
    ) {
      if (x > 0 && x < size.width) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
    }

    for (
      double y = shiftedY - gridStep;
      y <= size.height + gridStep;
      y += gridStep
    ) {
      if (y > 0 && y < size.height) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    for (final node in nodes) {
      final nodeRect = Rect.fromCenter(
        center: node.position + canvasOffset,
        width: MindmapNode.nodeWidth,
        height: MindmapNode.nodeHeight,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(nodeRect, const Radius.circular(10)),
        paint,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: node.type,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: MindmapNode.nodeWidth - 16);

      textPainter.paint(
        canvas,
        Offset(
          nodeRect.left + (nodeRect.width - textPainter.width) / 2,
          nodeRect.top + (nodeRect.height - textPainter.height) / 2,
        ),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) => true;
}

class MindmapNode {
  const MindmapNode({
    required this.id,
    required this.type,
    required this.position,
  });

  static const double nodeWidth = 180;
  static const double nodeHeight = 70;

  final int id;
  final String type;
  final Offset position;

  MindmapNode copyWith({int? id, String? type, Offset? position}) {
    return MindmapNode(
      id: id ?? this.id,
      type: type ?? this.type,
      position: position ?? this.position,
    );
  }
}
