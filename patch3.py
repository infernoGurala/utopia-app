with open('lib/screens/class_detail_screen.dart', 'r') as f: lines = f.readlines()

new_lines = []
skip = False

catalogues = """
const Map<String, (IconData, String)> kFolderIconCatalogue = {
  'school': (Icons.school_outlined, 'School'),
  'book': (Icons.menu_book_outlined, 'Book'),
  'library': (Icons.local_library_outlined, 'Library'),
  'assignment': (Icons.assignment_outlined, 'Assignment'),
  'quiz': (Icons.quiz_outlined, 'Quiz'),
  'article': (Icons.article_outlined, 'Article'),
  'bookmark': (Icons.collections_bookmark_outlined, 'Bookmark'),
  'folder': (Icons.folder_outlined, 'Folder'),
  'topic': (Icons.topic_outlined, 'Topic'),
  'math': (Icons.functions_outlined, 'Mathematics'),
  'calculate': (Icons.calculate_outlined, 'Calculate'),
  'analytics': (Icons.analytics_outlined, 'Analytics'),
  'bar_chart': (Icons.bar_chart_outlined, 'Statistics'),
  'science': (Icons.science_outlined, 'Science'),
  'rocket': (Icons.rocket_launch_outlined, 'Rocket'),
  'speed': (Icons.speed_outlined, 'Dynamics'),
  'thermostat': (Icons.thermostat_outlined, 'Thermo'),
  'waves': (Icons.waves_outlined, 'Waves'),
  'compress': (Icons.compress_outlined, 'Mechanics'),
  'straighten': (Icons.straighten_outlined, 'Measure'),
  'electrical': (Icons.electrical_services_outlined, 'Electrical'),
  'bolt': (Icons.bolt_outlined, 'Power'),
  'memory': (Icons.memory_outlined, 'Chip'),
  'developer_board': (Icons.developer_board_outlined, 'Board'),
  'cable': (Icons.cable_outlined, 'Cable'),
  'battery': (Icons.battery_charging_full_outlined, 'Battery'),
  'sensors': (Icons.sensors_outlined, 'Sensors'),
  'cell_tower': (Icons.cell_tower_outlined, 'Tower'),
  'code': (Icons.code_outlined, 'Code'),
  'terminal': (Icons.terminal_outlined, 'Terminal'),
  'storage': (Icons.storage_outlined, 'Database'),
  'cloud': (Icons.cloud_outlined, 'Cloud'),
  'lan': (Icons.lan_outlined, 'Network'),
  'security': (Icons.security_outlined, 'Security'),
  'bug': (Icons.bug_report_outlined, 'Debug'),
  'architecture': (Icons.architecture_outlined, 'Architecture'),
  'foundation': (Icons.foundation_outlined, 'Foundation'),
  'construction': (Icons.construction_outlined, 'Construction'),
  'engineering': (Icons.engineering_outlined, 'Engineering'),
  'terrain': (Icons.terrain_outlined, 'Terrain'),
  'location_city': (Icons.location_city_outlined, 'Structures'),
  'biotech': (Icons.biotech_outlined, 'Biotech'),
  'water_drop': (Icons.water_drop_outlined, 'Fluids'),
  'local_fire': (Icons.local_fire_department_outlined, 'Thermo'),
  'eco': (Icons.eco_outlined, 'Eco'),
  'opacity': (Icons.opacity_outlined, 'Chemistry'),
  'build': (Icons.build_outlined, 'Tools'),
  'handyman': (Icons.handyman_outlined, 'Workshop'),
  'precision_mfg': (Icons.precision_manufacturing_outlined, 'Manufacturing'),
  'settings': (Icons.settings_outlined, 'Gears'),
  'hardware': (Icons.hardware_outlined, 'Hardware'),
  'language': (Icons.language_outlined, 'Language'),
  'psychology': (Icons.psychology_outlined, 'Psychology'),
  'business': (Icons.business_center_outlined, 'Business'),
  'economics': (Icons.trending_up_outlined, 'Economics'),
  'groups': (Icons.groups_outlined, 'Management'),
  'fact_check': (Icons.fact_check_outlined, 'Fact Check'),
  'exam': (Icons.edit_note_outlined, 'Exam'),
  'checklist': (Icons.checklist_outlined, 'Checklist'),
  'category': (Icons.category_outlined, 'Category'),
  'archive': (Icons.archive_outlined, 'Archive'),
  'lightbulb': (Icons.lightbulb_outlined, 'Ideas'),
  'draw': (Icons.draw_outlined, 'Draw'),
  'palette': (Icons.palette_outlined, 'Design'),
  'explore': (Icons.explore_outlined, 'Explore'),
};

const List<(String, List<(String, IconData)>)> kIconCategories = [
  ('Mechanical', [
    ('speed', Icons.speed_outlined),
    ('thermostat', Icons.thermostat_outlined),
    ('compress', Icons.compress_outlined),
    ('precision_mfg', Icons.precision_manufacturing_outlined),
    ('build', Icons.build_outlined),
    ('hardware', Icons.hardware_outlined),
    ('handyman', Icons.handyman_outlined),
    ('settings', Icons.settings_outlined),
    ('straighten', Icons.straighten_outlined),
    ('local_fire', Icons.local_fire_department_outlined),
  ]),
  ('Electrical & Electronics', [
    ('electrical', Icons.electrical_services_outlined),
    ('bolt', Icons.bolt_outlined),
    ('memory', Icons.memory_outlined),
    ('developer_board', Icons.developer_board_outlined),
    ('cable', Icons.cable_outlined),
    ('battery', Icons.battery_charging_full_outlined),
    ('sensors', Icons.sensors_outlined),
    ('cell_tower', Icons.cell_tower_outlined),
    ('waves', Icons.waves_outlined),
  ]),
  ('Computer Science', [
    ('code', Icons.code_outlined),
    ('terminal', Icons.terminal_outlined),
    ('storage', Icons.storage_outlined),
    ('cloud', Icons.cloud_outlined),
    ('lan', Icons.lan_outlined),
    ('security', Icons.security_outlined),
    ('bug', Icons.bug_report_outlined),
  ]),
  ('Civil & Architecture', [
    ('architecture', Icons.architecture_outlined),
    ('foundation', Icons.foundation_outlined),
    ('construction', Icons.construction_outlined),
    ('engineering', Icons.engineering_outlined),
    ('terrain', Icons.terrain_outlined),
    ('location_city', Icons.location_city_outlined),
  ]),
  ('Science & Chemistry', [
    ('science', Icons.science_outlined),
    ('biotech', Icons.biotech_outlined),
    ('water_drop', Icons.water_drop_outlined),
    ('eco', Icons.eco_outlined),
    ('opacity', Icons.opacity_outlined),
    ('rocket', Icons.rocket_launch_outlined),
  ]),
  ('Mathematics & Stats', [
    ('math', Icons.functions_outlined),
    ('calculate', Icons.calculate_outlined),
    ('analytics', Icons.analytics_outlined),
    ('bar_chart', Icons.bar_chart_outlined),
  ]),
  ('Academic', [
    ('school', Icons.school_outlined),
    ('book', Icons.menu_book_outlined),
    ('library', Icons.local_library_outlined),
    ('assignment', Icons.assignment_outlined),
    ('quiz', Icons.quiz_outlined),
    ('article', Icons.article_outlined),
    ('bookmark', Icons.collections_bookmark_outlined),
    ('topic', Icons.topic_outlined),
    ('folder', Icons.folder_outlined),
  ]),
  ('Others', [
    ('language', Icons.language_outlined),
    ('psychology', Icons.psychology_outlined),
    ('business', Icons.business_center_outlined),
    ('economics', Icons.trending_up_outlined),
    ('groups', Icons.groups_outlined),
    ('fact_check', Icons.fact_check_outlined),
    ('exam', Icons.edit_note_outlined),
    ('checklist', Icons.checklist_outlined),
    ('category', Icons.category_outlined),
    ('archive', Icons.archive_outlined),
    ('lightbulb', Icons.lightbulb_outlined),
    ('draw', Icons.draw_outlined),
    ('palette', Icons.palette_outlined),
    ('explore', Icons.explore_outlined),
  ]),
];
"""

