import 'dart:convert';
import 'package:appflowy_editor/appflowy_editor.dart';

/// Lossless converter between Utopia Markdown strings and AppFlowy Editor [Document]s.
class AppFlowyMarkdownConverter {
  /// Converts a Utopia Markdown string into an AppFlowy [Document].
  static Document markdownToDocument(String markdown) {
    if (markdown.trim().isEmpty) {
      return Document.blank();
    }

    final rootChildren = <Node>[];
    final lines = markdown.split('\n');
    int i = 0;

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      // 1. Check for LaTeX Block ($$ ... $$)
      if (trimmed == '\$\$' || (trimmed.startsWith('\$\$') && trimmed.endsWith('\$\$') && trimmed.length > 4)) {
        if (trimmed == '\$\$') {
          i++;
          final buf = StringBuffer();
          while (i < lines.length && lines[i].trim() != '\$\$') {
            buf.writeln(lines[i]);
            i++;
          }
          if (i < lines.length && lines[i].trim() == '\$\$') i++;
          rootChildren.add(Node(
            type: 'latex_block',
            attributes: {'content': buf.toString().trim()},
          ));
          continue;
        } else {
          final content = trimmed.substring(2, trimmed.length - 2).trim();
          rootChildren.add(Node(
            type: 'latex_block',
            attributes: {'content': content},
          ));
          i++;
          continue;
        }
      }

      // 2. Check for Code Block or Mermaid Block (``` ...)
      if (trimmed.startsWith('```')) {
        final lang = trimmed.substring(3).trim();
        i++;
        final codeBuf = StringBuffer();
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          codeBuf.writeln(lines[i]);
          i++;
        }
        if (i < lines.length && lines[i].trim().startsWith('```')) i++;

        final rawCode = codeBuf.toString().trimRight();

        if (lang == 'mermaid') {
          String dir = 'TD';
          String diagramContent = rawCode;
          if (rawCode.startsWith('graph ')) {
            final firstLineEnd = rawCode.indexOf('\n');
            if (firstLineEnd != -1) {
              dir = rawCode.substring(6, firstLineEnd).trim();
              diagramContent = rawCode.substring(firstLineEnd + 1).trim();
            } else {
              dir = rawCode.substring(6).trim();
              diagramContent = '';
            }
          }
          rootChildren.add(Node(
            type: 'mermaid_block',
            attributes: {
              'direction': dir.isEmpty ? 'TD' : dir,
              'content': diagramContent,
            },
          ));
        } else if (lang == 'qa') {
          final parts = rawCode.split('\n---\n');
          final question = parts.isNotEmpty ? parts[0].trim() : '';
          final answer = parts.length > 1 ? parts[1].trim() : '';
          rootChildren.add(Node(
            type: 'qa_block',
            attributes: {
              'question': question,
              'answer': answer,
            },
          ));
        } else {
          rootChildren.add(paragraphNode(
            text: '```$lang\n$rawCode\n```',
          ));
        }
        continue;
      }

      // 3. Check for Q&A Inline link format: Question text [^Answer^](qa://encoded_answer)
      final qaRegex = RegExp(r'^(.*?)\s*\[\^Answer\^\]\(qa:\/\/(.*?)\)$');
      final qaMatch = qaRegex.firstMatch(trimmed);
      if (qaMatch != null) {
        final question = qaMatch.group(1)?.trim() ?? '';
        final encodedAnswer = qaMatch.group(2) ?? '';
        String answer = '';
        try {
          answer = Uri.decodeComponent(encodedAnswer);
        } catch (_) {
          answer = encodedAnswer;
        }
        rootChildren.add(Node(
          type: 'qa_block',
          attributes: {
            'question': question,
            'answer': answer,
          },
        ));
        i++;
        continue;
      }

