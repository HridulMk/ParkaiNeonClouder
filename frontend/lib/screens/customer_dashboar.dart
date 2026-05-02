import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/parking_service.dart';
import '../services/notification_service.dart';
import '../models/parking_slot.dart';
import 'welcome.dart';
import 'notifications_screen.dart';

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({super.key});

  @override
  State<CustomerDashboardScreen> createState() => _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  late Future<_CustomerData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    NotificationService().initialize();
  }

  Future<_CustomerData> _load() async {
    final results = await Future.wait<dynamic>([
      AuthService.getUserProfile(),
      ParkingService.getReservations(),
      ParkingService.getParkingSpaces(),
      ParkingService.getParkingSlots(),
      ParkingService.getPayments(),
    ]);

    final profileResp = results[0] as Map<String, dynamic>;
    final reservations = (results[1] as List<dynamic>).whereType<Map<String, dynamic>>().toList();
    final spaces = (results[2] as List<dynamic>).whereType<Map<String, dynamic>>().toList();
    final slots = results[3] as List<ParkingSlot>;
    final payments = (results[4] as List<dynamic>).whereType<Map<String, dynamic>>().toList();

    Map<String, dynamic> user = {};
    if (profileResp['success'] == true && profileResp['user'] is Map) {
      user = profileResp['user'] as Map<String, dynamic>;
    } else {
      user = await AuthService.getUserData() ?? {};
    }

    // Booking analytics
    int completed = 0, active = 0, cancelled = 0, pending = 0;
    double totalSpent = 0;

    for (final r in reservations) {
      final status = (r['status'] ?? '').toString().toLowerCase();

      if (status == 'completed') {
        completed++;
      } else if (status == 'reserved' || status == 'checked_in') {
        active++;
      } else if (status == 'cancelled') {
        cancelled++;
      } else {
        pending++;
      }
    }

    // Calculate total spent from payments
  for (final p in payments) {
  final type = (p['payment_type'] ?? '').toString();

  if (type == 'booking' || type == 'final') {
    final amount = double.tryParse((p['amount'] ?? '0').toString()) ?? 0;
    totalSpent += amount;
  }
}

    // Nearby spaces with slot info
    final activeSpaces = spaces.where((s) => s['is_active'] == true).toList();
    final nearbySpaces = activeSpaces.take(5).map((space) {
      final id = space['id'];
      final spaceSlots = slots.where((sl) => sl.spaceId == id).toList();
      final vacant = spaceSlots.where((sl) => !sl.isOccupied && sl.isActive).length;
      return _SpaceInfo(
        name: (space['name'] ?? 'Parking Space').toString(),
        location: (space['location'] ?? space['address'] ?? '').toString(),
        total: spaceSlots.length,
        vacant: vacant,
        mapLink: (space['google_map_link'] ?? '').toString(),
      );
    }).toList();

    // Recent 5 bookings
    final recent = reservations.take(5).toList();

    return _CustomerData(
      user: user,
      total: reservations.length,
      completed: completed,
      active: active,
      cancelled: cancelled,
      pending: pending,
      totalSpent: totalSpent,
      recent: recent,
      nearbySpaces: nearbySpaces,
      vacantSlots: slots.where((s) => !s.isOccupied && s.isActive).length,
      occupiedSlots: slots.where((s) => s.isOccupied && s.isActive).length,
    );
  }

  void _reload() => setState(() => _future = _load());

  String _name(Map<String, dynamic> u) {
    final n = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
    return n.isNotEmpty ? n : (u['username'] ?? 'User').toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0F7FF), Color(0xFFE8FFF5)],
        ),
      ),
      child: SafeArea(
        child: FutureBuilder<_CustomerData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _reload, child: const Text('Retry')),
                  ],
                ),
              );
            }

final NotificationService _notificationService = NotificationService();

        final d = snap.data!;
