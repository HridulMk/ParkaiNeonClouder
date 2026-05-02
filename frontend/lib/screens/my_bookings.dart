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
    'Live': [
      'pending_booking_payment',
      'reserved',
      'checked_in',
      'confirmed',
      'pending'
    ],
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

  Future<void> _reload() async {
    setState(() {
      _reservationsFuture = ParkingService.getReservations();
    });
  }

  List<dynamic> _filter(List<dynamic> rows, String tab) {
    final statuses = _statusMap[tab]!;
    return rows.where((r) {
      final s = ((r as Map<String, dynamic>)['status'] ?? '')
          .toString()
          .toLowerCase();
      return statuses.contains(s);
    }).toList();
  }

  String formatStatus(String s) {
    return s.replaceAll('_', ' ').toUpperCase();
  }

  String _formatTime(dynamic time) {
    if (time == null) return '-';
    try {
      final dt = DateTime.parse(time.toString());
      return '${dt.day}/${dt.month}/${dt.year} '
          '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return time.toString();
    }
  }

  Future<void> _cancelBooking(Map<String, dynamic> r) async {
    final id = r['id'];
    if (id == null) return;

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
            const Text('Select a reason:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...[
              'Changed my mind',
              'Emergency',
              'Wrong slot selected',
              'Other'
            ].map(
              (reason) => ListTile(
                title: Text(reason),
                onTap: () => Navigator.pop(context, reason),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No')),
        ],
      ),
    );

    if (reason == null) return;

    final result = await ParkingService.cancelReservation(
      id as int,
      cancellationReason: reason,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled successfully.')),
      );
      _reload();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Error occurred')),
      );
    }
  }

  Widget _buildList(List<dynamic> rows, {bool showCancel = false}) {
    if (rows.isEmpty) {
      return const Center(
        child: Text('No bookings here.', style: TextStyle(color: Colors.white)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final r = rows[i] as Map<String, dynamic>;
        final status = (r['status'] ?? '').toString().toLowerCase();

        final canCancel = showCancel &&
            ['pending_booking_payment', 'reserved', 'confirmed', 'pending']
                .contains(status);

        String subtitle =
            'Slot: ${r['slot_label'] ?? '-'}\n'
            'Status: ${formatStatus(r['status'] ?? '-')}\n'
            'Booking Fee: ₹${r['booking_fee'] ?? '0'}\n'
            'Final Fee: ₹${r['final_fee'] ?? '0'}';

        // ✅ FIXED HERE (IMPORTANT)
        if (status == 'completed' || status == 'checked_out') {
          subtitle +=
              '\nEntry Time: ${_formatTime(r['checkin_time'])}'
              '\nExit Time: ${_formatTime(r['checkout_time'])}';
        }

        // ✅ Cancellation reason
        if (status == 'cancelled') {
          final reason = r['Reason']?['reason'] ?? r['cancellation_reason'];
          subtitle +=
              '\n\n❌ Cancellation Reason:\n'
              '${reason != null && reason.toString().isNotEmpty ? reason : 'Not provided'}';
        }

        return Card(
          color: Colors.white.withOpacity(0.95),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(
              status == 'cancelled'
                  ? Icons.cancel
                  : status == 'completed' || status == 'checked_out'
                      ? Icons.check_circle
                      : Icons.local_parking,
              color: status == 'cancelled'
                  ? Colors.red
                  : status == 'completed' || status == 'checked_out'
                      ? Colors.green
                      : Colors.blue,
            ),
            title: Text('Reservation: ${r['reservation_id'] ?? '-'}'),
            subtitle: Text(subtitle),
            isThreeLine: true,
            trailing: canCancel
                ? TextButton(
                    onPressed: () => _cancelBooking(r),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.red)),
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF312E81),
              Color(0xFF1E293B),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + kToolbarHeight),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              ),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _reservationsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    final all = snapshot.data ?? [];

                    return RefreshIndicator(
                      onRefresh: _reload,
                      child: TabBarView(
                        controller: _tabController,
                        children: _tabs
                            .map((t) => _buildList(
                                  _filter(all, t),
                                  showCancel: t == 'Live',
                                ))
                            .toList(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}