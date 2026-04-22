import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class LiveMapScreen extends StatefulWidget {
  final List<dynamic> parkingSpaces;

  const LiveMapScreen({Key? key, required this.parkingSpaces}) : super(key: key);

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final MapController _mapController = MapController();
  Position? _userPosition;
  String? _locationError;
  bool _locating = true;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Location permission denied.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied.');
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _userPosition = pos;
        _locating = false;
      });
      _mapController.move(LatLng(pos.latitude, pos.longitude), 13);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.toString();
        _locating = false;
      });
    }
  }

  /// Parse lat/lng from a parking space map.
  /// Supports fields: latitude/longitude, lat/lng, or extracts from google_map_link.
  LatLng? _parseLatLng(Map<String, dynamic> space) {
    final lat = _toDouble(space['latitude'] ?? space['lat']);
    final lng = _toDouble(space['longitude'] ?? space['lng']);
    if (lat != null && lng != null) return LatLng(lat, lng);

    // Try extracting from google_map_link: ...@lat,lng,... or ?q=lat,lng
    final link = space['google_map_link']?.toString() ?? '';
    final atMatch = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(link);
    if (atMatch != null) {
      return LatLng(double.parse(atMatch.group(1)!), double.parse(atMatch.group(2)!));
    }
    final qMatch = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)').firstMatch(link);
    if (qMatch != null) {
      return LatLng(double.parse(qMatch.group(1)!), double.parse(qMatch.group(2)!));
    }
    return null;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Haversine distance in km
  double _distanceKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(a.latitude)) * cos(_rad(b.latitude)) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * asin(sqrt(h));
  }

  double _rad(double deg) => deg * pi / 180;

  String _formatDistance(double km) =>
      km < 1 ? '${(km * 1000).toStringAsFixed(0)} m' : '${km.toStringAsFixed(1)} km';

  void _showSpaceInfo(Map<String, dynamic> space, double? distKm) {
    final name = space['name']?.toString() ?? 'Parking Space';
    final location = space['location']?.toString() ?? space['address']?.toString() ?? '';
    final link = space['google_map_link']?.toString() ?? '';
    final slots = space['total_slots']?.toString() ?? '?';
    final isActive = space['is_active'] == true;

    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.local_parking, color: isActive ? Colors.green : Colors.grey, size: 28),
              const SizedBox(width: 8),
              Expanded(child: Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              if (!isActive)
                const Chip(label: Text('Inactive'), backgroundColor: Colors.grey),
            ]),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(location, style: const TextStyle(color: Colors.black54)),
            ],
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.layers, size: 16, color: Colors.blueGrey),
              const SizedBox(width: 4),
              Text('Total Slots: $slots'),
              if (distKm != null) ...[
                const SizedBox(width: 16),
                const Icon(Icons.directions_walk, size: 16, color: Colors.blueGrey),
                const SizedBox(width: 4),
                Text(_formatDistance(distKm)),
              ],
            ]),
            if (link.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.directions),
                  label: const Text('Get Directions'),
                  onPressed: () {
                    Navigator.pop(context);
                    launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userLatLng = _userPosition != null
        ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
        : null;

    final spacesWithCoords = <_SpaceWithCoord>[];
    for (final s in widget.parkingSpaces.whereType<Map<String, dynamic>>()) {
      final ll = _parseLatLng(s);
      if (ll != null) spacesWithCoords.add(_SpaceWithCoord(s, ll));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Parking Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Re-center',
            onPressed: () {
              if (userLatLng != null) {
                _mapController.move(userLatLng, 14);
              } else {
                _fetchLocation();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userLatLng ?? const LatLng(27.7172, 85.3240),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.parkai.app',
              ),
              MarkerLayer(
                markers: [
                  // User location marker
                  if (userLatLng != null)
                    Marker(
                      point: userLatLng,
                      width: 48,
                      height: 48,
                      child: const _PulsingUserMarker(),
                    ),
                  // Parking space markers
                  ...spacesWithCoords.map((e) {
                    final isActive = e.space['is_active'] == true;
                    final distKm = userLatLng != null ? _distanceKm(userLatLng, e.latlng) : null;
                    return Marker(
                      point: e.latlng,
                      width: 56,
                      height: 64,
                      child: GestureDetector(
                        onTap: () => _showSpaceInfo(e.space, distKm),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: isActive ? Colors.green : Colors.grey,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                distKm != null ? _formatDistance(distKm) : 'P',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Icon(Icons.local_parking, color: isActive ? Colors.green : Colors.grey, size: 28),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // Legend
          Positioned(
            bottom: 16,
            left: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LegendItem(color: Colors.blue, label: 'You'),
                    _LegendItem(color: Colors.green, label: 'Active Parking'),
                    _LegendItem(color: Colors.grey, label: 'Inactive Parking'),
                  ],
                ),
              ),
            ),
          ),

          // Loading / error overlay
          if (_locating)
            const Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Getting your location...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_locationError != null)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const Icon(Icons.location_off, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_locationError!, style: const TextStyle(color: Colors.red))),
                      TextButton(onPressed: _fetchLocation, child: const Text('Retry')),
                    ],
                  ),
                ),
              ),
            ),

          // No coords warning
          if (spacesWithCoords.isEmpty && widget.parkingSpaces.isNotEmpty)
            Positioned(
              top: _locationError != null ? 80 : 12,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.orange.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(child: Text('Parking spaces have no coordinates yet. Ask vendors to add lat/lng.')),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PulsingUserMarker extends StatefulWidget {
  const _PulsingUserMarker();

  @override
  State<_PulsingUserMarker> createState() => _PulsingUserMarkerState();
}

class _PulsingUserMarkerState extends State<_PulsingUserMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40 * _anim.value,
            height: 40 * _anim.value,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withOpacity(0.3 * (1 - _anim.value + 0.3)),
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue,
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _SpaceWithCoord {
  final Map<String, dynamic> space;
  final LatLng latlng;
  const _SpaceWithCoord(this.space, this.latlng);
}
