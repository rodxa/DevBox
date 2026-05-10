import 'package:devbox/tools/tool_scaffold.dart';
import 'package:flutter/material.dart';

class PasswordManagerPage extends StatelessWidget {
  const PasswordManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ToolScaffold(
      title: 'Password Manager',
      icon: Icons.lock,
      description: 'Store and organize passwords securely here.',
    );
  }
}
