import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../main.dart';
import '../services/docs_service.dart';

class DocViewerScreen extends StatefulWidget {
  final String title;
  final String url;

  const DocViewerScreen({super.key, required this.title, required this.url});

  @override
  State<DocViewerScreen> createState() => _DocViewerScreenState();
}

class _DocViewerScreenState extends State<DocViewerScreen> {
  late final WebViewController _webController;
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    final previewUrl = DocsService.toPreviewUrl(widget.url);
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(U.bg)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (_) => setState(() => _isLoading = false),
        onWebResourceError: (_) => setState(() => _isLoading = false),
      ))
      ..loadRequest(Uri.parse(previewUrl));
  }

  Future<void> _downloadDoc() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    try {
      final downloadUrl = DocsService.toDownloadUrl(widget.url);
      final dir = await getApplicationDocumentsDirectory();
      final safeTitle = widget.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final filePath = '${dir.path}/$safeTitle.pdf';

      await Dio().download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: U.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: U.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Saved offline successfully!',
                  style: GoogleFonts.outfit(color: U.text, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => OpenFilex.open(filePath),
                child: Text('Open', style: GoogleFonts.outfit(color: U.primary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: U.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: [
              Icon(Icons.error_outline_rounded, color: U.red, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Download failed. Try again.',
                  style: GoogleFonts.outfit(color: U.text, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            Theme.of(context).brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: U.bg,
        appBar: AppBar(
          backgroundColor: U.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 20),
          ),
          title: Text(
            widget.title,
            style: GoogleFonts.outfit(
              color: U.text,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (_isDownloading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    value: _downloadProgress > 0 ? _downloadProgress : null,
                    strokeWidth: 2.5,
                    color: U.primary,
                  ),
                ),
              ).animate().fadeIn()
            else if (DocsService.isGoogleDriveUrl(widget.url))
              IconButton(
                onPressed: _downloadDoc,
                tooltip: 'Save offline',
                icon: Icon(Icons.download_rounded, color: U.primary, size: 22),
              ).animate().fadeIn(),
          ],
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _webController),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: U.bg,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: U.primary, strokeWidth: 2.5),
                        const SizedBox(height: 16),
                        Text(
                          'Loading document…',
                          style: GoogleFonts.outfit(color: U.sub, fontSize: 14),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
