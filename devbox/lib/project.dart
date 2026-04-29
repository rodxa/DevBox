import 'dart:io';

import 'package:devbox/globals.dart';
import 'package:flutter/material.dart';

class Project extends StatefulWidget {
  const Project({
    Key? key,
    required this.projectFolder,
    required this.projectName,
  }) : super(key: key);
  final Directory projectFolder;
  final String projectName;

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
                        icon: Icon(Icons.arrow_back),
                        color: Colors.white,
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.projectName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
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
                          setState(() {
                            Globals().projectTab.value = 0;
                          });
                        },
                        text: "Dashboard",
                        icon: Icons.dashboard,
                        id: 0,
                      ),
                      DevBoxProjectButton(
                        onTap: () {
                          setState(() {
                            Globals().projectTab.value = 1;
                          });
                        },
                        text: "Files",
                        icon: Icons.folder,
                        id: 1,
                      ),
                      DevBoxProjectButton(
                        onTap: () {
                          setState(() {
                            Globals().projectTab.value = 2;
                          });
                        },
                        text: "Colaborators",
                        icon: Icons.people,
                        id: 2,
                      ),
                      DevBoxProjectButton(
                        onTap: () {
                          setState(() {
                            Globals().projectTab.value = 3;
                          });
                        },
                        text: "Settings",
                        icon: Icons.settings,
                        id: 3,
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
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                  child: () {
                    if (value == 0) {
                      return KeyedSubtree(
                        key: const ValueKey('project-dashboard'),
                        child: Dashboard(widget.projectName),
                      );
                    }
                    if (value == 1) {
                      return KeyedSubtree(
                        key: const ValueKey('project-files'),
                        child: Files(
                          projectName: widget.projectName,
                          projectFolder: widget.projectFolder,
                        ),
                      );
                    }
                    if (value == 2) {
                      return KeyedSubtree(
                        key: const ValueKey('project-collaborators'),
                        child: Collaborators(projectName: widget.projectName),
                      );
                    }
                    if (value == 3) {
                      return KeyedSubtree(
                        key: const ValueKey('project-settings'),
                        child: ProjectSettings(
                          projectName: widget.projectName,
                          projectFolder: widget.projectFolder,
                        ),
                      );
                    }
                    return KeyedSubtree(
                      key: ValueKey('project-tab-$value'),
                      child: Dashboard(widget.projectName),
                    );
                  }(),
                );
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
    required this.id,
  });

  final VoidCallback onTap;
  final String text;
  final IconData icon;
  final int id;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Material(
        color: Globals().projectTab.value == id
            ? Colors.blueGrey[600]
            : Colors.blueGrey[800],
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
            onTap();
          },

          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[100],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    projectName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[900],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 19),
          Row(
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.blueGrey[200],
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Center(child: Text("Project Image")),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class Files extends StatefulWidget {
  const Files({
    super.key,
    required this.projectName,
    required this.projectFolder,
  });

  final String projectName;
  final Directory projectFolder;

  @override
  State<Files> createState() => _FilesState();
}

class _FilesState extends State<Files> {
  late Directory _currentDirectory;
  final TextEditingController _folderNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentDirectory = widget.projectFolder;
  }

  @override
  void dispose() {
    _folderNameController.dispose();
    super.dispose();
  }

  List<Directory> _directoriesInCurrentPath() {
    if (!_currentDirectory.existsSync()) {
      return const [];
    }

    final entries = _currentDirectory.listSync().whereType<Directory>().toList()
      ..sort((first, second) => first.path.compareTo(second.path));
    return entries;
  }

  List<Directory> _pathDirectories() {
    final relativePath = _currentDirectory.path.substring(
      widget.projectFolder.path.length,
    );
    final parts = relativePath
        .split(Platform.pathSeparator)
        .where((part) => part.isNotEmpty)
        .toList();

    final directories = <Directory>[widget.projectFolder];
    var path = widget.projectFolder.path;
    for (final part in parts) {
      path = '$path${Platform.pathSeparator}$part';
      directories.add(Directory(path));
    }
    return directories;
  }

  Future<void> _createFolder() async {
    var folderAlreadyExists = false;

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        _folderNameController.clear();

        Future<void> tryCreate() async {
          final folderName = _folderNameController.text.trim();
          if (folderName.isEmpty) {
            return;
          }

          final newDirectory = Directory(
            '${_currentDirectory.path}${Platform.pathSeparator}$folderName',
          );

          if (newDirectory.existsSync()) {
            folderAlreadyExists = true;
            (dialogContext as Element).markNeedsBuild();
            return;
          }

          await newDirectory.create();
          if (!mounted) {
            return;
          }

          Navigator.of(dialogContext).pop(true);
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('New folder'),
          content: TextField(
            controller: _folderNameController,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Folder name',
              errorText: folderAlreadyExists
                  ? 'A folder with this name already exists.'
                  : null,
            ),
            onChanged: (_) {
              if (folderAlreadyExists) {
                folderAlreadyExists = false;
                (dialogContext as Element).markNeedsBuild();
              }
            },
            onSubmitted: (_) async {
              await tryCreate();
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await tryCreate();
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (shouldCreate != true) {
      _folderNameController.clear();
      return;
    }
    _folderNameController.clear();

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _openDirectory(Directory directory) {
    setState(() {
      _currentDirectory = directory;
    });
  }

  @override
  Widget build(BuildContext context) {
    final folders = _directoriesInCurrentPath();
    final pathDirectories = _pathDirectories();
    final contentKey = ValueKey('${_currentDirectory.path}-${folders.length}');

    return Container(
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[100],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      children: [
                        Text(
                          "Files",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[900],
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${folders.length} ${folders.length == 1 ? "folder" : "folders"}',
                          style: TextStyle(
                            color: Colors.blueGrey[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 18),
                Material(
                  color: Colors.blueGrey[100],
                  borderRadius: BorderRadius.circular(5),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(5),
                    onTap: _createFolder,
                    splashColor: Colors.blueGrey[200],
                    highlightColor: Colors.blueGrey[300],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.create_new_folder,
                            color: Colors.blueGrey[900],
                          ),
                          SizedBox(width: 8),
                          Text(
                            'New Folder',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 17),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var index = 0; index < pathDirectories.length; index++)
                  _PathCrumb(
                    label: index == 0
                        ? widget.projectName
                        : pathDirectories[index].path
                              .split(Platform.pathSeparator)
                              .last,
                    isActive:
                        pathDirectories[index].path == _currentDirectory.path,
                    onTap: () => _openDirectory(pathDirectories[index]),
                  ),
              ],
            ),
            SizedBox(height: 17),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: folders.isEmpty
                    ? Center(
                        key: contentKey,
                        child: Text(
                          'No folders here yet.',
                          style: TextStyle(
                            color: Colors.blueGrey[500],
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        key: contentKey,
                        itemCount: folders.length,
                        itemBuilder: (context, index) {
                          final folder = folders[index];
                          return FileButton(
                            name: folder.path
                                .split(Platform.pathSeparator)
                                .last,
                            onTap: () => _openDirectory(folder),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathCrumb extends StatelessWidget {
  const _PathCrumb({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? Colors.blueGrey[700] : Colors.blueGrey[200],
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.blueGrey[900],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class FileButton extends StatelessWidget {
  const FileButton({super.key, required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Material(
        color: Colors.blueGrey[300],
        borderRadius: BorderRadius.circular(5),
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: onTap,
          child: ListTile(
            leading: Icon(Icons.folder, color: Colors.white),
            title: Text(
              name,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Collaborators extends StatefulWidget {
  const Collaborators({super.key, required this.projectName});

  final String projectName;

  @override
  State<Collaborators> createState() => _CollaboratorsState();
}

class _CollaboratorsState extends State<Collaborators> {
  final TextEditingController _nameController = TextEditingController();
  final List<String> _collaborators = [];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addCollaborator() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    setState(() {
      _collaborators.add(name);
      _nameController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[100],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      'Collaborators',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Collaborator name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    onSubmitted: (_) => _addCollaborator(),
                  ),
                ),
                SizedBox(width: 10),
                FilledButton(
                  onPressed: _addCollaborator,
                  child: const Text('Add'),
                ),
              ],
            ),
            SizedBox(height: 16),
            Expanded(
              child: _collaborators.isEmpty
                  ? Center(
                      child: Text(
                        'No collaborators yet.',
                        style: TextStyle(
                          color: Colors.blueGrey[500],
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _collaborators.length,
                      itemBuilder: (context, index) {
                        final collaborator = _collaborators[index];
                        return Card(
                          color: Colors.white,
                          child: ListTile(
                            leading: Icon(
                              Icons.person,
                              color: Colors.blueGrey[700],
                            ),
                            title: Text(collaborator),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectSettings extends StatelessWidget {
  const ProjectSettings({
    super.key,
    required this.projectName,
    required this.projectFolder,
  });

  final String projectName;
  final Directory projectFolder;

  Future<void> _renameProject(BuildContext context) async {
    var projectAlreadyExists = false;
    var nextProjectName = projectName;

    final shouldRename = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogElement = dialogContext as Element;

        Future<void> tryRename() async {
          final nextName = nextProjectName.trim();
          if (nextName.isEmpty || nextName == projectName) {
            return;
          }

          final parentPath = projectFolder.parent.path;
          final renamedProject = Directory(
            '$parentPath${Platform.pathSeparator}$nextName',
          );

          if (renamedProject.existsSync()) {
            projectAlreadyExists = true;
            if (dialogElement.mounted) {
              dialogElement.markNeedsBuild();
            }
            return;
          }

          try {
            await projectFolder.rename(renamedProject.path);
          } catch (_) {
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not rename project folder.')),
            );
            return;
          }

          if (!context.mounted) {
            return;
          }

          Navigator.of(dialogContext).pop(true);
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Rename project'),
          content: TextFormField(
            initialValue: projectName,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Project name',
              errorText: projectAlreadyExists
                  ? 'A project with this name already exists.'
                  : null,
            ),
            onChanged: (value) {
              nextProjectName = value;
              if (projectAlreadyExists) {
                projectAlreadyExists = false;
                if (dialogElement.mounted) {
                  dialogElement.markNeedsBuild();
                }
              }
            },
            onFieldSubmitted: (_) {
              FocusScope.of(dialogContext).unfocus();
              Future<void>.microtask(tryRename);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await tryRename();
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    if (shouldRename != true || !context.mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  Future<void> _deleteProject(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          title: const Text('Delete project'),
          content: Text(
            'Delete "$projectName" permanently? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      if (projectFolder.existsSync()) {
        await projectFolder.delete(recursive: true);
      }
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete project folder.')),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[100],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[100],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          projectName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey[900],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blueGrey[700]),
                          onPressed: () {
                            _renameProject(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 17),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueGrey[100],
                borderRadius: BorderRadius.circular(5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Danger Zone',
                    style: TextStyle(
                      color: Colors.red[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Deleting this project removes the folder and all files inside it.',
                    style: TextStyle(color: Colors.blueGrey[800]),
                  ),
                  SizedBox(height: 14),
                  Material(
                    color: Colors.red[700],
                    borderRadius: BorderRadius.circular(5),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(5),
                      onTap: () => _deleteProject(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.delete_forever, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Delete Project',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
