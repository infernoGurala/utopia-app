import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';

import '../services/app_update_service.dart';
import '../main.dart';

class AppUpdatePrompt extends StatefulWidget {
  const AppUpdatePrompt({super.key, required this.info, required this.onSkip});

  final AppUpdateInfo info;
  final VoidCallback onSkip;

  @override
  State<AppUpdatePrompt> createState() => _AppUpdatePromptState();
}

class _AppUpdatePromptState extends State<AppUpdatePrompt> {
  bool _downloading = false;
  bool _installing = false;
  bool _installerOpened = false;
  String? _error;
  int _received = 0;
  int _total = 0;
  String _deviceAbi = 'loading...';
  String _apkSize = 'calculating...';

  @override
  void initState() {
    super.initState();
    _loadDeviceAbi();
    _loadApkSize();
  }

  Future<void> _loadApkSize() async {
    try {
      final dio = Dio();
      final response = await dio.head(
        widget.info.apkUrl,
        options: Options(followRedirects: true),
      );
      final contentLengthStr = response.headers.value('content-length');
      if (contentLengthStr != null) {
        final bytes = int.tryParse(contentLengthStr);
        if (bytes != null && mounted) {
          setState(() {
            _apkSize = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
          });
          return;
        }
      }
    } catch (e, s) {
      debugPrint('Update size check error: $e\n$s');
      if (mounted) {
        setState(() {
          _apkSize = 'unknown size';
        });
      }
    }
  }

  Future<void> _loadDeviceAbi() async {
    try {
      const channel = MethodChannel('utopia_app/app_update');
      final abi = await channel.invokeMethod<String>('getAbi');
      if (mounted && abi != null) {
        setState(() {
          _deviceAbi = abi;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _deviceAbi = 'unknown';
        });
      }
    }
  }

  double? get _progress {
    if (_total <= 0) {
      return null;
    }
    return _received / _total;
  }

  Future<void> _downloadAndInstall() async {
    if (_downloading || _installing) {
      return;
    }

    final canInstall = await AppUpdateService.canInstallDownloadedApk();
    if (!canInstall) {
      await AppUpdateService.openInstallPermissionSettings();
      if (!mounted) {
        return;
      }
      setState(() {
        _error =
            'Allow "Install unknown apps" for UTOPIA, then return and tap Update now.';
        _downloading = false;
        _installing = false;
        _installerOpened = false;
      });
      return;
    }

    setState(() {
      _downloading = true;
      _installing = false;
      _installerOpened = false;
      _error = null;
      _received = 0;
      _total = 0;
    });

    try {
      final filePath = await AppUpdateService.downloadApk(
        widget.info.apkUrl,
        onProgress: (received, total) {
          if (!mounted) {
            return;
          }
          setState(() {
            _received = received;
            _total = total;
            if (total > 0) {
              _apkSize = '${(total / (1024 * 1024)).toStringAsFixed(1)} MB';
            }
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _downloading = false;
        _installing = true;
      });

      final installResult = await AppUpdateService.installDownloadedApk(
        filePath,
      );
      if (!mounted) {
        return;
      }

      switch (installResult) {
        case 'launched':
          setState(() {
            _installing = false;
            _installerOpened = true;
            _error = null;
          });
          break;
        case 'permission_required':
          setState(() {
            _installing = false;
            _error =
                'Allow "Install unknown apps" for UTOPIA, then come back and tap Update now again.';
          });
          break;
        case 'file_missing':
          setState(() {
            _installing = false;
            _error = 'Downloaded APK could not be found.';
          });
          break;
        case 'no_installer':
          setState(() {
            _installing = false;
            _error =
                'No Android package installer was available on this device.';
          });
          break;
        default:
          setState(() {
            _installing = false;
            _error = 'Could not open the installer.';
          });
      }
    } catch (e, s) {
      debugPrint('Update download failed: $e\n$s');
      if (!mounted) {
        return;
      }
      setState(() {
        _downloading = false;
        _installing = false;
        _error = 'Download failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final force = widget.info.requiresImmediateUpdate;
    final size = MediaQuery.of(context).size;
    final shortHeight = size.height < 430;
    final cardPadding = shortHeight ? 18.0 : 24.0;
    final iconSize = shortHeight ? 44.0 : 52.0;
    final titleGap = shortHeight ? 12.0 : 18.0;
    final sectionGap = shortHeight ? 12.0 : 16.0;
    final actionGap = shortHeight ? 18.0 : 24.0;
    final buttonHeight = shortHeight ? 46.0 : 52.0;

    return Scaffold(
      backgroundColor: U.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                decoration: BoxDecoration(
                  color: U.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: U.border),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(cardPadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          color: U.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(
                            shortHeight ? 14 : 16,
                          ),
                        ),
                        child: Icon(
                          Icons.system_update_alt_rounded,
                          color: U.primary,
                          size: shortHeight ? 22 : 26,
                        ),
                      ),
                      SizedBox(height: titleGap),
                      Text(
                        widget.info.title,
                        style: GoogleFonts.outfit(
                          color: U.text,
                          fontSize: shortHeight ? 20 : 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.info.message,
                        style: GoogleFonts.outfit(
                          color: U.sub,
                          fontSize: shortHeight ? 13 : 14,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: sectionGap),
                      Text(
                        'Current: ${widget.info.currentVersion}  •  Latest: ${widget.info.latestVersion}  •  Arch: $_deviceAbi  •  Size: $_apkSize',
                        style: GoogleFonts.outfit(
                          color: U.teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      if (_downloading || _installing) ...[
                        SizedBox(height: shortHeight ? 14 : 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 7,
                            value: _progress,
                            backgroundColor: U.border.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              U.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _installing
                              ? 'Opening Android installer...'
                              : _progress == null
                              ? 'Downloading update...'
                              : 'Downloading update... ${(_progress! * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.outfit(
                            color: U.sub,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (_installerOpened) ...[
                        SizedBox(height: sectionGap),
                        Text(
                          'Installer opened. Complete the installation there. If nothing appeared, tap Update now again.',
                          style: GoogleFonts.outfit(
                            color: U.teal,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        SizedBox(height: sectionGap),
                        Text(
                          _error!,
                          style: GoogleFonts.outfit(
                            color: U.red,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                      SizedBox(height: actionGap),
                      Row(
                        children: [
                          if (!force)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _downloading || _installing
                                    ? null
                                    : widget.onSkip,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: U.sub,
                                  side: BorderSide(
                                    color: U.border,
                                  ),
                                  minimumSize: Size.fromHeight(buttonHeight),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'Later',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          if (!force) const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _downloading || _installing
                                  ? null
                                  : _downloadAndInstall,
                              style: FilledButton.styleFrom(
                                backgroundColor: U.primary,
                                foregroundColor: U.bg,
                                minimumSize: Size.fromHeight(buttonHeight),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                _downloading || _installing
                                    ? 'Please wait'
                                    : 'Update now',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (force) ...[
                        const SizedBox(height: 12),
                        Text(
                          'This update is required to continue using the app.',
                          style: GoogleFonts.outfit(
                            color: U.sub,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
