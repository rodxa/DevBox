import 'package:flutter/material.dart';

class Database extends StatefulWidget {
  const Database({Key? key, required this.databaseFile}) : super(key: key);
  final String databaseFile;

  @override
  State<Database> createState() => _DatabaseState();
}

class _DatabaseState extends State<Database> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database'),
      ),
      body: const Center(
        child: Text('Database Page'),
      ),
    );
  }
}
