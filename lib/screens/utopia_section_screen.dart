import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../main.dart';
import '../services/role_service.dart';
import 'developer_panel_screen.dart';

class CreatorApp {
  final String name;
  final String packageName;
  final String githubRepo;
  final IconData icon;
  final Color color;
  final String sub;
  
  bool isInstalled = false;
  String? installedVersion;
  String? latestVersion;
  bool isDownloading = false;
  double downloadProgress = 0.0;
  String? downloadUrl;
  
  CreatorApp({
    required this.name,
    required this.packageName,
    required this.githubRepo,
    required this.icon,
    required this.color,
    required this.sub,
  });
}

class UtopiaSectionScreen extends StatefulWidget {
  final bool initialIsSuperUser;

  const UtopiaSectionScreen({
    super.key,
    required this.initialIsSuperUser,
  });

  @override
  State<UtopiaSectionScreen> createState() => _UtopiaSectionScreenState();
}

class _UtopiaSectionScreenState extends State<UtopiaSectionScreen> with WidgetsBindingObserver {
  bool _isSuperUser = false;
  final _channel = const MethodChannel('utopia_app/app_update');
  
  final List<CreatorApp> _creatorApps = [
    CreatorApp(
      name: 'DELVE',
      packageName: 'com.delve.app',
      githubRepo: 'infernoGurala/Delve-app',
      icon: Icons.explore_outlined,
      color: Colors.deepPurpleAccent,
      sub: 'A clean and fast student companion app.',
    ),
    CreatorApp(
      name: 'Interceptor',
      packageName: 'com.interceptor.interceptor',
      githubRepo: 'infernoGurala/Interceptor-app',
      icon: Icons.hourglass_empty_outlined,
      color: Colors.tealAccent,
      sub: 'A personal doom-scrolling replacement app.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isSuperUser = widget.initialIsSuperUser;
    RoleService().isSuperUser().then((v) {
      if (mounted) {
        setState(() => _isSuperUser = v);
      }
    });
    _refreshApps();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshApps();
    }
  }

  void _refreshApps() {
    for (final app in _creatorApps) {
      _checkAppState(app);
    }
  }

  bool _isUpdateAvailable(CreatorApp app) {
    if (!app.isInstalled || app.latestVersion == null || app.installedVersion == null) {
      return false;
    }
    final cleanLatest = app.latestVersion!.replaceAll(RegExp(r'[vV\s]'), '');
    final cleanInstalled = app.installedVersion!.replaceAll(RegExp(r'[vV\s]'), '');
    return cleanLatest != cleanInstalled;
  }

  Future<void> _checkAppState(CreatorApp app) async {
    try {
      final isInstalled = await _channel.invokeMethod<bool>('isAppInstalled', {'packageName': app.packageName}) ?? false;
      String? installedVersion;
      if (isInstalled) {
        installedVersion = await _channel.invokeMethod<String>('getAppVersion', {'packageName': app.packageName});
      }
      
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/${app.githubRepo}/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      
      String? latestVersion;
      String? downloadUrl;
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        latestVersion = data['tag_name'] as String?;
        
        final String abi = await _channel.invokeMethod<String>('getAbi') ?? '';
        final assets = data['assets'] as List<dynamic>? ?? [];
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (abi.isNotEmpty && name.contains(abi)) {
            downloadUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
        if (downloadUrl == null) {
          for (final asset in assets) {
            final name = asset['name'] as String? ?? '';
            if (name.endsWith('.apk') && name.contains('release')) {
              downloadUrl = asset['browser_download_url'] as String?;
              break;
            }
          }
        }
      }
      
      if (mounted) {
        setState(() {
          app.isInstalled = isInstalled;
          app.installedVersion = installedVersion;
          app.latestVersion = latestVersion;
          app.downloadUrl = downloadUrl;
        });
      }
    } catch (_) {}
  }

  Future<void> _downloadAndInstall(CreatorApp app) async {
    if (app.downloadUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No release URL found for your device ABI.')),
      );
      return;
    }
    
    if (mounted) {
      setState(() {
        app.isDownloading = true;
        app.downloadProgress = 0.0;
      });
    }
    
