import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/parking_slot.dart';
import '../services/api_service.dart';
import '../services/parking_service.dart';
import '../utils/responsive_utils.dart';
import 'live_map_screen.dart';
import 'payment.dart';

class ParkingListScreen extends StatefulWidget {
  const ParkingListScreen({super.key});

  @override
  State<ParkingListScreen> createState() => _ParkingListScreenState();
}

class _ParkingListScreenState extends State<ParkingListScreen> {
  List<dynamic> spaces = [];
  List<dynamic> _filteredSpaces = [];
  List<String> _uniqueLocations = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _loadParkingSpaces();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParkingSpaces() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final loadedSpaces = await ParkingService.getParkingSpaces();
      if (!mounted) return;

      final uniqueLocs = loadedSpaces
          .map((s) => s['location']?.toString() ?? '')
          .where((l) => l.isNotEmpty)
          .toSet()
          .toList();

      setState(() {
        spaces = loadedSpaces;
        _uniqueLocations = uniqueLocs;
        _filteredSpaces = loadedSpaces;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showSlotsForSpace(Map<String, dynamic> space) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.82,
          child: _SpaceSlotsBottomSheet(space: space),
        );
      },
    );
  }

  void _showLocationDialog(Map<String, dynamic> space) {
    final location = space['location'] ?? space['address'] ?? 'No location available';
    final googleMapLink = (space['google_map_link'] ?? '').toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(space['name']?.toString() ?? 'Parking Space'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Location: $location'),
            const SizedBox(height: 16),
            if (googleMapLink.isNotEmpty)
              ElevatedButton.icon(
                icon: const Icon(Icons.map),
                label: const Text('View Location'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  launchUrl(
                    Uri.parse(googleMapLink),
                    mode: LaunchMode.externalApplication,
                  );
                },
              )
            else
              const Text('No map link available'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _filterSpaces(String query) {
    setState(() {
      var filtered = spaces;
      if (query.isNotEmpty) {
        filtered = filtered.where((space) {
          final name = space['name']?.toString().toLowerCase() ?? '';
          final location = space['location']?.toString().toLowerCase() ?? '';
          return name.contains(query.toLowerCase()) || location.contains(query.toLowerCase());
        }).toList();
      }
      if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
        filtered = filtered.where((space) => space['location']?.toString() == _selectedLocation).toList();
      }
      _filteredSpaces = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Parking Spaces'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.map),
              label: const Text('Live Map'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: spaces.isEmpty
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LiveMapScreen(parkingSpaces: spaces)),
                      ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadParkingSpaces, child: const Text('Retry')),
                    ],
                  ),
                )
              : spaces.isEmpty
                  ? const Center(child: Text('No parking spaces uploaded by vendors yet.'))
                  : Padding(
                      padding: EdgeInsets.all(
                        ResponsiveUtils.responsivePadding(context, mobile: 10, tablet: 12, desktop: 16),
                      ),
                      child: Column(
                        children: [
                          if (_uniqueLocations.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: DropdownButton<String?>(
                                      value: _selectedLocation,
                                      hint: const Text('Filter by Location'),
                                      isExpanded: true,
                                      items: [
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text('All Locations'),
                                        ),
                                        ..._uniqueLocations.map((loc) => DropdownMenuItem<String?>(
                                              value: loc,
                                              child: Text(loc),
                                            )),
                                      ],
                                      onChanged: (val) {
                                        setState(() => _selectedLocation = val);
                                        _filterSpaces(_searchController.text);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search parking spaces...',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: _filterSpaces,
                            ),
                          ),
                          Expanded(
                            child: ListView.separated(
                              itemCount: _filteredSpaces.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final space = _filteredSpaces[i] as Map<String, dynamic>;
                                final isActive = space['is_active'] == true;

                                return Card(
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.local_parking,
                                      color: isActive ? Colors.green : Colors.grey,
                                      size: isMobile ? 28 : 34,
                                    ),
                                    title: GestureDetector(
                                      onTap: () => _showLocationDialog(space),
                                      child: Text(
                                        space['name']?.toString() ?? 'Unnamed Space',
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${space['location'] ?? space['address'] ?? 'No location'}\nSlots: ${space['total_slots'] ?? 0}',
                                    ),
                                    isThreeLine: true,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if ((space['google_map_link'] ?? '').toString().isNotEmpty)
                                          IconButton(
                                            icon: const Icon(Icons.map, color: Colors.blue),
                                            tooltip: 'Open in Google Maps',
                                            onPressed: () => launchUrl(
                                              Uri.parse(space['google_map_link'].toString()),
                                              mode: LaunchMode.externalApplication,
                                            ),
                                          ),
                                        ElevatedButton(
                                          onPressed: isActive ? () => _showSlotsForSpace(space) : null,
                                          child: Text(isActive ? 'View Slots' : 'Inactive'),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _SpaceSlotsBottomSheet extends StatefulWidget {
  final Map<String, dynamic> space;

  const _SpaceSlotsBottomSheet({required this.space});

  @override
  State<_SpaceSlotsBottomSheet> createState() => _SpaceSlotsBottomSheetState();
}

class _SpaceSlotsBottomSheetState extends State<_SpaceSlotsBottomSheet> {
  late final int _spaceId;
  List<ParkingSlot> _slots = [];
  bool _loading = true;
  String? _error;
  bool _socketConnected = false;
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    _spaceId = widget.space['id'] as int;
    _loadSlots();
    _connectSocket();
  }

  String _buildWsUrl(int spaceId) {
    final base = ApiService.baseUrl.replaceFirst('/api', '');
    final secure = base.startsWith('https://');
    final host = base.replaceFirst('https://', '').replaceFirst('http://', '');
    final scheme = secure ? 'wss' : 'ws';
    return '$scheme://$host/ws/spaces/$spaceId/slots/';
  }

  Future<void> _loadSlots({bool silent = false}) async {
    try {
      if (!silent) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }

      final slotRows = await ParkingService.getSlots(_spaceId);
      final slots = slotRows
          .map((row) => ParkingSlot.fromJson(row as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _slots = slots;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _connectSocket() {
    final wsUrl = _buildWsUrl(_spaceId);
    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _channel = channel;

    channel.stream.listen(
      (event) {
        if (!mounted) return;

        setState(() => _socketConnected = true);

        try {
          final data = jsonDecode(event.toString());
          if (data is Map<String, dynamic> && data['type'] == 'slot_update') {
            _loadSlots(silent: true);
          }
        } catch (_) {
          // ignore non-json heartbeat/connection messages
        }
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _socketConnected = false);
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _socketConnected = false);
      },
      cancelOnError: false,
    );
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _reserveSlot(ParkingSlot slot) async {
    // Show vehicle information dialog
    final vehicleInfo = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _VehicleInfoDialog(),
    );

    if (vehicleInfo == null) return; // User cancelled

    final result = await ParkingService.reserveSlot(
      spaceId: _spaceId, 
      slotId: slot.id,
      vehicleNumber: vehicleInfo['number'] as String,
      vehicleType: vehicleInfo['type'] as String,
      expectedCheckinTime: vehicleInfo['expected_checkin_time'] as String?,
      estimatedDurationMins: vehicleInfo['estimated_duration_mins'] as int?,
    );
    
    if (!mounted) return;

    if (result['success'] == true) {
      final reservation = result['reservation'] as Map<String, dynamic>;
      final expectedCheckInValue =
          vehicleInfo['expected_checkin_time'] as String?;
      final estimatedDurationValue =
          vehicleInfo['estimated_duration_mins'] as int?;
      Navigator.pop(context);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            slotName: slot.label,
            slotId: slot.slotId,
            reservationId: reservation['id'] as int,
            amount: double.parse((reservation['booking_fee'] ?? reservation['amount'] ?? 0).toString()),
            expectedCheckInTime: expectedCheckInValue != null
                ? DateTime.tryParse(expectedCheckInValue)
                : null,
            estimatedDurationMins: estimatedDurationValue,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error']?.toString() ?? 'Failed to reserve slot'),
          backgroundColor: Colors.red,
        ),
      );
      _loadSlots(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Failed to load slots: $_error'),
        ),
      );
    }

    return Column(
      children: [
        ListTile(
          title: Text(widget.space['name']?.toString() ?? 'Parking Space'),
          subtitle: Text(widget.space['location']?.toString() ?? widget.space['address']?.toString() ?? ''),
          onTap: (widget.space['google_map_link'] ?? '').toString().isNotEmpty
              ? () => launchUrl(
                    Uri.parse(widget.space['google_map_link'].toString()),
                    mode: LaunchMode.externalApplication,
                  )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 10, color: _socketConnected ? Colors.green : Colors.orange),
              const SizedBox(width: 6),
              Text(_socketConnected ? 'Realtime' : 'Connecting'),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
        const Divider(height: 1),
        _SlotSummaryBar(slots: _slots),
        const Divider(height: 1),
        Expanded(
          child: _slots.isEmpty
              ? const Center(child: Text('No slots available in this space.'))
              : RefreshIndicator(
                  onRefresh: () => _loadSlots(),
                  child: ListView.builder(
                    itemCount: _slots.length,
                    itemBuilder: (context, i) {
                      final slot = _slots[i];
                      final isBlocked = slot.isOccupied || slot.isReserved;
                      final canReserve = slot.isActive && !isBlocked;

                      Color color;
                      if (!slot.isActive) {
                        color = Colors.grey;
                      } else if (slot.isOccupied) {
                        color = Colors.red;
                      } else if (slot.isReserved) {
                        color = Colors.orange;
                      } else {
                        color = Colors.green;
                      }

                      String label;
                      if (!slot.isActive) {
                        label = 'Inactive';
                      } else if (slot.isOccupied) {
                        label = 'Occupied';
                      } else if (slot.isReserved) {
                        label = 'Reserved';
                      } else {
                        label = 'Reserve';
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: Icon(Icons.local_parking, color: color),
                          title: Text(slot.label),
                          subtitle: Text('ID: ${slot.slotId}'),
                          trailing: ElevatedButton(
                            onPressed: canReserve ? () => _reserveSlot(slot) : null,
                            child: Text(label),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _SlotSummaryBar extends StatelessWidget {
  final List<ParkingSlot> slots;
  const _SlotSummaryBar({required this.slots});

  @override
  Widget build(BuildContext context) {
    final total = slots.length;
    final vacant = slots.where((s) => s.isActive && !s.isOccupied && !s.isReserved).length;
    final occupied = slots.where((s) => s.isOccupied).length;
    final reserved = slots.where((s) => s.isReserved && !s.isOccupied).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryChip(label: 'Total', value: total, color: Colors.blueGrey),
          _SummaryChip(label: 'Vacant', value: vacant, color: Colors.green),
          _SummaryChip(label: 'Occupied', value: occupied, color: Colors.red),
          _SummaryChip(label: 'Reserved', value: reserved, color: Colors.orange),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _SummaryChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 1),
          ),
          child: Text(
            '$value',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }
}

class _VehicleInfoDialog extends StatefulWidget {
  const _VehicleInfoDialog();

  @override
  State<_VehicleInfoDialog> createState() => _VehicleInfoDialogState();
}

class _VehicleInfoDialogState extends State<_VehicleInfoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _vehicleNumberController = TextEditingController();
  String? _selectedVehicleType;
  DateTime? _expectedCheckInTime;
  int? _estimatedDurationMins;

  final List<String> _vehicleTypes = ['SUV', 'Pickup', 'Sedan', 'Hatchback'];
  final List<int> _durationOptions = [30, 60, 90, 120, 180, 240, 360, 480, 720, 1440]; // minutes

  String _formatDuration(int mins) {
    if (mins < 60) return '$mins mins';
    final hours = mins ~/ 60;
    final remainingMins = mins % 60;
    if (remainingMins == 0) return '$hours hour${hours > 1 ? 's' : ''}';
    return '$hours hr ${remainingMins} mins';
  }

  Future<void> _selectCheckInTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _expectedCheckInTime ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    
    if (date == null || !mounted) return;
    
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expectedCheckInTime ?? now),
    );
    
    if (time == null || !mounted) return;
    
    setState(() {
      _expectedCheckInTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Vehicle & Booking Information'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle Number
              TextFormField(
                controller: _vehicleNumberController,
                decoration: const InputDecoration(
                  labelText: 'Vehicle Number',
                  hintText: 'e.g., ABC-1234',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vehicle number is required';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              
              // Vehicle Type
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Vehicle Type',
                  border: OutlineInputBorder(),
                ),
                items: _vehicleTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type.toLowerCase(),
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedVehicleType = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a vehicle type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              
              // Expected Check-in Time Section
              const Text(
                'Booking Preferences (Optional)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              
              // Expected Check-in Time
              InkWell(
                onTap: _selectCheckInTime,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expected Check-in Time',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time),
                  ),
                  child: Text(
                    _expectedCheckInTime != null
                        ? '${_expectedCheckInTime!.day}/${_expectedCheckInTime!.month}/${_expectedCheckInTime!.year} ${_expectedCheckInTime!.hour.toString().padLeft(2, '0')}:${_expectedCheckInTime!.minute.toString().padLeft(2, '0')}'
                        : 'Tap to select time',
                    style: TextStyle(
                      color: _expectedCheckInTime != null ? null : Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Estimated Duration - Slider
              const Text(
                'Estimated Parking Duration',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: (_estimatedDurationMins ?? 60).toDouble(),
                      min: 15,
                      max: 720,
                      divisions: 47,
                      label: _formatDuration(_estimatedDurationMins ?? 60),
                      onChanged: (value) {
                        setState(() {
                          _estimatedDurationMins = value.round();
                        });
                      },
                    ),
                  ),
                SizedBox(
                  width: 70,
                  child: Text(
                    _formatDuration(_estimatedDurationMins ?? 60),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.end,
                  ),
                ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Slide to set your parking duration',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Reserve'),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop({
        'number': _vehicleNumberController.text.trim().toUpperCase(),
        'type': _selectedVehicleType!,
        'expected_checkin_time': _expectedCheckInTime?.toIso8601String(),
        'estimated_duration_mins': _estimatedDurationMins ?? 60,
      });
    }
  }
}



