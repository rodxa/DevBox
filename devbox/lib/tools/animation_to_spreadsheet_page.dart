import 'package:devbox/tools/tool_scaffold.dart';
import 'package:flutter/material.dart';

class AnimationToSpreadsheetPage extends StatelessWidget {
  const AnimationToSpreadsheetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ToolScaffold(
      title: 'Animation to Spreadsheet',
      icon: Icons.image_aspect_ratio,
      description: 'Convert animation data into spreadsheet output here.',
    );
  }
}
