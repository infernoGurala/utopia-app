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

