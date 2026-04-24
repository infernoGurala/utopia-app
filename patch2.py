with open('lib/screens/class_detail_screen.dart', 'r') as f: lines = f.readlines()

new_lines = []
skip = False

import_added = False
for i, line in enumerate(lines):
    if line.startswith("import 'package:flutter/material.dart';") and not import_added:
        new_lines.append(line)
        new_lines.append("import 'dart:async';\n")
        import_added = True
        continue
        
    if "List<Map<String, dynamic>> _items = [];" in line:
        new_lines.append(line)
        new_lines.append("  bool _editModeEnabled = false;\n")
        new_lines.append("  bool _warningShown = false;\n")
        new_lines.append("  Map<String, String> _folderIcons = {};\n")
        continue

    if "void _navigateBack() {" in line:
        helpers = """
  Future<void> _setFolderIcon(String folderPath, String iconKey) async {
    setState(() => _folderIcons[folderPath] = iconKey);
  }

  Future<void> _removeFolderIcon(String folderPath) async {
    setState(() => _folderIcons.remove(folderPath));
  }

  static String _displayName(String name) {
    final match = RegExp(r'__[0-9a-f]{4}$').firstMatch(name);
    if (match != null) return name.substring(0, match.start);
    return name;
  }

  static String _uniqueName(String displayName) {
    final code = (DateTime.now().millisecondsSinceEpoch & 0xFFFF).toRadixString(16).padLeft(4, '0');
    return '${displayName}__$code';
  }

  (IconData, Color) _iconFor(String name, String path) {
    final overrideKey = _folderIcons[path];
    if (overrideKey != null && overrideKey.startsWith('num_')) {
      return (Icons.tag_outlined, U.teal);
    }
    
    final key = name.toLowerCase();
    if (key.contains('doc') || key.contains('note')) return (Icons.article_outlined, U.primary);
    if (key.contains('assign')) return (Icons.assignment_outlined, U.peach);
    if (key.contains('quiz') || key.contains('test')) return (Icons.quiz_outlined, U.peach);
    
    return (Icons.folder_outlined, U.primary);
  }

  void _showRenameDialog(Map<String, dynamic> item, bool isFolder) {
    final oldName = item['name'] as String;
    final path = item['path'] as String;
    final displayOld = _displayName(oldName).replaceAll('.md', '');
    final controller = TextEditingController(text: displayOld);
    bool isRenaming = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: U.surface,
          title: Text('Rename', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
          content: TextField(
            controller: controller,
            style: GoogleFonts.outfit(color: U.text),
            decoration: InputDecoration(
              hintText: 'New name', hintStyle: GoogleFonts.outfit(color: U.sub),
              filled: true, fillColor: U.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: U.border)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub)),
            ),
            FilledButton(
              onPressed: isRenaming
                  ? null
                  : () async {
                      var newName = controller.text.trim();
                      if (newName.isEmpty || newName == displayOld) return;
                      // Only add .md for files
                      if (!isFolder && !newName.endsWith('.md')) newName += '.md';

                      setDialogState(() => isRenaming = true);
                      Navigator.pop(ctx);

                      String ghNewName;
                      if (isFolder) {
                        final oldSuffixMatch = RegExp(r'__[0-9a-f]{4}$').firstMatch(oldName);
                        if (oldSuffixMatch != null) {
                          ghNewName = '$newName${oldSuffixMatch.group(0)}';
                        } else {
                          ghNewName = _uniqueName(newName);
                        }
                      } else {
                        ghNewName = newName;
                      }

                      final parentPath = path.substring(0, path.lastIndexOf('/'));
                      final newPath = parentPath.isEmpty ? ghNewName : '$parentPath/$ghNewName';

                      final originalItems = List<Map<String, dynamic>>.from(_items);
                      setState(() {
                        final index = _items.indexWhere((i) => i['path'] == path);
                        if (index != -1) {
                          _items[index] = {..._items[index], 'name': ghNewName, 'path': newPath};
                        }
                      });

                      final success = await _github.renameItem(path, newPath);

                      if (mounted) {
                        if (!success) {
                          setState(() => _items = originalItems);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(success ? 'Renamed to $displayOld' : 'Failed to rename'), backgroundColor: success ? U.green : U.red),
                        );
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: U.primary),
              child: Text(isRenaming ? 'Renaming...' : 'Rename', style: GoogleFonts.outfit(color: U.bg)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> item) {
    final name = item['name'] as String;
    final path = item['path'] as String;
    final displayName = _displayName(name).replaceAll('.md', '');
    
    int countdown = 5;
    Timer? timer;
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (timer == null) {
            timer = Timer.periodic(const Duration(seconds: 1), (t) {
              if (countdown > 0) setDialogState(() => countdown--);
              else t.cancel();
            });
          }

          return AlertDialog(
            backgroundColor: U.surface,
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: U.red, size: 28),
                const SizedBox(width: 10),
                Text('Delete Item', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
              ],
            ),
            content: Text('Are you sure you want to permanently delete "$displayName"?\\n\\nThis action cannot be undone.', style: GoogleFonts.outfit(color: U.sub, fontSize: 14)),
            actions: [
              TextButton(
                onPressed: () { timer?.cancel(); Navigator.pop(ctx); },
                child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub)),
              ),
              FilledButton(
                onPressed: countdown > 0 || isDeleting ? null : () async {
                  setDialogState(() => isDeleting = true);
                  Navigator.pop(ctx);
                  
                  final originalItems = List<Map<String, dynamic>>.from(_items);
                  setState(() { _items.removeWhere((i) => i['path'] == path); });

                  final success = await _github.deleteItem(path);

                  if (mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted "$displayName"'), backgroundColor: U.green));
                    } else {
                      setState(() => _items = originalItems);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete "$displayName"'), backgroundColor: U.red));
                    }
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: U.red, disabledBackgroundColor: U.red.withOpacity(0.3)),
                child: Text(isDeleting ? 'Deleting...' : (countdown > 0 ? 'Delete in ${countdown}s' : 'Delete Now'), style: GoogleFonts.outfit(color: U.bg)),
              ),
            ],
          );
        },
      ),
    ).then((_) { timer?.cancel(); });
  }

  void _showAddItemDialog() {
    final controller = TextEditingController();
    bool isCreating = false;
    bool isFile = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: U.surface,
          title: Text('Add Item', style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: Text('File', style: GoogleFonts.outfit(color: U.text, fontSize: 14)),
                      value: true,
                      groupValue: isFile,
                      onChanged: (v) => setDialogState(() => isFile = v!),
                      activeColor: U.primary,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Folder', style: GoogleFonts.outfit(color: U.text, fontSize: 14)),
                      value: false,
                      groupValue: isFile,
                      onChanged: (v) => setDialogState(() => isFile = v!),
                      activeColor: U.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: GoogleFonts.outfit(color: U.text),
                decoration: InputDecoration(
                  hintText: 'Name', hintStyle: GoogleFonts.outfit(color: U.sub),
                  filled: true, fillColor: U.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: U.border)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.outfit(color: U.sub)),
            ),
            FilledButton(
              onPressed: isCreating ? null : () async {
                var name = controller.text.trim();
                if (name.isEmpty) return;
                if (isFile && !name.endsWith('.md')) name += '.md';
                final ghName = isFile ? name : _uniqueName(name);

                setDialogState(() => isCreating = true);
                Navigator.pop(ctx);

                final targetPath = isFile ? '$_fullPath$ghName' : '$_fullPath$ghName/.keep';

                final originalItems = List<Map<String, dynamic>>.from(_items);
                setState(() {
                  _items.insert(0, {
                    'name': ghName,
                    'type': isFile ? 'file' : 'dir',
                    'path': targetPath,
                    'size': isFile ? 0 : null,
                    'download_url': isFile ? 'new' : null,
                  });
                });

                final success = await _github.createFolder(
                  targetPath,
                  content: isFile ? '# ${name.replaceAll('.md', '')}\\n\\n' : '# init\\n',
                );

                if (mounted) {
                  if (!success) {
                    setState(() => _items = originalItems);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? '$name created!' : 'Failed to create $name'), backgroundColor: success ? U.green : U.red),
                  );
                }
              },
              style: FilledButton.styleFrom(backgroundColor: U.primary),
              child: Text(isCreating ? 'Creating...' : 'Create', style: GoogleFonts.outfit(color: U.bg)),
            ),
          ],
        ),
      ),
    );
  }

"""
        new_lines.append(helpers)
        new_lines.append(line)
        continue

    if "        actions: [" in line and "_userRole == 'writer'" not in line and "IconButton" not in lines[i+1]:
        # we found actions: [ inside AppBar. We will inject the FAB later, so we just append.
        new_lines.append(line)
        continue

    if "      body: Column(" in line:
        fab_code = """
      floatingActionButton: _userRole == 'writer' ? FloatingActionButton(
        onPressed: () {
          if (_editModeEnabled) {
            _showAddItemDialog();
          } else {
            setState(() => _editModeEnabled = true);
          }
        },
        backgroundColor: _editModeEnabled ? U.primary : U.surface,
        child: Icon(_editModeEnabled ? Icons.add : Icons.edit_outlined, color: _editModeEnabled ? U.bg : U.text),
      ) : null,
"""
        new_lines.append(fab_code)
        new_lines.append(line)
        continue

    if ": ListView.builder(" in line:
        skip = True
        list_view_code = """                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 116),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => Divider(
                      color: U.border,
                      height: 1,
                      thickness: 0.5,
                      indent: 56,
                    ),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final name = item['name'] as String;
                      final type = item['type'] as String;
                      final path = item['path'] as String;
                      final isFolder = type == 'dir';

                      final displayTitle = _displayName(name).replaceAll('.md', '');
                      final iconData = _iconFor(name, path);

                      final palette = [
                        U.cyan,
                        U.teal,
                        U.peach,
                        U.primary,
                        U.blue,
                        U.lavender,
                        U.gold,
                        U.red,
                      ];
                      final itemColor = isFolder ? palette[index % palette.length] : U.sub;

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 250 + index * 45),
                        curve: Curves.easeOut,
                        builder: (context, v, child) => Opacity(
                          opacity: v,
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1 - v)),
                            child: child,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            if (isFolder) {
                              _navigateToFolder(name);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NoteViewerScreen(
                                    title: displayTitle,
                                    filePath: path,
                                    isEditable: _editModeEnabled && _userRole == 'writer',
                                    useGlobalRepo: true,
                                  ),
                                ),
                              );
                            }
                          },
                          splashColor: itemColor.withOpacity(0.06),
                          highlightColor: itemColor.withOpacity(0.04),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Row(
                              children: [
                                if (!isFolder) ...[
                                  Icon(Icons.article_outlined, color: itemColor, size: 22),
                                ] else ...[
                                  () {
                                    final iconKey = _folderIcons[path];
                                    if (iconKey != null && iconKey.startsWith('num_')) {
                                      final numText = iconKey.replaceFirst('num_', '');
                                      return Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(color: itemColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                        child: Center(
                                          child: Text(
                                            numText,
                                            style: GoogleFonts.outfit(color: itemColor, fontSize: 12, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      );
                                    }
                                    return Icon(iconData.$1, color: itemColor, size: 26);
                                  }(),
                                ],
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayTitle.trim(),
                                        style: GoogleFonts.outfit(
                                          color: U.text,
                                          fontSize: 16,
                                          fontWeight: isFolder ? FontWeight.w500 : FontWeight.w400,
                                        ),
                                      ),
                                      if (!isFolder && item['size'] != null && !name.toLowerCase().endsWith('.md'))
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            _formatFileSize(item['size'] as int),
                                            style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (_editModeEnabled && _userRole == 'writer')
                                  PopupMenuButton<String>(
                                    color: U.surface,
                                    padding: EdgeInsets.zero,
                                    tooltip: 'Actions',
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Center(child: Icon(Icons.more_vert, color: U.dim, size: 16)),
                                    ),
                                    splashRadius: 18,
                                    onSelected: (value) {
                                      if (value == 'edit') _showRenameDialog(item, isFolder);
                                      if (value == 'delete') _showDeleteDialog(item);
                                    },
                                    itemBuilder: (ctx) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit_outlined, color: U.text, size: 14),
                                            const SizedBox(width: 6),
                                            Text('Rename', style: GoogleFonts.outfit(color: U.text, fontSize: 13, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.delete_outline, color: U.red, size: 14),
                                            const SizedBox(width: 6),
                                            Text('Delete', style: GoogleFonts.outfit(color: U.red, fontSize: 13, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
"""
        new_lines.append(list_view_code)
        continue

    if skip:
        # Check for end of listview
        if line.strip() == ")," and lines[i+1].strip() == "]," and lines[i+2].strip() == "),":
            skip = False
            # append line? No, the list_view_code includes the closing `,`
        continue
        
    new_lines.append(line)

with open('lib/screens/class_detail_screen.dart', 'w') as f: f.writelines(new_lines)
print("done")
