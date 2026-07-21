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
  final TransformationController _transformationController = TransformationController();
  double _currentScale = 1.0;
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    final previewUrl = DocsService.toPreviewUrl(widget.url);
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..enableZoom(true)
      ..setBackgroundColor(U.bg)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (_) {
          if (mounted) {
            setState(() => _isLoading = false);
            _webController.runJavaScript('''
              try {
                var meta = document.querySelector('meta[name="viewport"]');
                if (meta) {
                  meta.setAttribute('content', 'width=device-width, initial-scale=1.0, minimum-scale=0.5, maximum-scale=5.0, user-scalable=yes');
                } else {
                  var newMeta = document.createElement('meta');
                  newMeta.name = 'viewport';
                  newMeta.content = 'width=device-width, initial-scale=1.0, minimum-scale=0.5, maximum-scale=5.0, user-scalable=yes';
                  document.getElementsByTagName('head')[0].appendChild(newMeta);
                }
              } catch(e) {}
            ''');
          }
        },
        onWebResourceError: (_) {
          if (mounted) setState(() => _isLoading = false);
        },
      ))
      ..loadRequest(Uri.parse(previewUrl));
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final nextScale = (_currentScale + 0.25).clamp(1.0, 4.0);
    _animateToScale(nextScale);
  }

  void _zoomOut() {
    final nextScale = (_currentScale - 0.25).clamp(1.0, 4.0);
    _animateToScale(nextScale);
  }

  void _resetZoom() {
    _animateToScale(1.0);
  }

  void _animateToScale(double targetScale) {
    final size = MediaQuery.of(context).size;
    final double x = -(size.width * (targetScale - 1)) / 2;
    final double y = -(size.height * (targetScale - 1)) / 2;

    setState(() {
      _currentScale = targetScale;
      _transformationController.value = Matrix4.identity()
        ..translate(x, y)
        ..scale(targetScale);
    });
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
                child: Text(
                  'Open',
                  style: GoogleFonts.outfit(
                    color: (ThemeData.estimateBrightnessForColor(U.surface) == Brightness.light &&
                            ThemeData.estimateBrightnessForColor(U.primary) == Brightness.light)
                        ? const Color(0xFF0C7A65)
                        : U.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: U.surface,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
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
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1.0,
              maxScale: 4.0,
              panEnabled: _currentScale > 1.01,
              scaleEnabled: true,
              onInteractionEnd: (_) {
                if (mounted) {
                  final scale = _transformationController.value.getMaxScaleOnAxis();
                  setState(() {
                    _currentScale = scale;
                  });
                }
              },
              child: WebViewWidget(controller: _webController),
            ),
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
            // Floating zoom controls bar
            Positioned(
              right: 16,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: U.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: U.border.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove_rounded, color: U.text, size: 20),
                      onPressed: _currentScale > 1.0 ? _zoomOut : null,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                      tooltip: 'Zoom Out',
                    ),
                    GestureDetector(
                      onTap: _resetZoom,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${(_currentScale * 100).round()}%',
                          style: GoogleFonts.outfit(
                            color: U.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_rounded, color: U.text, size: 20),
                      onPressed: _currentScale < 4.0 ? _zoomIn : null,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                      tooltip: 'Zoom In',
                    ),
                    if (_currentScale > 1.01) ...[
                      Container(
                        height: 16,
                        width: 1,
                        color: U.border,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      IconButton(
                        icon: Icon(Icons.restart_alt_rounded, color: U.sub, size: 18),
                        onPressed: _resetZoom,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                        tooltip: 'Reset Zoom',
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(),
            ),
          ],
        ),
      ),
    );
  }
}

