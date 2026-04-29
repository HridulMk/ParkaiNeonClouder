import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/parking_slot.dart';
import '../services/auth_service.dart';
import '../services/parking_service.dart';
import 'live_location_screen.dart';
import 'welcome.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _dashboardFuture;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<_DashboardData> _loadDashboard() async {
    final results = await Future.wait<dynamic>([
      AuthService.getUserProfile(),
      ParkingService.getParkingSpaces(),
      ParkingService.getReservations(),
      ParkingService.getParkingSlots(),
    ]);

    final profileResp = results[0] as Map<String, dynamic>;
    final spaces = (results[1] as List<dynamic>).whereType<Map<String, dynamic>>().toList();
    final reservations = (results[2] as List<dynamic>).whereType<Map<String, dynamic>>().toList();
    final slots = results[3] as List<ParkingSlot>;

    Map<String, dynamic> user = {};
    if (profileResp['success'] == true && profileResp['user'] is Map<String, dynamic>) {
      user = profileResp['user'] as Map<String, dynamic>;
    } else {
      user = await AuthService.getUserData() ?? <String, dynamic>{};
    }

    final activeSpaces = spaces.where((s) => s['is_active'] == true).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final successfulBookings = reservations.where((r) {
      final status = (r['status'] ?? '').toString();
      return status == 'completed' || r['final_fee_paid'] == true || r['is_paid'] == true;
    }).length;

    final activeUsage = reservations.where((r) {
      final status = (r['status'] ?? '').toString();
      return status == 'reserved' || status == 'checked_in';
    }).length;

    final vacantSlots = slots.where((s) => !s.isOccupied && s.isActive).length;
    final occupiedSlots = slots.where((s) => s.isOccupied && s.isActive).length;
    final totalActiveSlots = vacantSlots + occupiedSlots;
    final occupiedPercent =
        totalActiveSlots == 0 ? 0.0 : occupiedSlots / totalActiveSlots;

    double totalEarnings = 0;
    double monthlyEarnings = 0;
    int todaysBookings = 0;
    final Map<String, int> bookingsByWeekday = {
      'Mon': 0,
      'Tue': 0,
      'Wed': 0,
      'Thu': 0,
      'Fri': 0,
      'Sat': 0,
      'Sun': 0,
    };
    final Map<String, int> statusBreakdown = {
      'Completed': 0,
      'Active': 0,
      'Pending': 0,
      'Cancelled': 0,
    };
    final Map<String, _CustomerStats> customerStats = {};

    for (final reservation in reservations) {
      final createdAt = DateTime.tryParse(
        (reservation['created_at'] ?? '').toString(),
      )?.toLocal();
      final status = (reservation['status'] ?? '').toString().toLowerCase();
      final totalCharged =
          double.tryParse((reservation['total_charged'] ?? '0').toString()) ??
              0;
      final customerName =
          (reservation['user_full_name'] ?? reservation['user_name'] ?? 'Unknown')
              .toString();

      if (createdAt != null) {
        final createdDate = DateTime(
          createdAt.year,
          createdAt.month,
          createdAt.day,
        );
        if (createdDate == today) {
          todaysBookings++;
        }

        final weekdayLabel = bookingsByWeekday.keys.elementAt(
          createdAt.weekday - 1,
        );
        bookingsByWeekday[weekdayLabel] =
            (bookingsByWeekday[weekdayLabel] ?? 0) + 1;
      }

      if (status == 'completed') {
        statusBreakdown['Completed'] =
            (statusBreakdown['Completed'] ?? 0) + 1;
      } else if (status == 'reserved' || status == 'checked_in') {
        statusBreakdown['Active'] = (statusBreakdown['Active'] ?? 0) + 1;
      } else if (status == 'cancelled') {
        statusBreakdown['Cancelled'] =
            (statusBreakdown['Cancelled'] ?? 0) + 1;
      } else {
        statusBreakdown['Pending'] = (statusBreakdown['Pending'] ?? 0) + 1;
      }

      totalEarnings += totalCharged;
      if (createdAt != null &&
          createdAt.year == now.year &&
          createdAt.month == now.month) {
        monthlyEarnings += totalCharged;
      }

      customerStats.putIfAbsent(customerName, () => _CustomerStats());
      customerStats[customerName]!.bookings += 1;
      customerStats[customerName]!.spent += totalCharged;
    }

    String bestCustomer = 'No customer data';
    int bestCustomerBookings = 0;
    double bestCustomerSpent = 0;
    if (customerStats.isNotEmpty) {
      final sortedCustomers = customerStats.entries.toList()
        ..sort((a, b) {
          final spentCompare = b.value.spent.compareTo(a.value.spent);
          if (spentCompare != 0) return spentCompare;
          return b.value.bookings.compareTo(a.value.bookings);
        });
      bestCustomer = sortedCustomers.first.key;
      bestCustomerBookings = sortedCustomers.first.value.bookings;
      bestCustomerSpent = sortedCustomers.first.value.spent;
    }

    final nearbySpaces = activeSpaces.take(6).map((space) {
      final spaceId = space['id'];
      final spaceSlots = slots.where((slot) => slot.spaceId == spaceId).toList();
      final free = spaceSlots.where((slot) => !slot.isOccupied && slot.isActive).length;
      return _NearbySpace(
        name: (space['name'] ?? 'Parking Space').toString(),
        location: (space['location'] ?? space['address'] ?? 'Location unavailable').toString(),
        totalSlots: spaceSlots.length,
        vacantSlots: free,
        mapLink: (space['google_map_link'] ?? '').toString(),
      );
    }).toList();

    final liveLocation = nearbySpaces.isNotEmpty ? nearbySpaces.first.location : 'Location unavailable';

    return _DashboardData(
      user: user,
      totalReservations: reservations.length,
      successfulReservations: successfulBookings,
      activeReservations: activeUsage,
      nearbyParkingCount: activeSpaces.length,
      totalSlots: totalActiveSlots,
      vacantSlots: vacantSlots,
      occupiedSlots: occupiedSlots,
      occupiedPercent: occupiedPercent,
      liveLocation: liveLocation,
      nearbySpaces: nearbySpaces,
      totalEarnings: totalEarnings,
      monthlyEarnings: monthlyEarnings,
      todaysBookings: todaysBookings,
      bestCustomer: bestCustomer,
      bestCustomerBookings: bestCustomerBookings,
      bestCustomerSpent: bestCustomerSpent,
      weeklyBookings: bookingsByWeekday,
      statusBreakdown: statusBreakdown,
    );
  }

  void _reload() {
    setState(() {
      _dashboardFuture = _loadDashboard();
    });
  }

  String _fullName(Map<String, dynamic> user) {
    final first = (user['first_name'] ?? '').toString().trim();
    final last = (user['last_name'] ?? '').toString().trim();
    final joined = '$first $last'.trim();
    if (joined.isNotEmpty) return joined;
    return (user['username'] ?? 'User').toString();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _scrollController,
          builder: (context, _) {
            final t = _scrollController.hasClients
                ? ((_scrollController.offset / 1200) % 1).toDouble()
                : 0.0;
            return CustomPaint(
              painter: _ModernBgPainter(t),
              size: Size(
                MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height,
              ),
            );
          },
        ),
        SafeArea(
          child: FutureBuilder<_DashboardData>(
              future: _dashboardFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Failed to load dashboard: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final data = snapshot.data;
                if (data == null) {
                  return const Center(
                    child: Text(
                      'No dashboard data available.',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final user = data.user;
                final userName = _fullName(user);
                final email = (user['email'] ?? 'Not available').toString();
                final phone = (user['phone'] ?? 'Not available').toString();
                final userType = (user['user_type'] ?? 'customer').toString();
                final width = MediaQuery.of(context).size.width;
                final horizontalPadding = width < 360 ? 12.0 : 16.0;
                final titleSize = width < 360 ? 22.0 : 24.0;

                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      12,
                      horizontalPadding,
                      28,
                    ),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'App Dashboard',
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh, color: Colors.white70),
                          ),
                          IconButton(
                            onPressed: () async {
                              await AuthService.logout();
                              if (!context.mounted) return;
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const WelcomeScreen(),
                                ),
                                (route) => false,
                              );
                            },
                            icon: const Icon(Icons.logout, color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _GlassCard(
                        padding: EdgeInsets.all(width < 360 ? 14 : 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: TextStyle(
                                fontSize: width < 360 ? 18 : 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              email,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.74),
                                fontSize: width < 360 ? 12 : 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Phone: $phone',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.74),
                                fontSize: width < 360 ? 12 : 13,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22D3EE).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Role: ${userType.toUpperCase()}',
                                style: const TextStyle(
                                  color: Color(0xFF67E8F9),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LiveLocationScreen(),
                          ),
                        ),
                        child: _GlassCard(
                          padding: EdgeInsets.all(width < 360 ? 14 : 16),
                          child: Row(
                            children: [
                              const Icon(Icons.my_location, color: Colors.white),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Live Location',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: width < 360 ? 12 : 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      data.liveLocation,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: width < 360 ? 13 : 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white30,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _KpiCard(title: 'Total Earnings', value: 'Rs ${data.totalEarnings.toStringAsFixed(0)}', icon: Icons.currency_rupee, color: const Color(0xFF22C55E)),
                          _KpiCard(title: 'This Month', value: 'Rs ${data.monthlyEarnings.toStringAsFixed(0)}', icon: Icons.calendar_month, color: const Color(0xFF67E8F9)),
                          _KpiCard(title: 'Bookings Today', value: '${data.todaysBookings}', icon: Icons.today, color: const Color(0xFFF59E0B)),
                          _KpiCard(title: 'Total Bookings', value: '${data.totalReservations}', icon: Icons.receipt_long, color: const Color(0xFF0EA5E9)),
                          _KpiCard(title: 'Successful Uses', value: '${data.successfulReservations}', icon: Icons.verified, color: const Color(0xFF22C55E)),
                          _KpiCard(title: 'Active Sessions', value: '${data.activeReservations}', icon: Icons.directions_car, color: const Color(0xFFF59E0B)),
                          _KpiCard(title: 'Nearby Spaces', value: '${data.nearbyParkingCount}', icon: Icons.local_parking, color: const Color(0xFF6366F1)),
                          _KpiCard(title: 'Vacant Slots', value: '${data.vacantSlots}', icon: Icons.event_available, color: const Color(0xFF10B981)),
                          _KpiCard(title: 'Occupied Slots', value: '${data.occupiedSlots}', icon: Icons.event_busy, color: const Color(0xFFEF4444)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _GlassCard(
                        padding: EdgeInsets.all(width < 360 ? 14 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vacancy Analytics',
                              style: TextStyle(
                                fontSize: width < 360 ? 16 : 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: data.totalSlots == 0
                                  ? 0
                                  : (data.vacantSlots / math.max(1, data.totalSlots)),
                              minHeight: 10,
                              borderRadius: BorderRadius.circular(8),
                              backgroundColor: Colors.white.withOpacity(0.12),
                              color: const Color(0xFF22D3EE),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Vacant ${data.vacantSlots} of ${data.totalSlots} active slots',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.76),
                                fontSize: width < 360 ? 12 : 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _MiniMetricTile(
                                    label: 'Occupied Live',
                                    value:
                                        '${(data.occupiedPercent * 100).toStringAsFixed(0)}%',
                                    color: const Color(0xFFEF4444),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _MiniMetricTile(
                                    label: 'Free Live',
                                    value:
                                        '${((1 - data.occupiedPercent) * 100).toStringAsFixed(0)}%',
                                    color: const Color(0xFF22C55E),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _GlassCard(
                        padding: EdgeInsets.all(width < 360 ? 14 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Best Customer',
                              style: TextStyle(
                                fontSize: width < 360 ? 16 : 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              data.bestCustomer,
                              style: TextStyle(
                                fontSize: width < 360 ? 17 : 20,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF67E8F9),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${data.bestCustomerBookings} bookings • Rs ${data.bestCustomerSpent.toStringAsFixed(0)} spent',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.74),
                                fontSize: width < 360 ? 12 : 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Analytics',
                        style: TextStyle(
                          fontSize: width < 360 ? 16 : 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _GlassCard(
                        padding: EdgeInsets.all(width < 360 ? 14 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Weekly Bookings',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _BarChart(
                              data: data.weeklyBookings,
                              barColor: const Color(0xFF22D3EE),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _GlassCard(
                        padding: EdgeInsets.all(width < 360 ? 14 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Booking Status Mix',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _StatusChart(data: data.statusBreakdown),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nearby Parking Availability',
                        style: TextStyle(
                          fontSize: width < 360 ? 16 : 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (data.nearbySpaces.isEmpty)
                        const _GlassCard(
                          child: Padding(
                            padding: EdgeInsets.all(2),
                            child: Text(
                              'No nearby parking spaces available right now.',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                      ...data.nearbySpaces.map(
                        (space) => _GlassCard(
                          padding: EdgeInsets.all(width < 360 ? 12 : 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                space.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: width < 360 ? 14 : 16,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                space.location,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.72),
                                  fontSize: width < 360 ? 12 : 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Nearby slot count: ${space.totalSlots}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Text(
                                'Vacant slots: ${space.vacantSlots}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              if (space.mapLink.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Map: ${space.mapLink}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF67E8F9),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
        ),
        
      )],

    );
    
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 24.0 : 32.0;
    final gap = 10.0;
    final cardsPerRow = screenWidth < 420 ? 1 : 2;
    final width =
        (screenWidth - horizontalPadding - (cardsPerRow - 1) * gap) / cardsPerRow;
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: screenWidth < 360 ? 18 : 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: screenWidth < 360 ? 12 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: child,
    );
  }
}

class _MiniMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniMetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final Map<String, int> data;
  final Color barColor;

  const _BarChart({
    required this.data,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = data.values.isEmpty
        ? 1
        : math.max(1, data.values.reduce(math.max));

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.entries.map((entry) {
          final ratio = entry.value / maxValue;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${entry.value}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 110 * ratio.clamp(0.08, 1.0),
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    entry.key,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatusChart extends StatelessWidget {
  final Map<String, int> data;

  const _StatusChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold<int>(0, (sum, value) => sum + value);
    final colors = <String, Color>{
      'Completed': const Color(0xFF22C55E),
      'Active': const Color(0xFFF59E0B),
      'Pending': const Color(0xFF8B5CF6),
      'Cancelled': const Color(0xFFEF4444),
    };

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 14,
            child: Row(
              children: data.entries.map((entry) {
                final flex = total == 0
                    ? 1
                    : math.max(1, ((entry.value / total) * 100).round());
                return Expanded(
                  flex: flex,
                  child: Container(
                    color: colors[entry.key] ?? Colors.white24,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: data.entries.map((entry) {
            final color = colors[entry.key] ?? Colors.white24;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${entry.key} (${entry.value})',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ModernBgPainter extends CustomPainter {
  final double t;

  _ModernBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF050A12), Color(0xFF0B1320)],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, base);

    _blob(
      canvas,
      x: size.width * 0.20,
      y: 120 + math.sin(t * 2 * math.pi) * 20,
      r: 180,
      color: const Color(0xFF22D3EE).withOpacity(0.10),
    );
    _blob(
      canvas,
      x: size.width * 0.85,
      y: 260 + math.cos(t * 2 * math.pi) * 25,
      r: 140,
      color: const Color(0xFF0EA5A4).withOpacity(0.10),
    );
    _blob(
      canvas,
      x: size.width * 0.50,
      y: size.height * 0.78,
      r: 220,
      color: const Color(0xFF22D3EE).withOpacity(0.06),
    );
  }

  void _blob(
    Canvas canvas, {
    required double x,
    required double y,
    required double r,
    required Color color,
  }) {
    final p = Paint()..color = color;
    canvas.drawCircle(Offset(x, y), r, p);
  }

  @override
  bool shouldRepaint(covariant _ModernBgPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}

class _DashboardData {
  final Map<String, dynamic> user;
  final int totalReservations;
  final int successfulReservations;
  final int activeReservations;
  final int nearbyParkingCount;
  final int totalSlots;
  final int vacantSlots;
  final int occupiedSlots;
  final double occupiedPercent;
  final String liveLocation;
  final List<_NearbySpace> nearbySpaces;
  final double totalEarnings;
  final double monthlyEarnings;
  final int todaysBookings;
  final String bestCustomer;
  final int bestCustomerBookings;
  final double bestCustomerSpent;
  final Map<String, int> weeklyBookings;
  final Map<String, int> statusBreakdown;

  _DashboardData({
    required this.user,
    required this.totalReservations,
    required this.successfulReservations,
    required this.activeReservations,
    required this.nearbyParkingCount,
    required this.totalSlots,
    required this.vacantSlots,
    required this.occupiedSlots,
    required this.occupiedPercent,
    required this.liveLocation,
    required this.nearbySpaces,
    required this.totalEarnings,
    required this.monthlyEarnings,
    required this.todaysBookings,
    required this.bestCustomer,
    required this.bestCustomerBookings,
    required this.bestCustomerSpent,
    required this.weeklyBookings,
    required this.statusBreakdown,
  });
}

class _CustomerStats {
  int bookings = 0;
  double spent = 0;
}

class _NearbySpace {
  final String name;
  final String location;
  final int totalSlots;
  final int vacantSlots;
  final String mapLink;

  _NearbySpace({
    required this.name,
    required this.location,
    required this.totalSlots,
    required this.vacantSlots,
    required this.mapLink,
  });
}





