import 'package:devbox/globals.dart';
import 'package:devbox/project.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Directory contentFolder = Directory(
    'C:/Users/Utilizador/Desktop/devbox_content',
  );
  List<Directory> projectFolders = [];

  TextEditingController projectNameController = TextEditingController();
  bool projectAlreadyExists = false;

  void loadProjects() {
    if (contentFolder.existsSync()) {
      setState(() {
        projectFolders = contentFolder
            .listSync()
            .whereType<Directory>()
            .toList();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadProjects();
  }

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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Projects',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add),
                        color: Colors.white,
                        onPressed: () {
                          projectAlreadyExists = false;
                          showDialog(
                            context: context,
                            builder: (dialogContext) {
                              projectNameController.clear();
                              Future<void> tryCreate() async {
                                if (projectNameController.text.trim().isEmpty)
                                  return;
                                if (projectFolders.any(
                                  (folder) =>
                                      folder.path.split('\\').last ==
                                      projectNameController.text.trim(),
                                )) {
                                  (dialogContext as Element).markNeedsBuild();
                                  setState(() {
                                    projectAlreadyExists = true;
                                  });
                                  return;
                                }
                                setState(() {
                                  Directory newProjectDir = Directory(
                                    '${contentFolder.path}/${projectNameController.text}',
                                  );
                                  newProjectDir.createSync();
                                  projectFolders.add(newProjectDir);
                                });
                                loadProjects();
                                Navigator.of(dialogContext).pop();
                              }

                              return AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                title: Text('Create New Project'),
                                content: TextField(
                                  controller: projectNameController,
                                  decoration: InputDecoration(
                                    hintText: 'Project Name',
                                    errorText: projectAlreadyExists
                                        ? 'A project with this name already exists.'
                                        : null,
                                  ),
                                  onSubmitted: (_) async {
                                    await tryCreate();
                                  },
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop();
                                    },
                                    child: Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      await tryCreate();
                                    },
                                    child: Text('Create'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: projectFolders.length,
                    itemBuilder: (context, index) {
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
                            splashColor: const Color.fromARGB(
                              255,
                              148,
                              160,
                              180,
                            ).withOpacity(0.3),
                            onTap: () {
                              Globals().projectTab.value = 0;
                              Navigator.of(context)
                                  .push<bool>(
                                    MaterialPageRoute(
                                      builder: (context) => Project(
                                        projectFolder: projectFolders[index],
                                        projectName: projectFolders[index].path
                                            .split('\\')
                                            .last,
                                      ),
                                    ),
                                  )
                                  .then((wasChanged) {
                                    if (wasChanged == true && mounted) {
                                      loadProjects();
                                    }
                                  });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.folder, color: Colors.white70),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      projectFolders[index].path
                                          .split('\\')
                                          .last,
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
                    },
                  ),
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: Container(
              color: Colors.blueGrey[50],
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top icon row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 20,
                      children: [
                        IconButton(
                          icon: Icon(Icons.sync, size: 30),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: Icon(Icons.storage, size: 30),
                          onPressed: () {},
                        ),

                        // Placeholder icons
                        IconButton(
                          icon: Icon(Icons.insert_drive_file, size: 30),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: Icon(Icons.insert_chart, size: 30),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: Icon(Icons.settings, size: 30),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    SizedBox(height: 22),
                    // Search bar
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'search project or tool',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,

                        contentPadding: EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: BorderSide(color: Colors.blueGrey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
