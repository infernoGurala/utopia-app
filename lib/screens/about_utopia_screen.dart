import 'dart:convert';
import 'package:flutter/material.dart';
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
          ),
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
          ),
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
          'https://raw.githubusercontent.com/theutopiadomain/utopia-global/main/Utopiarollout.md'));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _markdownContent = response.body;
            _isLoading = false;
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
                  child: Text(
                    _error!,
                    style: GoogleFonts.outfit(color: U.red, fontSize: 16),
                  ),
                )
              : Markdown(
                  data: _markdownContent ?? '',
                  builders: {
                    'pre': _CodeElementBuilder(),
                  },
                  styleSheet: MarkdownStyleSheet(
                    p: GoogleFonts.outfit(color: U.text, fontSize: 15),
                    h1: GoogleFonts.outfit(color: U.text, fontSize: 26, fontWeight: FontWeight.w700),
                    h2: GoogleFonts.outfit(color: U.text, fontSize: 22, fontWeight: FontWeight.w700),
                    h3: GoogleFonts.outfit(color: U.text, fontSize: 18, fontWeight: FontWeight.w600),
                    listBullet: GoogleFonts.outfit(color: U.text, fontSize: 16),
                    a: GoogleFonts.outfit(color: U.primary, fontSize: 15, fontWeight: FontWeight.w500),
                    strong: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w700),
                    blockquote: GoogleFonts.outfit(color: U.sub, fontStyle: FontStyle.italic),
                  ),
                ),
    );
  }
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
    final codeElement = element.children != null && element.children!.isNotEmpty
        ? element.children!.first
        : null;
    final languageClass = codeElement is md.Element
        ? codeElement.attributes['class']
        : null;
    final language = languageClass != null && languageClass.startsWith('language-')
        ? languageClass.substring('language-'.length)
        : null;

    if (language == 'mermaid') {
      return _MermaidBlock(code: element.textContent);
    }
    
    // For normal code blocks
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
    final bgHex = U.mermaidBackground.replaceAll('#', '');
    final primaryHex = U.mermaidPrimary.replaceAll('#', '');
    final lineHex = U.mermaidLine.replaceAll('#', '');
    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background: #${bgHex};
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
  }
</style>
<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
  mermaid.initialize({
    startOnLoad: true,
    theme: 'dark',
    themeVariables: {
      primaryColor: '#${primaryHex}',
      primaryTextColor: '#CDD6F4',
      primaryBorderColor: '#45475A',
      lineColor: '#${lineHex}',
      secondaryColor: '#${bgHex}',
      tertiaryColor: '#${bgHex}',
      background: '#${bgHex}',
      mainBkg: '#${primaryHex}',
      nodeBorder: '#${lineHex}',
      clusterBkg: '#${bgHex}',
      titleColor: '#CDD6F4',
      edgeLabelBackground: '#${bgHex}',
      fontFamily: 'sans-serif',
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


