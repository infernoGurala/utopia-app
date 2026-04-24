with open('lib/screens/class_detail_screen.dart', 'r') as f:
    lines = f.readlines()

replacement = """                                  () {
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
                                    if (iconKey != null && kFolderIconCatalogue.containsKey(iconKey)) {
                                      return Icon(kFolderIconCatalogue[iconKey]!.$1, color: isFolder ? itemColor : U.primary, size: isFolder ? 26 : 22);
                                    }
                                    return Icon(iconData.$1, color: isFolder ? itemColor : iconData.$2, size: isFolder ? 26 : 22);
                                  }(),\n"""

# Replace lines 864 to 885 (inclusive, 1-indexed)
# In 0-indexed, it's 863 to 885.
new_lines = lines[:863] + [replacement] + lines[885:]

with open('lib/screens/class_detail_screen.dart', 'w') as f:
    f.writelines(new_lines)
print("done")
