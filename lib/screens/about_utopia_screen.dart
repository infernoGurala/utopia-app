import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:webview_flutter/webview_flutter.dart';

import '../main.dart';
import '../services/platform_support.dart';

/// Screen displaying "About UTOPIA" settings options.
class AboutUtopiaScreen extends StatelessWidget {
  const AboutUtopiaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        title: Text(
          'About UTOPIA',
          style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600),
        ),
        backgroundColor: U.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: U.primary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildActionTile(
            context,
            icon: Icons.new_releases_outlined,
            title: 'Rollout Releases',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RolloutReleasesScreen(),
                ),
              );
            },
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideX(begin: -0.05, end: 0, duration: 500.ms, curve: Curves.easeOut),
          const SizedBox(height: 12),
          _buildActionTile(
            context,
            icon: Icons.info_outline_rounded,
            title: 'About',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EmptyPlaceholderScreen(title: 'About'),
                ),
              );
            },
          )
              .animate()
              .fadeIn(delay: 100.ms, duration: 500.ms)
              .slideX(begin: -0.05, end: 0, delay: 100.ms, duration: 500.ms, curve: Curves.easeOut),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: U.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: U.teal, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  color: U.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: U.sub, size: 20),
          ],
        ),
      ),
    );
  }
}

class RolloutReleasesScreen extends StatefulWidget {
  const RolloutReleasesScreen({super.key});

  @override
  State<RolloutReleasesScreen> createState() => _RolloutReleasesScreenState();
}

class _RolloutReleasesScreenState extends State<RolloutReleasesScreen> {
  String? _markdownContent;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMarkdown();
  }

  Future<void> _fetchMarkdown() async {
    try {
      final response = await http.get(Uri.parse(
          'https://raw.githubusercontent.com/theutopiadomain/utopia-global/main/Utopiarollout.md'
          '?cb=${DateTime.now().millisecondsSinceEpoch}'));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _markdownContent = response.body;
            _isLoading = false;
            _error = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load rollout information (${response.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Network error loading rollout information';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        title: Text(
          'Rollout Releases',
          style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600),
        ),
        backgroundColor: U.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: U.primary),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: U.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded, color: U.dim, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: GoogleFonts.outfit(color: U.sub, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () {
                          setState(() { _isLoading = true; _error = null; });
                          _fetchMarkdown();
                        },
                        icon: Icon(Icons.refresh_rounded, color: U.primary, size: 18),
                        label: Text('Retry', style: GoogleFonts.outfit(color: U.primary)),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: U.primary,
                  backgroundColor: U.card,
                  onRefresh: _fetchMarkdown,
                  child: _buildMarkdownBody(),
                ),
    );
  }

  Widget _buildMarkdownBody() {
    final content = _markdownContent ?? '';

    // Pre-parse: split content into segments (markdown vs mermaid)
    final segments = _parseSegments(content);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      itemCount: segments.length,
      itemBuilder: (context, index) {
        final seg = segments[index];
        if (seg.isMermaid) {
          return _MermaidBlock(code: seg.content);
        }

        // Regular markdown – render with links disabled
        return MarkdownBody(
          data: seg.content,
          extensionSet: md.ExtensionSet.gitHubFlavored,
          builders: {
            'pre': _CodeElementBuilder(),
          },
          // ignore: missing_return
          onTapLink: (text, href, title) {
            // Links disabled — do nothing
          },
          styleSheet: MarkdownStyleSheet(
            p: GoogleFonts.outfit(color: U.text, fontSize: 15),
            h1: GoogleFonts.outfit(color: U.text, fontSize: 26, fontWeight: FontWeight.w700),
            h2: GoogleFonts.outfit(color: U.text, fontSize: 22, fontWeight: FontWeight.w700),
            h3: GoogleFonts.outfit(color: U.text, fontSize: 18, fontWeight: FontWeight.w600),
            listBullet: GoogleFonts.outfit(color: U.text, fontSize: 16),
            // Render links as plain text style (no underline, same color as body)
            a: GoogleFonts.outfit(color: U.text, fontSize: 15),
            strong: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w700),
            blockquote: GoogleFonts.outfit(color: U.sub, fontStyle: FontStyle.italic),
          ),
        );
      },
    );
  }

  /// Split raw markdown into alternating markdown / mermaid segments.
  List<_RolloutSegment> _parseSegments(String raw) {
    final segments = <_RolloutSegment>[];
    final lines = raw.split('\n');
    final buffer = StringBuffer();
    bool inMermaid = false;
    final mermaidBuffer = StringBuffer();

    for (final line in lines) {
      if (!inMermaid && line.trim() == '```mermaid') {
        // Flush any markdown before this
        if (buffer.isNotEmpty) {
          segments.add(_RolloutSegment(buffer.toString(), isMermaid: false));
          buffer.clear();
        }
        inMermaid = true;
        mermaidBuffer.clear();
        continue;
      }

      if (inMermaid) {
        if (line.trim() == '```') {
          segments.add(_RolloutSegment(mermaidBuffer.toString().trim(), isMermaid: true));
          mermaidBuffer.clear();
          inMermaid = false;
        } else {
          mermaidBuffer.writeln(line);
        }
        continue;
      }

      buffer.writeln(line);
    }

    // Flush remainder
    if (inMermaid && mermaidBuffer.isNotEmpty) {
      // Unclosed mermaid block – treat as code
      segments.add(_RolloutSegment(mermaidBuffer.toString().trim(), isMermaid: true));
    }
    if (buffer.isNotEmpty) {
      segments.add(_RolloutSegment(buffer.toString(), isMermaid: false));
    }

    return segments;
  }
}

