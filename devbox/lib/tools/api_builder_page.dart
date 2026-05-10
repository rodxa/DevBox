import 'package:devbox/tools/tool_scaffold.dart';
import 'package:flutter/material.dart';

class ApiBuilderPage extends StatelessWidget {
  const ApiBuilderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ToolScaffold(
      title: 'API Builder',
      icon: Icons.construction_rounded,
      description: 'Design and generate API workflows here.',
    );
  }
}
