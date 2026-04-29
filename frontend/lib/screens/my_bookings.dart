import 'package:flutter/material.dart';

import '../services/parking_service.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<dynamic>> _reservationsFuture;
  late TabController _tabController;

  static const _tabs = ['Live', 'Completed', 'Cancelled'];
  static const _statusMap = {
    'Live': ['pending_booking_payment', 'reserved', 'checked_in', 'confirmed', 'pending'],
    'Completed': ['completed', 'checked_out'],
    'Cancelled': ['cancelled'],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _reservationsFuture = ParkingService.getReservations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _reservationsFuture = ParkingService.getReservations();
    });
  }

  List<dynamic> _filter(List<dynamic> rows, String tab) {
    final statuses = _statusMap[tab]!;
    return rows.where((r) {

      final s = ((r as Map<String, dynamic>)['status'] ?? '').toString().toLowerCase();
      return statuses.contains(s);
    }).toList();
  }

  Future<void> _cancelBooking(Map<String, dynamic> r) async {
    final id = r['id'];
    if (id == null) return;

    // Show reason selection dialog
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cancel reservation ${r['reservation_id'] ?? id}?'),
            const SizedBox(height: 16),
            const Text('Select a reason:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...['Changed my mind', 'Emergency', 'Wrong slot selected', 'Other'].map(
              (r) => ListTile(
                title: Text(r),
                onTap: () => Navigator.pop(context, r),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
        ],
      ),
    );

    if (reason == null) return;

    final result = await ParkingService.cancelReservation(id as int, cancellationReason: reason);
    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled successfully.')),
      );
      _reload();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${result['error'] ?? 'Unknown error'}')),
      );
    }
  }

  Widget _buildList(List<dynamic> rows, {bool showCancel = false}) {
    if (rows.isEmpty) return const Center(child: Text('No bookings here.'));
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = rows[i] as Map<String, dynamic>;
        final status = (r['status'] ?? '').toString().toLowerCase();
        final canCancel = showCancel &&
            ['pending_booking_payment', 'reserved', 'confirmed', 'pending'].contains(status);
        
        // Build subtitle with cancellation reason if applicable
        String subtitle = 'Slot: ${r['slot_label'] ?? '-'}\nStatus: ${r['status'] ?? '-'}\nFee: ${r['final_fee'] ?? r['booking_fee'] ?? '-'}';
        if (status == 'cancelled' && r['cancellation_reason'] != null) {
          subtitle += '\nReason: ${r['cancellation_reason']}';
        }
        
        return Card(
          child: ListTile(
            leading: Icon(
              status == 'cancelled' ? Icons.cancel_outlined :
              status == 'checked_out' || status == 'completed' ? Icons.check_circle_outline :
              Icons.confirmation_number_outlined,
              color: status == 'cancelled' ? Colors.red :
                     status == 'checked_out' || status == 'completed' ? Colors.green : null,
            ),
            title: Text('Reservation: ${r['reservation_id'] ?? '-'}'),
            subtitle: Text(subtitle),
            isThreeLine: status == 'cancelled' && r['cancellation_reason'] != null,
            trailing: canCancel
                ? TextButton(
                    onPressed: () => _cancelBooking(r),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Cancel'),
                  )
                : null,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color(0xFF312E81),
            // deep navy
  Color(0xFF1E293B), // smooth transition
  Color(0xFF0F172A), // subtle purple-blue
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _reservationsFuture,
              
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      
                      
                      padding: const EdgeInsets.all(16),
                      child: Text('Failed to load bookings: ${snapshot.error}'),

                      
                    ),
                  );
                }
                final all = snapshot.data ?? <dynamic>[];
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: TabBarView(
                    controller: _tabController,
                    children: _tabs
                        .map((t) => _buildList(_filter(all, t), showCancel: t == 'Live'))
                        .toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ));
  }
}



