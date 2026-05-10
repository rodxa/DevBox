import 'package:devbox/tools/tool_scaffold.dart';
import 'package:flutter/material.dart';

class DatabaseBuilderPage extends StatelessWidget {
  const DatabaseBuilderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ToolScaffold(
      title: 'Database Builder',
      icon: Icons.storage,
      description: 'Create and manage database structures here.',
    );
  }
}
