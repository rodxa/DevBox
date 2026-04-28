import 'dart:io';

import 'package:devbox/globals.dart';
import 'package:flutter/material.dart';

class Project extends StatefulWidget {
  const Project({Key? key, required this.projectFolder}) : super(key: key);
  final Directory projectFolder;

  @override
  State<Project> createState() => _ProjectState();
}

class _ProjectState extends State<Project> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 200,
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
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
                // Navigation items
                Expanded(
                  child: Column(
                    children: [
                      DevBoxProjectButton(
                        onTap: () {
                          Globals().projectTab.value = 0;
                        },
                        text: "Dashboard",
                        icon: Icons.dashboard,
                      ),
                      DevBoxProjectButton(
                        onTap: () {
                          Globals().projectTab.value = 1;
                        },
                        text: "Files",
                        icon: Icons.folder,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: Globals().projectTab,
              builder: (context, value, child) {
                return switch(value) {
                  0 => Dashboard(widget.projectFolder.path.split(Platform.pathSeparator).last),
                  _ => Dashboard(widget.projectFolder.path.split(Platform.pathSeparator).last),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DevBoxProjectButton extends StatelessWidget {
  const DevBoxProjectButton({
    super.key,
    required this.onTap,
    required this.text,
    required this.icon,
  });

  final VoidCallback onTap;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 8.0,
        vertical: 4.0,
      ),
      child: Material(
        color: Colors.blueGrey[800],
        elevation: 2,
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          hoverColor: Colors.blueGrey[700],
          splashColor: const Color.fromARGB(255, 148, 160, 180).withOpacity(0.3),
          onTap: () {
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white70),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget Dashboard(String projectName) {
  return Container(
    color: Colors.blueGrey[50],
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            projectName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[900],
            ),
          ),
        ],
      ),
    ),
  );
}