    try {
      final tempDir = await getTemporaryDirectory();
      final apkName = '${app.name.toLowerCase()}_release.apk';
      final apkPath = '${tempDir.path}/$apkName';
      
      final dio = Dio();
      await dio.download(
        app.downloadUrl!,
        apkPath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              app.downloadProgress = (received / total).clamp(0.0, 1.0);
            });
          }
        },
      );
      
      if (mounted) {
        setState(() {
          app.isDownloading = false;
          app.downloadProgress = 1.0;
        });
      }
      
      final result = await _channel.invokeMethod<String>('installApk', {'filePath': apkPath});
      if (result == 'permission_required') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable Unknown Source installation permission to install the app.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          app.isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download APK: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchBugReport() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'johnmosesg150@gmail.com',
      query: 'subject=UTOPIA Bug Report / Suggestion',
    );
    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      }
    } catch (_) {}
  }

  Widget _groupedTile({
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: U.dim, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        elevation: 0,
        title: Text(
          'UTOPIA',
          style: GoogleFonts.outfit(
            color: U.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        foregroundColor: U.text,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // Premium Logo Section
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: Image.asset(
                        'assets/icon_cropped.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'UTOPIA',
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'App Version 1.0.0',
                    style: GoogleFonts.outfit(
                      color: U.sub,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),

            // Settings Group
            Container(
              decoration: BoxDecoration(
                color: U.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: U.border),
              ),
              child: Column(
                children: [
                  // Report Bugs & Suggestions
                  _groupedTile(
                    icon: Icons.bug_report_outlined,
                    label: 'Report Bugs & Suggestions',
                    sub: 'Help us improve UTOPIA',
                    color: U.teal,
                    onTap: _launchBugReport,
                  ),

                  if (_isSuperUser) ...[
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      color: U.border.withValues(alpha: 0.5),
                    ),
                    // Super Controls
                    _groupedTile(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Super Controls',
                      sub: 'Analytics, broadcasts, and app-wide settings',
                      color: U.primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DeveloperPanelScreen(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'MORE APPS BY THE CREATOR',
              style: GoogleFonts.outfit(
                color: U.sub,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: U.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: U.border),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _creatorApps.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 0.5,
                  color: U.border.withValues(alpha: 0.5),
                ),
                itemBuilder: (context, index) {
                  final app = _creatorApps[index];
                  final bool hasUpdate = _isUpdateAvailable(app);
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        // App Icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: app.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(app.icon, color: app.color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        // App Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    app.name,
                                    style: GoogleFonts.outfit(
                                      color: U.text,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (app.isInstalled) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: U.teal.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Installed',
                                        style: GoogleFonts.outfit(
                                          color: U.teal,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                app.sub,
                                style: GoogleFonts.outfit(
                                  color: U.sub,
                                  fontSize: 12,
                                ),
                              ),
                              if (app.isInstalled && app.installedVersion != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Version ${app.installedVersion}',
                                  style: GoogleFonts.outfit(
                                    color: U.dim,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Download/Open/Update CTA button
                        SizedBox(
                          width: 90,
                          height: 36,
                          child: app.isDownloading
                              ? Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        value: app.downloadProgress,
                                        strokeWidth: 3,
                                        valueColor: AlwaysStoppedAnimation<Color>(app.color),
                                        backgroundColor: app.color.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    Text(
                                      '${(app.downloadProgress * 100).toInt()}%',
                                      style: GoogleFonts.outfit(
                                        color: U.text,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : ElevatedButton(
                                  onPressed: () {
                                    if (app.isInstalled) {
                                      if (hasUpdate) {
                                        _downloadAndInstall(app);
                                      } else {
                                        _channel.invokeMethod('launchApp', {'packageName': app.packageName});
                                      }
                                    } else {
                                      _downloadAndInstall(app);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    backgroundColor: hasUpdate
                                        ? Colors.orange.withValues(alpha: 0.15)
                                        : (app.isInstalled
                                            ? U.primary.withValues(alpha: 0.12)
                                            : app.color),
                                    foregroundColor: hasUpdate
                                        ? Colors.orange
                                        : (app.isInstalled ? U.primary : Colors.black),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: hasUpdate
                                            ? Colors.orange.withValues(alpha: 0.3)
                                            : (app.isInstalled
                                                ? U.primary.withValues(alpha: 0.25)
                                                : Colors.transparent),
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    hasUpdate
                                        ? 'Update'
                                        : (app.isInstalled ? 'Open' : 'Get'),
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
