import 'package:devbox/tools/tool_scaffold.dart';
import 'package:flutter/material.dart';

class DataTransformerPage extends StatelessWidget {
  const DataTransformerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ToolScaffold(
      title: 'Data Transformer',
      icon: Icons.transform,
      description: 'Transform and reshape your data here.',
    );
  }
}