      // 4. Check for Cloudinary File Link or Image Link format: ![alt](url) OR [File Name](url "size")
      final fileLinkRegex = RegExp(r'^!?\[([^\]]*)\]\((https?:\/\/[^\s\)]+)(?:\s+"([^"]+)")?\)$');
      final fileMatch = fileLinkRegex.firstMatch(trimmed);
      if (fileMatch != null) {
        String name = fileMatch.group(1)?.trim() ?? 'File';
        final url = fileMatch.group(2)?.trim() ?? '';
        String? fileSize = fileMatch.group(3)?.trim();

        if (name.isEmpty) name = 'Image';

        if ((fileSize == null || fileSize.isEmpty) && name.contains(' | ')) {
          final parts = name.split(' | ');
          if (parts.length > 1 && (parts.last.endsWith('B') || parts.last.endsWith('KB') || parts.last.endsWith('MB') || parts.last.endsWith('GB'))) {
            name = parts.sublist(0, parts.length - 1).join(' | ');
            fileSize = parts.last;
          }
        }

        rootChildren.add(Node(
          type: 'cloudinary_file_block',
          attributes: {
            'display_name': name,
            'url': url,
            if (fileSize != null && fileSize.isNotEmpty) 'file_size': fileSize,
          },
        ));
        i++;
        continue;
      }

