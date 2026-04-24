with open('lib/screens/class_detail_screen.dart', 'r') as f:
    text = f.read()

import re

old_block = r"""                                children: \[
                                  if \(!isFolder\) \.\.\. \[
                                    Icon\(Icons\.article_outlined, color: itemColor, size: 22\),
                                  \] else \.\.\. \[
                                    \(\) \{
                                      final iconKey = _folderIcons\[path\];
                                      if \(iconKey != null && iconKey\.startsWith\('num_'\)\) \{
                                        final numText = iconKey\.replaceFirst\('num_', ''\);
                                        return Container\(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration\(color: itemColor\.withOpacity\(0\.1\), borderRadius: BorderRadius\.circular\(8\)\),
                                          child: Center\(
                                            child: Text\(
                                              numText,
                                              style: GoogleFonts\.outfit\(color: itemColor, fontSize: 12, fontWeight: FontWeight\.w700\),
                                            \),
                                          \),
                                        \);
                                      \}
                                      return Icon\(iconData\.\$1, color: itemColor, size: 26\);
                                    \}\(\),
                                  \],"""

new_block = r"""                                children: [
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
                                    if (iconKey != null && kFolderIconCatalogue.containsKey(iconKey)) {
                                      return Icon(kFolderIconCatalogue[iconKey]!.$1, color: isFolder ? itemColor : U.primary, size: isFolder ? 26 : 22);
                                    }
                                    return Icon(iconData.$1, color: isFolder ? itemColor : iconData.$2, size: isFolder ? 26 : 22);
                                  }(),"""

new_text = re.sub(old_block, new_block, text)
if new_text != text:
    with open('lib/screens/class_detail_screen.dart', 'w') as f:
        f.write(new_text)
    print("done")
else:
    print("failed to find block")
