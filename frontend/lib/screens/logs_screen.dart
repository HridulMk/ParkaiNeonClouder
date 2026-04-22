import 'package:flutter/material.dart';

import '../services/parking_service.dart';
import '../services/auth_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<dynamic> _logs = [];
  List<dynamic> _filteredLogs = [];
  List<String> _parkingSpaces = [];
  bool _loading = true;
  String? _error;
  String? _selectedSpace;
  String? _userType;
  String? _assignedSpaceName;
  String _selectedLogType = 'all'; // 'all', 'vehicle', 'reservations'

  @override
  void initState() {
    super.initState();
    _loadUserTypeAndLogs();
  }

  Future<void> _loadUserTypeAndLogs() async {
    try {
      final userData = await AuthService.getUserData();
      _userType = userData?['user_type'];
      if (_userType == 'security') {
        _assignedSpaceName = userData?['assigned_parking_space_name']?.toString();
        if (_assignedSpaceName != null && _assignedSpaceName!.isNotEmpty) {
          _selectedSpace = _assignedSpaceName;
        }
      }
    } catch (e) {
      // continue without user data
    }
    await _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<dynamic> allLogs = [];

      // Fetch vehicle logs
      if (_selectedLogType == 'all' || _selectedLogType == 'vehicle') {
        try {
          final vehicleLogs = await ParkingService.getVehicleLogs();
          // Add type identifier to each log
          for (final log in vehicleLogs) {
            (log as Map<String, dynamic>)['log_type'] = 'vehicle';
          }
          allLogs.addAll(vehicleLogs);
        } catch (e) {
          // If vehicle logs fail, continue with reservations
          print('Failed to load vehicle logs: $e');
        }
      }

      // Fetch reservations
      if (_selectedLogType == 'all' || _selectedLogType == 'reservations') {
        try {
          final reservations = await ParkingService.getReservations();
          // Add type identifier to each reservation
          for (final reservation in reservations) {
            (reservation as Map<String, dynamic>)['log_type'] = 'reservation';
          }
          allLogs.addAll(reservations);
        } catch (e) {
          // If reservations fail, continue with vehicle logs
          print('Failed to load reservations: $e');
        }
      }
      
      if (!mounted) return;

      // Sort: for security, assigned space logs first, then by timestamp
      allLogs.sort((a, b) {
        if (_userType == 'security' && _assignedSpaceName != null) {
          final aIsAssigned = _getSpaceName(a) == _assignedSpaceName ? 0 : 1;
          final bIsAssigned = _getSpaceName(b) == _assignedSpaceName ? 0 : 1;
          if (aIsAssigned != bIsAssigned) return aIsAssigned.compareTo(bIsAssigned);
        }
        return _getLogTimestamp(b).compareTo(_getLogTimestamp(a));
      });

      // Extract unique parking spaces
      final spaces = <String>{};
      for (final log in allLogs) {
        final name = _getSpaceName(log);
        if (name.isNotEmpty) spaces.add(name);
      }

      setState(() {
        _logs = allLogs;
        _filteredLogs = allLogs;
        _parkingSpaces = spaces.toList()..sort();
        _loading = false;
      });
      
      // Apply current filters
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  DateTime _getLogTimestamp(dynamic log) {
    final logType = log['log_type'];
    if (logType == 'vehicle') {
      final checkInTime = log['check_in_time'];
      if (checkInTime != null) {
        return DateTime.parse(checkInTime);
      }
    } else if (logType == 'reservation') {
      final createdAt = log['created_at'];
      if (createdAt != null) {
        return DateTime.parse(createdAt);
      }
    }
    return DateTime.now(); // Fallback
  }

  void _filterBySpace(String? spaceName) {
    setState(() {
      _selectedSpace = spaceName;
      _applyFilters();
    });
  }

  void _filterByLogType(String logType) {
    setState(() {
      _selectedLogType = logType;
      _loadLogs(); // Reload logs when type changes
    });
  }

  void _applyFilters() {
    var filtered = _logs;

    // Filter by log type
    if (_selectedLogType != 'all') {
      filtered = filtered.where((log) => log['log_type'] == _selectedLogType).toList();
    }

    // Filter by space
    if (_selectedSpace != null && _selectedSpace!.isNotEmpty) {
      filtered = filtered.where((log) {
        return _getSpaceName(log) == _selectedSpace;
      }).toList();
    }

    setState(() {
      _filteredLogs = filtered;
    });
  }

  // vehicle logs: space_name, slot_label (flat fields from VehicleLogSerializer)
  // reservations: parking_space_name, slot_label (flat fields from ReservationSerializer)
  String _getSpaceName(dynamic log) {
    if (log['log_type'] == 'vehicle') {
      return log['space_name']?.toString() ?? '';
    }
    return log['parking_space_name']?.toString() ?? '';
  }

  String _getSlotLabel(dynamic log) {
    return log['slot_label']?.toString() ?? 'N/A';
  }


  String _getDurationText(dynamic log) {
    final durationHours = log['duration_hours'];
    if (durationHours == null) return 'N/A';
    if (durationHours < 1) {
      final minutes = (durationHours * 60).toStringAsFixed(0);
      return '$minutes min';
    }
    return '${durationHours} hrs';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text(_userType == 'security' ? 'My Parking Logs' : 'Parking Logs', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF161B22),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 56),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadLogs,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _logs.isEmpty
                  ? const Center(
                      child: Text(
                        'No logs found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : Column(
                      children: [
                                        if (_parkingSpaces.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: DropdownButton<String>(
                              value: _selectedSpace,
                              hint: const Text(
                                'Filter by Parking Space',
                                style: TextStyle(color: Colors.white54),
                              ),
                              isExpanded: true,
                              dropdownColor: const Color(0xFF161B22),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('All Spaces', style: TextStyle(color: Colors.white)),
                                ),
                                ..._parkingSpaces.map((space) => DropdownMenuItem<String>(
                                  value: space,
                                  child: Row(
                                    children: [
                                      if (_userType == 'security' && space == _assignedSpaceName)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 6),
                                          child: Icon(Icons.security, color: Colors.blueAccent, size: 14),
                                        ),
                                      Text(space, style: const TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                )),
                              ],
                              onChanged: _filterBySpace,
                            ),
                          ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _filteredLogs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final log = _filteredLogs[i] as Map<String, dynamic>;
                              final logType = log['log_type'];
                              final isVehicleLog = logType == 'vehicle';
                              final isReservation = logType == 'reservation';

                              // Determine status and colors
                              Color iconColor;
                              Color statusColor;
                              String statusText;
                              IconData icon;

                              if (isVehicleLog) {
                                final checkOutTime = log['check_out_time'];
                                final isActive = checkOutTime == null;
                                iconColor = isActive ? Colors.greenAccent : Colors.cyanAccent;
                                statusColor = isActive ? Colors.greenAccent : Colors.white54;
                                statusText = isActive ? 'Active' : 'Completed';
                                icon = Icons.directions_car;
                              } else if (isReservation) {
                                final status = log['status']?.toString() ?? '';
                                switch (status) {
                                  case 'checked_in':
                                    iconColor = Colors.greenAccent;
                                    statusColor = Colors.greenAccent;
                                    statusText = 'Checked In';
                                    icon = Icons.check_circle;
                                    break;
                                  case 'checked_out':
                                    iconColor = Colors.orangeAccent;
                                    statusColor = Colors.orangeAccent;
                                    statusText = 'Checked Out';
                                    icon = Icons.exit_to_app;
                                    break;
                                  case 'completed':
                                    iconColor = Colors.blueAccent;
                                    statusColor = Colors.blueAccent;
                                    statusText = 'Completed';
                                    icon = Icons.done_all;
                                    break;
                                  case 'reserved':
                                    iconColor = Colors.yellowAccent;
                                    statusColor = Colors.yellowAccent;
                                    statusText = 'Reserved';
                                    icon = Icons.schedule;
                                    break;
                                  default:
                                    iconColor = Colors.cyanAccent;
                                    statusColor = Colors.white54;
                                    statusText = 'Pending';
                                    icon = Icons.pending;
                                }
                              } else {
                                iconColor = Colors.cyanAccent;
                                statusColor = Colors.white54;
                                statusText = 'Unknown';
                                icon = Icons.help;
                              }

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161B22),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white10,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          icon,
                                          color: iconColor,
                                          size: 28,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isVehicleLog 
                                                  ? (log['vehicle_number']?.toString() ?? 'Unknown')
                                                  : (log['reservation_id']?.toString() ?? 'Unknown'),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              if (isVehicleLog && log['vehicle_type'] != null && log['vehicle_type'].toString().isNotEmpty)
                                                Text(
                                                  log['vehicle_type'].toString(),
                                                  style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              if (isReservation)
                                                Text(
                                                  'Reservation',
                                                  style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            statusText,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.03),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          _LogDetailRow(
                                            label: 'Space',
                                            value: _getSpaceName(log).isEmpty ? 'N/A' : _getSpaceName(log),
                                          ),
                                          _LogDetailRow(
                                            label: 'Slot',
                                            value: _getSlotLabel(log),
                                          ),
                                          if (isVehicleLog) ...[
                                            _LogDetailRow(
                                              label: 'Check-In',
                                              value: _formatDateTime(log['check_in_time']),
                                            ),
                                            if (log['check_out_time'] != null)
                                              _LogDetailRow(
                                                label: 'Check-Out',
                                                value: _formatDateTime(log['check_out_time']),
                                              ),
                                            _LogDetailRow(
                                              label: 'Duration',
                                              value: _getDurationText(log),
                                            ),
                                          ],
                                          if (isReservation) ...[
                                            _LogDetailRow(
                                              label: 'Booked',
                                              value: _formatDateTime(log['created_at']),
                                            ),
                                            if (log['checkin_time'] != null)
                                              _LogDetailRow(
                                                label: 'Check-In',
                                                value: _formatDateTime(log['checkin_time']),
                                              ),
                                            if (log['checkout_time'] != null)
                                              _LogDetailRow(
                                                label: 'Check-Out',
                                                value: _formatDateTime(log['checkout_time']),
                                              ),
                                            _LogDetailRow(
                                              label: 'Booking Fee',
                                              value: '₹${log['booking_fee']?.toString() ?? '0.00'}',
                                            ),
                                            if (log['final_fee'] != null)
                                              _LogDetailRow(
                                                label: 'Final Fee',
                                                value: '₹${log['final_fee']}',
                                              ),
                                            _LogDetailRow(
                                              label: 'Total Charged',
                                              value: '₹${log['total_charged']?.toString() ?? '0.00'}',
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTimeStr);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }
}

class _LogDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _LogDetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
