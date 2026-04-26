// ignore_for_file: avoid_print

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/location_service.dart';
import '../services/platform_support.dart';
import '../widgets/utopia_snackbar.dart';
import 'iaa_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String _sharingPreferenceKey = 'location_sharing_enabled';
  static const Duration _locationFreshness = Duration(minutes: 10);
  static const LatLng _campusCenter = LatLng(17.0890, 82.0693);
  static final LatLngBounds _campusBounds = LatLngBounds(
    southwest: LatLng(17.0854, 82.0656),
    northeast: LatLng(17.0922, 82.0729),
  );
  static const String _darkMapStyle =
      '[{"elementType":"geometry","stylers":[{"color":"#1e1e2e"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#cdd6f4"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#1e1e2e"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#313244"}]},{"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#45475a"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#181825"}]},{"featureType":"poi","elementType":"geometry","stylers":[{"color":"#27273a"}]},{"featureType":"landscape","elementType":"geometry","stylers":[{"color":"#1e1e2e"}]}]';

  final DatabaseReference _locationsRef = FirebaseDatabase.instanceFor(
    app: FirebaseDatabase.instance.app,
    databaseURL: LocationService.databaseUrl,
  ).ref('locations');
  final User? _user = FirebaseAuth.instance.currentUser;

  bool _isSharingLocation = false;
  bool _isGpsEnabled = false;
  bool _isAerialMode = true;
  bool _peopleExpanded = false;
  Set<Marker> _visibleMarkers = <Marker>{};
  List<_VisiblePerson> _visiblePeople = const [];
  Timer? _updateTimer;
  StreamSubscription<DatabaseEvent>? _locationsSubscription;
  SharedPreferences? _preferences;
  GoogleMapController? _mapController;
  int _markerBuildGeneration = 0;
  int _shareRequestId = 0;

  String get _uid => _user?.uid ?? '';
  String get _displayName => (_user?.displayName?.trim().isNotEmpty ?? false)
      ? _user!.displayName!.trim()
      : (_user?.email?.split('@').first ?? 'UTOPIA Student');

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      final shouldShare = _preferences?.getBool(_sharingPreferenceKey) ?? false;
      if (!mounted) {
        return;
      }

      await _loadLocationsOnce();
      _listenToLocations();
      _startRefreshTimer();

      if (shouldShare && _uid.isNotEmpty) {
        final requestId = ++_shareRequestId;
        setState(() => _isGpsEnabled = true);
        await _startSharing(
          requestId: requestId,
          savePreference: false,
          silent: true,
        );
      }
    } catch (e) {
      print('Map bootstrap error: $e');
    }
  }

  void _listenToLocations() {
    _locationsSubscription?.cancel();
    _locationsSubscription = _locationsRef.onValue.listen(
      (event) {
        try {
          final next = _extractLocations(event.snapshot.value);
          if (!mounted) {
            return;
          }
          unawaited(_rebuildMarkers(next));
        } catch (e) {
          print('Locations listener parse error: $e');
        }
      },
      onError: (error) {
        print('Locations listener error: $error');
      },
    );
  }

  Future<void> _loadLocationsOnce() async {
    try {
      final snapshot = await _locationsRef.get();
      final next = _extractLocations(snapshot.value);
      if (!mounted) {
        return;
      }
      await _rebuildMarkers(next);
    } catch (e) {
      print('Locations one-shot read error: $e');
    }
  }

  Map<String, dynamic> _extractLocations(dynamic raw) {
    final next = <String, dynamic>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        final uid = entry.key.toString();
        final value = entry.value;
        if (uid == _uid) {
          continue;
        }
        if (value is! Map) {
          continue;
        }
        next[uid] = Map<String, dynamic>.from(
          value.map((key, item) => MapEntry(key.toString(), item)),
        );
      }
    }
    return next;
  }

  void _startRefreshTimer() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final prefersSharing =
          _preferences?.getBool(_sharingPreferenceKey) ?? false;
      if (!prefersSharing || _uid.isEmpty) {
        return;
      }
      if (!_isSharingLocation && !_isGpsEnabled) {
        return;
      }

      try {
        await _startSharing(
          requestId: _shareRequestId,
          savePreference: false,
          silent: true,
        );
      } catch (e) {
        print('Timer location update error: $e');
      }
    });
  }

  Future<void> _setSharing(bool enabled) async {
    if (_uid.isEmpty) {
      return;
    }

    final requestId = ++_shareRequestId;
    if (mounted) {
      setState(() {
        _isGpsEnabled = enabled;
        if (!enabled) {
          _isSharingLocation = false;
        }
      });
    }

    if (enabled) {
      final permissionReady = await _ensureLocationPermission();
      if (requestId != _shareRequestId || !mounted) {
        return;
      }
      if (!permissionReady) {
        setState(() {
          _isGpsEnabled = false;
          _isSharingLocation = false;
        });
        return;
      }
      await _startSharing(
        requestId: requestId,
        savePreference: true,
        silent: false,
      );
      return;
    }

    await _stopSharing(requestId: requestId, savePreference: true);
  }

  Future<void> _startSharing({
    required int requestId,
    required bool savePreference,
    required bool silent,
  }) async {
    try {
      await LocationService.startSharingLocation(_uid, _displayName);
      if (requestId != _shareRequestId) {
        try {
          await LocationService.stopSharingLocation(_uid);
        } catch (undoError) {
          print('Undo stale sharing error: $undoError');
        }
        return;
      }
      if (savePreference) {
        await _preferences?.setBool(_sharingPreferenceKey, true);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isGpsEnabled = true;
        _isSharingLocation = true;
      });
      if (!silent) {
        showUtopiaSnackBar(
          context,
          message: 'Location sharing enabled',
          tone: UtopiaSnackBarTone.success,
        );
      }
    } catch (e) {
      print('Start sharing UI error: $e');
      if (requestId != _shareRequestId || !mounted) {
        return;
      }
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _isGpsEnabled = false;
        _isSharingLocation = false;
      });

      if (silent) {
        return;
      }

      if (message.contains('denied forever')) {
        await _showPermissionDialog(
          title: 'Location access blocked',
          message:
              'Open settings and allow location access to share your position on campus.',
          openSettings: true,
        );
      } else if (message.contains('permission denied')) {
        await _showPermissionDialog(
          title: 'Location permission needed',
          message:
              'Allow location permission so others can see you on the campus map.',
        );
      } else if (message.contains('services are disabled')) {
        await _showPermissionDialog(
          title: 'Turn on location services',
          message:
              'Enable location services on your device to use the campus map.',
          openLocationSettings: true,
        );
      } else {
        showUtopiaSnackBar(
          context,
          message: message.isEmpty
              ? 'Could not start location sharing'
              : message,
          tone: UtopiaSnackBarTone.error,
        );
      }
    }
  }

  Future<void> _stopSharing({
    required int requestId,
    required bool savePreference,
  }) async {
    final previousGpsEnabled = _isGpsEnabled;
    final previousSharing = _isSharingLocation;
    try {
      await LocationService.stopSharingLocation(_uid);
      if (requestId != _shareRequestId) {
        return;
      }
      if (savePreference) {
        await _preferences?.setBool(_sharingPreferenceKey, false);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isSharingLocation = false;
      });
    } catch (e) {
      print('Stop sharing UI error: $e');
      if (requestId != _shareRequestId || !mounted) {
        return;
      }
      setState(() {
        _isGpsEnabled = previousGpsEnabled;
        _isSharingLocation = previousSharing;
      });
      showUtopiaSnackBar(
        context,
        message: 'Could not stop location sharing',
        tone: UtopiaSnackBarTone.error,
      );
    }
  }

  Future<void> _showPermissionDialog({
    required String title,
    required String message,
    bool openSettings = false,
    bool openLocationSettings = false,
    String settingsLabel = 'Open settings',
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: U.card,
        title: Text(
          title,
          style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w700),
        ),
        content: Text(
          message,
          style: GoogleFonts.outfit(color: U.sub, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: GoogleFonts.outfit(color: U.sub)),
          ),
          if (openSettings)
            FilledButton.tonal(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openAppSettings();
              },
              child: Text(
                settingsLabel,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            ),
          if (openLocationSettings)
            FilledButton.tonal(
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
              },
              child: Text(
                'Turn on',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  void _openIAA() {
    Navigator.of(context).push(IAAScreen.route());
  }

  Future<bool> _ensureLocationPermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        await _showPermissionDialog(
          title: 'Location permission needed',
          message: 'Allow location access to use campus GPS sharing.',
        );
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        await _showPermissionDialog(
          title: 'Location access blocked',
          message:
              'Open app settings and allow location access to share your position on the map.',
          openSettings: true,
          settingsLabel: 'Open settings',
        );
        return false;
      }

      if (permission == LocationPermission.whileInUse) {
        if (mounted) {
          showUtopiaSnackBar(
            context,
            message:
                'GPS sharing works now. "Always allow" is optional for better background updates.',
            tone: UtopiaSnackBarTone.info,
          );
        }
      }

      return true;
    } catch (e) {
      print('Permission precheck error: $e');
      if (!mounted) {
        return false;
      }
      showUtopiaSnackBar(
        context,
        message: 'Could not verify location permission',
        tone: UtopiaSnackBarTone.error,
      );
      return false;
    }
  }

  Set<Marker> _markers() {
    return _visibleMarkers;
  }

  Future<void> _rebuildMarkers(Map<String, dynamic> locations) async {
    final generation = ++_markerBuildGeneration;
    final nextMarkers = <Marker>{};
    final nextPeople = <_VisiblePerson>[];

    for (final entry in locations.entries) {
      if (entry.value is! Map) {
        continue;
      }
      final data = Map<String, dynamic>.from(entry.value as Map);
      final sharing = data['sharing'] == true;
      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      final updatedAt = (data['updatedAt'] as num?)?.toInt();
      if (!sharing || lat == null || lng == null) {
        continue;
      }
      if (updatedAt == null) {
        continue;
      }
      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(updatedAt),
      );
      if (age > _locationFreshness) {
        continue;
      }

      final displayName = (data['displayName'] ?? 'UTOPIA Student').toString();
      nextPeople.add(
        _VisiblePerson(
          uid: entry.key,
          displayName: displayName,
          age: age,
          latLng: LatLng(lat, lng),
        ),
      );
      nextMarkers.add(
        Marker(
          markerId: MarkerId(entry.key),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(title: displayName, snippet: _ageLabel(age)),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            age.inMinutes <= 2
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }

    if (!mounted || generation != _markerBuildGeneration) {
      return;
    }
    nextPeople.sort((a, b) {
      final ageCompare = a.age.compareTo(b.age);
      if (ageCompare != 0) {
        return ageCompare;
      }
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    setState(() {
      _visibleMarkers = nextMarkers;
      _visiblePeople = nextPeople;
      if (nextPeople.isEmpty) {
        _peopleExpanded = false;
      }
    });
  }

  String _ageLabel(Duration age) {
    if (age.inMinutes <= 0) {
      return 'Updated just now';
    }
    if (age.inMinutes == 1) {
      return 'Updated 1 min ago';
    }
    return 'Updated ${age.inMinutes} mins ago';
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(_campusBounds, 24),
      );
    } catch (e) {
      print('Campus bounds camera error: $e');
      try {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            const CameraPosition(target: _campusCenter, zoom: 17.8),
          ),
        );
      } catch (inner) {
        print('Campus center camera error: $inner');
      }
    }
  }

  Future<void> _goToCampus() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(_campusBounds, 24),
      );
    } catch (e) {
      print('Go to campus bounds error: $e');
      try {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            const CameraPosition(target: _campusCenter, zoom: 17.8),
          ),
        );
      } catch (inner) {
        print('Go to campus center error: $inner');
      }
    }
  }

  Future<void> _goToMyLocation() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 17.8,
          ),
        ),
      );
    } catch (e) {
      print('Go to my location error: $e');
      if (!mounted) {
        return;
      }
      showUtopiaSnackBar(
        context,
        message: 'Could not get your current location',
        tone: UtopiaSnackBarTone.error,
      );
    }
  }

  Future<void> _focusPerson(_VisiblePerson person) async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: person.latLng, zoom: 18.2),
        ),
      );
    } catch (e) {
      print('Focus person error: $e');
    }
  }

  @override
  void dispose() {
    _markerBuildGeneration += 1;
    _mapController?.dispose();
    _updateTimer?.cancel();
    _locationsSubscription?.cancel();
    if (_uid.isNotEmpty) {
      unawaited(LocationService.stopSharingLocation(_uid));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformSupport.supportsCampusMap) {
      return Scaffold(
        backgroundColor: U.bg,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1E2E),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Campus Map',
            style: GoogleFonts.outfit(
              color: U.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: U.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: U.border),
                ),
                child: Text(
                  'Campus map depends on Google Maps and mobile location APIs that are not enabled for Windows in this app yet.',
                  style: GoogleFonts.outfit(
                    color: U.sub,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Campus Map',
          style: GoogleFonts.outfit(color: U.text, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: _openIAA,
            tooltip: 'IAA',
            icon: const Icon(Icons.auto_awesome, color: Color(0xFF7F77DD)),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: U.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _isGpsEnabled
                    ? U.primary.withValues(alpha: 0.45)
                    : U.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isGpsEnabled
                      ? Icons.location_on_rounded
                      : Icons.location_off_rounded,
                  color: _isGpsEnabled ? U.primary : U.sub,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'GPS',
                  style: GoogleFonts.outfit(
                    color: U.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _isGpsEnabled,
                  onChanged: _setSharing,
                  activeThumbColor: U.bg,
                  activeTrackColor: U.primary,
                  inactiveThumbColor: U.sub,
                  inactiveTrackColor: U.surface,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _campusCenter,
              zoom: 17.8,
            ),
            onMapCreated: _onMapCreated,
            myLocationEnabled: _isGpsEnabled,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: _isAerialMode ? MapType.hybrid : MapType.normal,
            markers: _markers(),
            style: _isAerialMode ? null : _darkMapStyle,
          ),
          if (_isAerialMode)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(color: U.bg.withValues(alpha: 0.12)),
              ),
            ),
          if (_isSharingLocation)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: U.green.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: U.green.withValues(alpha: 0.22),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    '📍 Sharing your location',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF0F0F17),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: _isSharingLocation ? 64 : 16,
            left: 16,
            child: _MapModeChip(
              isAerialMode: _isAerialMode,
              onToggle: () {
                setState(() => _isAerialMode = !_isAerialMode);
              },
            ),
          ),
          Positioned(
            top: _isSharingLocation ? 64 : 16,
            right: 16,
            child: _CampusChip(onTap: () => unawaited(_goToCampus())),
          ),
          Positioned(
            right: 16,
            bottom: _peopleExpanded ? 244 : 112,
            child: _MapActionButton(
              icon: Icons.my_location_rounded,
              tooltip: 'My location',
              onTap: () => unawaited(_goToMyLocation()),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: _PeoplePanel(
              people: _visiblePeople,
              expanded: _peopleExpanded,
              onToggleExpanded: () {
                if (_visiblePeople.isEmpty) {
                  return;
                }
                setState(() => _peopleExpanded = !_peopleExpanded);
              },
              onSelectPerson: (person) {
                setState(() => _peopleExpanded = false);
                unawaited(_focusPerson(person));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MapModeChip extends StatelessWidget {
  const _MapModeChip({required this.isAerialMode, required this.onToggle});

  final bool isAerialMode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: U.card.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: U.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAerialMode
                    ? Icons.layers_rounded
                    : Icons.satellite_alt_rounded,
                color: U.primary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                isAerialMode ? 'Blocks' : 'Aerial',
                style: GoogleFonts.outfit(
                  color: U.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampusChip extends StatelessWidget {
  const _CampusChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: U.card.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: U.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.school_rounded, color: U.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                'Go to campus',
                style: GoogleFonts.outfit(
                  color: U.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: U.card.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: U.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: U.primary, size: 20),
          ),
        ),
      ),
    );
  }
}

class _VisiblePerson {
  const _VisiblePerson({
    required this.uid,
    required this.displayName,
    required this.age,
    required this.latLng,
  });

  final String uid;
  final String displayName;
  final Duration age;
  final LatLng latLng;
}

class _PeoplePanel extends StatelessWidget {
  const _PeoplePanel({
    required this.people,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onSelectPerson,
  });

  final List<_VisiblePerson> people;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<_VisiblePerson> onSelectPerson;

  String _ageLabel(Duration age) {
    if (age.inMinutes <= 0) {
      return 'just now';
    }
    if (age.inMinutes == 1) {
      return '1 min ago';
    }
    return '${age.inMinutes} mins ago';
  }

  @override
  Widget build(BuildContext context) {
    final hasPeople = people.isNotEmpty;
    final visibleRows = expanded ? people : people.take(2).toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF11111B).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: U.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: U.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.people_alt_outlined,
                  color: U.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasPeople
                          ? '${people.length} student${people.length == 1 ? '' : 's'} visible'
                          : 'No one visible right now',
                      style: GoogleFonts.outfit(
                        color: U.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      hasPeople
                          ? 'Tap a person to focus them on the map'
                          : 'Waiting for someone nearby to share location',
                      style: GoogleFonts.outfit(
                        color: U.sub,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasPeople)
                IconButton(
                  onPressed: onToggleExpanded,
                  splashRadius: 18,
                  icon: Icon(
                    expanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    color: U.sub,
                  ),
                ),
            ],
          ),
          if (hasPeople) ...[
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: expanded ? 204 : 104),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: visibleRows.length,
                separatorBuilder: (context, index) =>
                    Divider(color: U.border.withValues(alpha: 0.7), height: 12),
                itemBuilder: (context, index) {
                  final person = visibleRows[index];
                  final initials = person.displayName.trim().isEmpty
                      ? 'U'
                      : person.displayName.trim()[0].toUpperCase();
                  return InkWell(
                    onTap: () => onSelectPerson(person),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: U.primary.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  initials,
                                  style: GoogleFonts.outfit(
                                    color: U.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: person.age.inMinutes <= 2
                                        ? U.green
                                        : const Color(0xFF89B4FA),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF11111B),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  person.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    color: U.text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Updated ${_ageLabel(person.age)}',
                                  style: GoogleFonts.outfit(
                                    color: U.sub,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.my_location_rounded,
                            color: U.sub,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (!expanded && people.length > 2)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+${people.length - 2} more nearby',
                  style: GoogleFonts.outfit(
                    color: U.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