for i, line in enumerate(lines):
    if "class ClassDetailScreen extends StatefulWidget {" in line:
        new_lines.append(catalogues)
        new_lines.append(line)
        continue

    if "(IconData, Color) _iconFor(String name, String path) {" in line:
        skip = True
        iconfor = """  (IconData, Color) _iconFor(String name, String path) {
    final overrideKey = _folderIcons[path];
    if (overrideKey != null) {
      if (overrideKey.startsWith('num_')) {
        return (Icons.tag_outlined, U.teal);
      }
      if (kFolderIconCatalogue.containsKey(overrideKey)) {
        return (kFolderIconCatalogue[overrideKey]!.$1, U.primary);
      }
    }
    
    final key = name.toLowerCase();
    if (key.contains('doc') || key.contains('note')) return (Icons.article_outlined, U.primary);
    if (key.contains('assign')) return (Icons.assignment_outlined, U.peach);
    if (key.contains('quiz') || key.contains('test')) return (Icons.quiz_outlined, U.peach);
    
    return (Icons.folder_outlined, U.primary);
  }
"""
        new_lines.append(iconfor)
        continue
    
    if skip and "return (Icons.folder_outlined, U.primary);" in line:
        skip = False
        continue
    
    if skip:
        continue

    if "void _showDeleteDialog(Map<String, dynamic> item) {" in line:
        iconpicker = """  void _showIconPicker(String folderPath) {
    final numController = TextEditingController();
    final currentIcon = _folderIcons[folderPath];
    if (currentIcon != null && currentIcon.startsWith('num_')) {
      numController.text = currentIcon.replaceFirst('num_', '');
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: U.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: U.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('Number', style: GoogleFonts.outfit(color: U.sub, fontSize: 13)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    height: 36,
                    child: TextField(
                      controller: numController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: U.teal, fontSize: 14, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: '1',
                        hintStyle: GoogleFonts.outfit(color: U.dim, fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        filled: true, fillColor: U.bg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: U.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: U.border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: U.teal)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final num = numController.text.trim();
                      if (num.isNotEmpty) {
                        _setFolderIcon(folderPath, 'num_$num');
                        Navigator.pop(ctx);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(color: U.teal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                      child: Text('Set', style: GoogleFonts.outfit(color: U.teal, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const Spacer(),
                  if (currentIcon != null)
                    GestureDetector(
                      onTap: () {
                        _removeFolderIcon(folderPath);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(color: U.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('Reset', style: GoogleFonts.outfit(color: U.red, fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: U.border, height: 1, thickness: 0.5),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: kIconCategories.length,
                itemBuilder: (ctx, catIndex) {
                  final category = kIconCategories[catIndex];
                  final catName = category.$1;
                  final icons = category.$2;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                        child: Text(catName, style: GoogleFonts.outfit(color: U.dim, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 8, runSpacing: 8,
                          children: icons.map((entry) {
                            final key = entry.$1;
                            final icon = entry.$2;
                            final isSelected = _folderIcons[folderPath] == key;
                            return GestureDetector(
                              onTap: () {
                                _setFolderIcon(folderPath, key);
                                Navigator.pop(ctx);
                              },
                              child: Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected ? U.primary.withValues(alpha: 0.15) : U.bg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isSelected ? U.primary : U.border, width: isSelected ? 1.5 : 0.5),
                                ),
                                child: Icon(icon, color: isSelected ? U.primary : U.sub, size: 20),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

"""
        new_lines.append(iconpicker)
        new_lines.append(line)
        continue

    if "if (value == 'edit') _showRenameDialog(item, isFolder);" in line:
        new_lines.append(line)
        new_lines.append("                                      if (value == 'icon') _showIconPicker(path);\n")
        continue

    if "const SizedBox(width: 6)," in line and "Text('Rename'," in lines[i+1]:
        # inside the rename PopupMenuItem, we need to add the icon change PopupMenuItem too
        new_lines.append(line)
        continue
    
    if "Text('Rename'," in line:
        new_lines.append(line)
        # we found the rename menu item, add the icon menu item before or after.
        # Let's add after.
        # I need to find the closing bracket of the Rename PopupMenuItem
        continue
    
    if line.strip() == ")," and i > 0 and "Text('Rename'," in lines[i-1]:
        new_lines.append(line)
        icon_menu_item = """                                      PopupMenuItem(
                                        value: 'icon',
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.palette_outlined, color: U.primary, size: 14),
                                            const SizedBox(width: 6),
                                            Text('Change Icon', style: GoogleFonts.outfit(color: U.primary, fontSize: 13, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ),
"""
        new_lines.append(icon_menu_item)
        continue

    new_lines.append(line)

with open('lib/screens/class_detail_screen.dart', 'w') as f: f.writelines(new_lines)
print("done")
