import 'package:flutter/material.dart';
import 'package:parking_app/screens/home1.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../widgets/app_floating_nav.dart';
import 'welcome.dart';
import 'my_bookings.dart';
import 'dashboard.dart';
import 'home.dart';
import 'parking_list.dart';
import 'add_space_screen.dart';
import 'manage_pricing_screen.dart';
import 'vendor_reports_screen.dart';
import '../services/notification_service.dart';
import 'notifications_screen.dart';


class VendorHomeScreen extends StatefulWidget {
  const VendorHomeScreen({super.key});

  @override
  State<VendorHomeScreen> createState() => _VendorHomeScreenState();
}

class _VendorHomeScreenState extends State<VendorHomeScreen> {
  bool _isBackendConnected = true;
  Timer? _connectionTimer;
  int _selectedIndex = 4; // default to Vendor profile tab

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _connectionTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkConnection());
    NotificationService().initialize();
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    final connected = await AuthService.checkBackendConnection();
    if (mounted) setState(() => _isBackendConnected = connected);
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const MyBookingsScreen();
      case 1:
        return DashboardScreen();
      case 2:
        return _VendorHomeContent(isBackendConnected: _isBackendConnected);
      case 3:
         return HomeScreen1();
      case 4:
      default:
        return _VendorProfileContent(isBackendConnected: _isBackendConnected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Color.fromARGB(255, 13, 105, 48),
        Color(0xFF020617),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ),
  child: Scaffold(
    extendBody: true,
    backgroundColor: Colors.transparent, // keep this transparent
    body: _buildBody(),
    bottomNavigationBar: AppFloatingNavBar(
      selectedIndex: _selectedIndex,
      onTap: _onNavTap,
    ),
  ),
);
  }
}

class _VendorHomeContent extends StatelessWidget {
  final bool isBackendConnected;
  const _VendorHomeContent({required this.isBackendConnected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.cyanAccent.withValues(alpha: 0.15),
                    Colors.cyanAccent.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Hello, Vendor!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('Manage your parking spaces', style: TextStyle(color: Colors.white60, fontSize: 14)),
                      ],
                    ),
                  ),
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: Colors.cyanAccent),
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                        },
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: AnimatedBuilder(
                          animation: NotificationService(),
                          builder: (context, _) {
                            final count = NotificationService().unreadCount;
                            if (count == 0) return const SizedBox.shrink();
                            return Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: Text(
                                count > 9 ? '9+' : '$count',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _StatBox(icon: Icons.local_parking, label: 'Total Spaces', value: '48', color: Colors.tealAccent)),
                const SizedBox(width: 12),
                Expanded(child: _StatBox(icon: Icons.check_circle, label: 'Occupied', value: '32', color: Colors.cyanAccent)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatBox(icon: Icons.trending_up, label: 'Revenue', value: '€1,240', color: Colors.blueAccent)),
                const SizedBox(width: 12),
                Expanded(child: _StatBox(icon: Icons.schedule, label: 'Pending', value: '5', color: Colors.orangeAccent)),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Quick Actions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.add_circle_outline,
              title: 'Add New Space',
              subtitle: 'Add parking spaces to your inventory',
              onTap: () async {
                final added = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const AddSpaceScreen()),
                );
                if (added == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Space added successfully!'), backgroundColor: Colors.green),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            _ActionCard(
              icon: Icons.edit_note,
              title: 'Manage Pricing',
              subtitle: 'Update rates for your spaces',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ManagePricingScreen()),
              ),
            ),
            const SizedBox(height: 10),
            _ActionCard(
              icon: Icons.bar_chart,
              title: 'View Reports',
              subtitle: 'Check occupancy and revenue analytics',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VendorReportsScreen()),
              ),
            ),
            if (!isBackendConnected) ...[
              const SizedBox(height: 16),
              Container(
                color: Colors.red,
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                child: const Text(
                  'Warning: Backend server is not reachable. Some features may not work.',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VendorProfileContent extends StatelessWidget {
  final bool isBackendConnected;
  const _VendorProfileContent({required this.isBackendConnected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ActionCard(
              icon: Icons.logout,
              title: 'Logout',
              subtitle: 'Sign out of your account',
              onTap: () async {
                await AuthService.logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.cyanAccent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 18),
          ],
        ),
      ),
    );
  }
}