return RefreshIndicator(
  onRefresh: () async => _reload(),
  child: ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
    children: [
      // ── Header ──────────────────────────────────────────
      Row(
        children: [
          const Expanded(
            child: Text(
              'My Dashboard',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),

          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: Color(0xFF0D9488)),
                onPressed: () {
                  print("Notification clicked"); // debug
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const NotificationsScreen(),
    ),
                  );
                },
              ),

              Positioned(
                right: 8,
                top: 8,
                child: AnimatedBuilder(
                  animation: _notificationService, // ✅ fixed
                  builder: (context, _) {
                    final count = _notificationService.unreadCount; // ✅ fixed
                    if (count == 0) return const SizedBox.shrink();

                    return Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await AuthService.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (r) => false,
              );
            },
          ),
        ],
      ),

      const SizedBox(height: 10),
    

                  // ── Profile Card ─────────────────────────────────────
                  _ProfileCard(user: d.user, name: _name(d.user)),
                  const SizedBox(height: 14),

                  // ── KPI Grid ─────────────────────────────────────────
                  _SectionLabel('Booking Overview'),
                  const SizedBox(height: 10),
                  _KpiGrid(data: d),
                  const SizedBox(height: 14),

                  // ── Booking Status Bar ────────────────────────────────
                  _SectionLabel('Booking Breakdown'),
                  const SizedBox(height: 10),
                  _BookingBreakdownCard(data: d),
                  const SizedBox(height: 14),

                  // ── Slot Vacancy ──────────────────────────────────────
                  _SectionLabel('Live Slot Availability'),
                  const SizedBox(height: 10),
                  _SlotVacancyCard(vacant: d.vacantSlots, occupied: d.occupiedSlots),
                  const SizedBox(height: 14),

                  // ── Recent Bookings ───────────────────────────────────
                  _SectionLabel('Recent Bookings'),
                  const SizedBox(height: 10),
                  if (d.recent.isEmpty)
                    _EmptyCard('No bookings yet. Start by reserving a slot!')
                  else
                    ...d.recent.map((r) => _RecentBookingTile(reservation: r)),
                  const SizedBox(height: 14),

                  // ── Nearby Spaces ─────────────────────────────────────
                  _SectionLabel('Nearby Parking Spaces'),
                  const SizedBox(height: 10),
                  if (d.nearbySpaces.isEmpty)
                    _EmptyCard('No active parking spaces available.')
                  else
                    ...d.nearbySpaces.map((s) => _NearbySpaceTile(space: s)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Card
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String name;
  const _ProfileCard({required this.user, required this.name});

  @override
  Widget build(BuildContext context) {
    final email = (user['email'] ?? 'N/A').toString();
    final phone = (user['phone'] ?? 'N/A').toString();
    final userType = (user['user_type'] ?? 'customer').toString();
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF0EA5A4),
            child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(email, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                Text(phone, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5A4).withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              userType.toUpperCase(),
              style: const TextStyle(color: Color(0xFF0EA5A4), fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI Grid
// ─────────────────────────────────────────────────────────────────────────────
class _KpiGrid extends StatelessWidget {
  final _CustomerData data;
  const _KpiGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiItem('Total Bookings', '${data.total}', Icons.receipt_long, const Color(0xFF0EA5E9)),
      _KpiItem('Completed', '${data.completed}', Icons.check_circle_outline, const Color(0xFF22C55E)),
      _KpiItem('Active', '${data.active}', Icons.directions_car, const Color(0xFFF59E0B)),
      _KpiItem('Cancelled', '${data.cancelled}', Icons.cancel_outlined, const Color(0xFFEF4444)),
      _KpiItem('Pending', '${data.pending}', Icons.hourglass_empty, const Color(0xFF8B5CF6)),
      _KpiItem('Total Spent', 'Rs ${data.totalSpent.toStringAsFixed(0)}', Icons.account_balance_wallet, const Color(0xFF0D9488)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.6,
      ),
      itemBuilder: (_, i) => _KpiCard(item: items[i]),
    );
  }
}

class _KpiItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiItem(this.label, this.value, this.icon, this.color);
}

