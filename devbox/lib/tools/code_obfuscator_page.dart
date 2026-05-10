import 'package:devbox/tools/tool_scaffold.dart';
import 'package:flutter/material.dart';

class CodeObfuscatorPage extends StatelessWidget {
  const CodeObfuscatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ToolScaffold(
      title: 'Code Obfuscator',
      icon: Icons.password,
      description: 'Obfuscate code and manage protection options here.',
    );
  }
}