      // 5. Check for Markdown Table (| cell | cell |)
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        final tableLines = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('|') && lines[i].trim().endsWith('|')) {
          tableLines.add(lines[i].trim());
          i++;
        }
        if (tableLines.length >= 2) {
          final grid = <List<String>>[];
          for (final tLine in tableLines) {
            // Ignore separator line like |---|---|
            if (RegExp(r'^\|(\s*:?-+:?\s*\|)+$').hasMatch(tLine)) continue;
            final cells = tLine
                .substring(1, tLine.length - 1)
                .split('|')
                .map((c) => c.trim())
                .toList();
            grid.add(cells);
          }
          if (grid.isNotEmpty) {
            rootChildren.add(Node(
              type: 'table_block',
              attributes: {
                'data': jsonEncode(grid),
              },
            ));
            continue;
          }
        }
      }

      // 6. Headings (# Heading 1, ## Heading 2, ### Heading 3)
      if (trimmed.startsWith('#')) {
        int level = 0;
        while (level < trimmed.length && trimmed[level] == '#') {
          level++;
        }
        if (level > 0 && level <= 6 && level < trimmed.length && trimmed[level] == ' ') {
          final headingText = trimmed.substring(level + 1).trim();
          rootChildren.add(headingNode(
            level: level.clamp(1, 6),
            text: headingText,
          ));
          i++;
          continue;
        }
      }

      // 7. Bulleted list (- item, * item)
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        final itemText = trimmed.substring(2).trim();
        rootChildren.add(bulletedListNode(
          text: itemText,
        ));
        i++;
        continue;
      }

      // 8. Numbered list (1. item)
      final numMatch = RegExp(r'^\d+\.\s+').firstMatch(trimmed);
      if (numMatch != null) {
        final itemText = trimmed.substring(numMatch.end).trim();
        rootChildren.add(numberedListNode(
          delta: Delta()..insert(itemText),
        ));
        i++;
        continue;
      }

      // 9. Quote block (> quote)
      if (trimmed.startsWith('> ')) {
        final quoteText = trimmed.substring(2).trim();
        rootChildren.add(quoteNode(
          delta: Delta()..insert(quoteText),
        ));
        i++;
        continue;
      }

      // 10. Default: Paragraph
      rootChildren.add(paragraphNode(
        text: trimmed,
      ));
      i++;
    }

    if (rootChildren.isEmpty) {
      return Document.blank();
    }

    return Document(
      root: Node(
        type: 'page',
        children: rootChildren,
      ),
    );
  }

  /// Converts an AppFlowy [Document] back into a Lossless Utopia Markdown string.
  static String documentToMarkdown(Document document) {
    final buf = StringBuffer();
    final children = document.root.children;

    for (int idx = 0; idx < children.length; idx++) {
      final node = children.elementAt(idx);
      final type = node.type;

      switch (type) {
        case 'heading':
          final level = (node.attributes['level'] as int?) ?? 1;
          final hashes = '#' * level;
          final text = _getNodeText(node);
          buf.writeln('$hashes $text');
          buf.writeln();
          break;

        case 'paragraph':
          final text = _getNodeText(node);
          if (text.trim().isNotEmpty) {
            buf.writeln(text.trim());
            buf.writeln();
          }
          break;

        case 'bulleted_list':
          final text = _getNodeText(node);
          buf.writeln('- $text');
          break;

        case 'numbered_list':
          final text = _getNodeText(node);
          buf.writeln('1. $text');
          break;

        case 'quote':
          final text = _getNodeText(node);
          buf.writeln('> $text');
          buf.writeln();
          break;

        case 'qa_block':
          final question = (node.attributes['question'] as String?) ?? '';
          final answer = (node.attributes['answer'] as String?) ?? '';
          final encodedAnswer = Uri.encodeComponent(answer);
          buf.writeln('$question [^Answer^](qa://$encodedAnswer)');
          buf.writeln();
          break;

        case 'latex_block':
          final content = (node.attributes['content'] as String?) ?? '';
          buf.writeln('\$\$');
          buf.writeln(content);
          buf.writeln('\$\$');
          buf.writeln();
          break;

        case 'mermaid_block':
          final dir = (node.attributes['direction'] as String?) ?? 'TD';
          final content = (node.attributes['content'] as String?) ?? '';
          buf.writeln('```mermaid');
          buf.writeln('graph $dir');
          buf.writeln(content);
          buf.writeln('```');
          buf.writeln();
          break;

        case 'cloudinary_file_block':
          final name = (node.attributes['display_name'] as String?) ?? 'File';
          final url = (node.attributes['url'] as String?) ?? '';
          final fileSize = (node.attributes['file_size'] as String?) ?? '';
          final isImage = _isImageUrl(url, name);
          final prefix = isImage ? '!' : '';
          if (fileSize.isNotEmpty) {
            buf.writeln('$prefix[$name]($url "$fileSize")');
          } else {
            buf.writeln('$prefix[$name]($url)');
          }
          buf.writeln();
          break;

        case 'table_block':
          final rawData = (node.attributes['data'] as String?) ?? '[]';
          List<List<String>> grid = [];
          try {
            final List dynamicGrid = jsonDecode(rawData);
            grid = dynamicGrid.map((row) => (row as List).map((cell) => cell.toString()).toList()).toList();
          } catch (_) {}

          if (grid.isNotEmpty) {
            // Header
            buf.writeln('| ${grid[0].map((c) => c.isEmpty ? ' ' : c).join(' | ')} |');
            buf.writeln('| ${grid[0].map((_) => '---').join(' | ')} |');
            // Rows
            for (int r = 1; r < grid.length; r++) {
              buf.writeln('| ${grid[r].map((c) => c.isEmpty ? ' ' : c).join(' | ')} |');
            }
            buf.writeln();
          }
          break;

        default:
          final text = _getNodeText(node);
          if (text.trim().isNotEmpty) {
            buf.writeln(text.trim());
            buf.writeln();
          }
          break;
      }
    }

    return buf.toString().trimRight();
  }

  static bool _isImageUrl(String url, String name) {
    final cleanUrl = url.split('?').first.toLowerCase();
    final ext = cleanUrl.split('.').last;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp', 'svg'].contains(ext)) return true;
    if (url.contains('/image/upload/')) return true;
    final nameExt = name.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp', 'svg'].contains(nameExt)) return true;
    return false;
  }

  static String _getNodeText(Node node) {
    final nodeDelta = node.delta;
    if (nodeDelta != null) {
      return nodeDelta.toPlainText();
    }
    final rawDelta = node.attributes['delta'];
    if (rawDelta is Delta) {
      return rawDelta.toPlainText();
    }
    if (node.children.isNotEmpty) {
      return node.children.map((c) => _getNodeText(c)).join(' ');
    }
    return '';
  }
}