class _RolloutSegment {
  final String content;
  final bool isMermaid;
  const _RolloutSegment(this.content, {required this.isMermaid});
}

class EmptyPlaceholderScreen extends StatelessWidget {
  const EmptyPlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w600),
        ),
        backgroundColor: U.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: U.primary),
      ),
      body: Center(
        child: Text(
          'Coming Soon',
          style: GoogleFonts.outfit(color: U.sub, fontSize: 16),
        ),
      ),
    );
  }
}

class _CodeElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // For normal code blocks (mermaid is handled outside the Markdown widget)
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: U.border),
      ),
      child: SelectableText(
        element.textContent,
        style: GoogleFonts.sourceCodePro(
          color: U.mdCode,
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }
}

class _MermaidBlock extends StatefulWidget {
  final String code;
  const _MermaidBlock({required this.code});

  @override
  State<_MermaidBlock> createState() => _MermaidBlockState();
}

class _MermaidBlockState extends State<_MermaidBlock> {
  WebViewController? _controller;
  double _height = 200;

  @override
  void initState() {
    super.initState();
    if (!PlatformSupport.supportsEmbeddedWebView) {
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (msg) {
          final h = double.tryParse(msg.message);
          if (h != null && mounted) {
            setState(() => _height = h + 24);
          }
        },
      )
      ..loadHtmlString(_buildHtml(widget.code));
  }

  String _buildHtml(String code) {
    final escaped = const HtmlEscape().convert(code);
    return '''
<!DOCTYPE html>
<html>
<head>
<link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600&display=swap" rel="stylesheet">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background: transparent;
    display: flex;
    justify-content: center;
    align-items: flex-start;
    padding: 12px;
    min-height: 100vh;
  }
  .mermaid {
    width: 100%;
    max-width: 100%;
  }
  .mermaid svg {
    max-width: 100%;
    height: auto;
    font-family: 'Outfit', sans-serif !important;
  }
</style>
<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
  mermaid.initialize({
    startOnLoad: true,
    theme: 'base',
    themeVariables: {
      primaryColor: '#282A36',
      primaryTextColor: '#F8F8F2',
      primaryBorderColor: '#6272A4',
      lineColor: '#6272A4',
      secondaryColor: '#1E1F29',
      tertiaryColor: '#1E1F29',
      background: 'transparent',
      mainBkg: '#282A36',
      nodeBorder: '#6272A4',
      clusterBkg: '#1E1F29',
      titleColor: '#F8F8F2',
      edgeLabelBackground: '#282A36',
      fontFamily: 'Outfit, sans-serif',
    }
  });
  window.addEventListener('load', () => {
    setTimeout(() => {
      const el = document.querySelector('.mermaid svg');
      if (el) {
        FlutterChannel.postMessage(el.getBoundingClientRect().height.toString());
      }
    }, 800);
  });
</script>
</head>
<body>
<div class="mermaid">
$escaped
</div>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: U.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: U.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mermaid preview is unavailable on this platform.',
              style: GoogleFonts.outfit(
                color: U.sub,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              widget.code,
              style: GoogleFonts.sourceCodePro(
                color: U.text,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      height: _height,
      decoration: BoxDecoration(
        color: U.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: U.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: WebViewWidget(controller: _controller!),
    );
  }
}
