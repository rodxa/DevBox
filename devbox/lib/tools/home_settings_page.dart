import 'package:devbox/tools/tool_scaffold.dart';
import 'package:flutter/material.dart';

class HomeSettingsPage extends StatelessWidget {
  const HomeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ToolScaffold(
      title: 'Settings',
      icon: Icons.settings,
      description: 'Configure DevBox home settings here.',
    );
  }
}