class _KpiCard extends StatelessWidget {
  final _KpiItem item;
  const _KpiCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: item.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: item.color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(item.label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Booking Breakdown Bar
// ─────────────────────────────────────────────────────────────────────────────
class _BookingBreakdownCard extends StatelessWidget {
  final _CustomerData data;
  const _BookingBreakdownCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, data.total);
    final segments = [
      _Segment('Completed', data.completed, const Color(0xFF22C55E)),
      _Segment('Active', data.active, const Color(0xFFF59E0B)),
      _Segment('Cancelled', data.cancelled, const Color(0xFFEF4444)),
      _Segment('Pending', data.pending, const Color(0xFF8B5CF6)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: segments.map((s) {
                  final flex = math.max(1, (s.count / total * 100).round());
                  return Expanded(
                    flex: flex,
                    child: Container(color: s.color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: segments.map((s) => _LegendDot(label: '${s.label} (${s.count})', color: s.color)).toList(),
          ),
        ],
      ),
    );
  }
}

class _Segment {
  final String label;
  final int count;
  final Color color;
  const _Segment(this.label, this.count, this.color);
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slot Vacancy Card
// ─────────────────────────────────────────────────────────────────────────────
class _SlotVacancyCard extends StatelessWidget {
  final int vacant;
  final int occupied;
  const _SlotVacancyCard({required this.vacant, required this.occupied});

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, vacant + occupied);
    final vacancyRatio = vacant / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$vacant vacant of ${vacant + occupied} total slots',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${(vacancyRatio * 100).toStringAsFixed(0)}% free',
                  style: TextStyle(
                    color: vacancyRatio > 0.4 ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: vacancyRatio,
              minHeight: 12,
              backgroundColor: const Color(0xFFEF4444).withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                vacancyRatio > 0.4 ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _LegendDot(label: 'Vacant ($vacant)', color: const Color(0xFF22C55E)),
              const SizedBox(width: 16),
              _LegendDot(label: 'Occupied ($occupied)', color: const Color(0xFFEF4444)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent Booking Tile
// ─────────────────────────────────────────────────────────────────────────────
class _RecentBookingTile extends StatelessWidget {
  final Map<String, dynamic> reservation;
  const _RecentBookingTile({required this.reservation});

  Color _statusColor(String s) {
    switch (s) {
      case 'completed': return const Color(0xFF22C55E);
      case 'reserved': return const Color(0xFF0EA5E9);
      case 'checked_in': return const Color(0xFFF59E0B);
      case 'cancelled': return const Color(0xFFEF4444);
      default: return const Color(0xFF8B5CF6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (reservation['status'] ?? 'pending').toString().toLowerCase();
    final resId = reservation['reservation_id']?.toString() ?? reservation['id']?.toString() ?? '-';
    final slot = reservation['slot_label']?.toString() ?? reservation['slot']?.toString() ?? '-';
    final fee = reservation['final_fee'] ?? reservation['booking_fee'];
    final feeStr = fee != null ? 'Rs $fee' : '-';
    final color = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.confirmation_number_outlined, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Booking #$resId', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Slot: $slot  •  Fee: $feeStr',
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.replaceAll('_', ' ').toUpperCase(),
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nearby Space Tile
// ─────────────────────────────────────────────────────────────────────────────
class _NearbySpaceTile extends StatelessWidget {
  final _SpaceInfo space;
  const _NearbySpaceTile({required this.space});

  @override
  Widget build(BuildContext context) {
    final ratio = space.total == 0 ? 0.0 : space.vacant / space.total;
    final color = ratio > 0.4 ? const Color(0xFF22C55E) : ratio > 0.1 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_parking, color: Color(0xFF0EA5A4), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(space.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '${space.vacant} free',
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (space.location.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(space.location, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          ],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${space.vacant}/${space.total} slots available',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              if (space.mapLink.isNotEmpty)
                GestureDetector(
                  onTap: () => launchUrl(Uri.parse(space.mapLink), mode: LaunchMode.externalApplication),
                  child: const Row(
                    children: [
                      Icon(Icons.map_outlined, size: 14, color: Color(0xFF0EA5A4)),
                      SizedBox(width: 3),
                      Text('View Map', style: TextStyle(fontSize: 12, color: Color(0xFF0EA5A4), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
      );
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard(this.message);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8)],
        ),
        child: Text(message, style: const TextStyle(color: Color(0xFF6B7280))),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────
class _CustomerData {
  final Map<String, dynamic> user;
  final int total, completed, active, cancelled, pending;
  final double totalSpent;
  final List<Map<String, dynamic>> recent;
  final List<_SpaceInfo> nearbySpaces;
  final int vacantSlots, occupiedSlots;

  const _CustomerData({
    required this.user,
    required this.total,
    required this.completed,
    required this.active,
    required this.cancelled,
    required this.pending,
    required this.totalSpent,
    required this.recent,
    required this.nearbySpaces,
    required this.vacantSlots,
    required this.occupiedSlots,
  });
}

class _SpaceInfo {
  final String name, location, mapLink;
  final int total, vacant;

  const _SpaceInfo({
    required this.name,
    required this.location,
    required this.total,
    required this.vacant,
    required this.mapLink,
  });
}
