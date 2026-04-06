import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';
import 'welcome.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  bool _isBackendConnected = true;
  bool _loadingProfile = true;
  bool _loadingMetrics = true;
  String _adminName = 'Admin';
  String _adminEmail = 'admin@parkai.com';
  String? _profileError;
  String? _metricsError;
  Map<String, dynamic>? _metrics;
  DateTime? _lastConnectionCheck;
  Timer? _connectionTimer;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadAdminMetrics();
    _checkConnection();
    _connectionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkConnection();
      _loadAdminMetrics();
    });
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });

    final profileResult = await AuthService.getUserProfile();
    if (!mounted) return;

    if (profileResult['success'] == true) {
      final user = profileResult['user'] as Map<String, dynamic>;
      setState(() {
        _adminName = user['full_name'] ?? user['username'] ?? 'Admin';
        _adminEmail = user['email'] ?? 'admin@parkai.com';
        _loadingProfile = false;
      });
    } else {
      setState(() {
        _profileError = profileResult['error']?.toString() ?? 'Unable to fetch profile.';
        _loadingProfile = false;
      });
    }
  }

  Future<void> _loadAdminMetrics() async {
    setState(() {
      _loadingMetrics = true;
      _metricsError = null;
    });

    final metricsResult = await AuthService.getAdminMetrics();
    if (!mounted) return;

    if (metricsResult['success'] == true) {
      setState(() {
        _metrics = Map<String, dynamic>.from(metricsResult['data'] as Map<String, dynamic>);
        _loadingMetrics = false;
      });
    } else {
      setState(() {
        _metricsError = metricsResult['error']?.toString() ?? 'Unable to fetch admin metrics.';
        _loadingMetrics = false;
      });
    }
  }

  Future<void> _checkConnection() async {
    final connected = await AuthService.checkBackendConnection();
    if (mounted) {
      setState(() {
        _isBackendConnected = connected;
        _lastConnectionCheck = DateTime.now();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F2E),
        elevation: 0,
        title: const Text('Admin Dashboard'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.purpleAccent.withValues(alpha: 0.18),
                          Colors.purpleAccent.withValues(alpha: 0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loadingProfile ? 'Hello, Admin!' : 'Hello, $_adminName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _loadingProfile
                              ? 'Loading admin profile...'
                              : 'Signed in as $_adminEmail',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _StatusChip(
                              color: _isBackendConnected ? Colors.greenAccent : Colors.redAccent,
                              label: _isBackendConnected ? 'Backend connected' : 'Backend offline',
                            ),
                            const SizedBox(width: 10),
                            _StatusChip(
                              color: _loadingProfile ? Colors.orangeAccent : Colors.blueAccent,
                              label: _loadingProfile ? 'Profile loading' : 'Profile loaded',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_profileError != null)
                          Text(
                            _profileError!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Backend details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Backend & App Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(label: 'API Endpoint', value: AuthService.baseUrl),
                        const SizedBox(height: 8),
                        _DetailRow(label: 'Backend Status', value: _isBackendConnected ? 'Online' : 'Offline'),
                        const SizedBox(height: 8),
                        _DetailRow(label: 'Last Health Check', value: _lastConnectionCheck != null ? '${_lastConnectionCheck!.toLocal()}' : 'Not checked yet'),
                        const SizedBox(height: 8),
                        _DetailRow(label: 'App Version', value: '1.0.0'),
                        const SizedBox(height: 8),
                        _DetailRow(
                          label: 'Total Slots',
                          value: _loadingMetrics ? '...' : '${_metrics?['total_slots'] ?? 0}',
                        ),
                        const SizedBox(height: 8),
                        _DetailRow(
                          label: 'Pending Vendor Docs',
                          value: _loadingMetrics ? '...' : '${_metrics?['vendor_pending_documents'] ?? 0}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // System overview
                  const Text(
                    'System Overview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          icon: Icons.store,
                          label: 'Vendors',
                          value: _loadingMetrics ? '...' : '${_metrics?['total_vendors'] ?? 0}',
                          color: Colors.tealAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatBox(
                          icon: Icons.people,
                          label: 'Users',
                          value: _loadingMetrics ? '...' : '${_metrics?['total_users'] ?? 0}',
                          color: Colors.cyanAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          icon: Icons.local_parking,
                          label: 'Total Spaces',
                          value: _loadingMetrics ? '...' : '${_metrics?['total_spaces'] ?? 0}',
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatBox(
                          icon: Icons.trending_up,
                          label: 'Revenue',
                          value: _loadingMetrics ? '...' : '€${_metrics?['total_revenue'] ?? '0.00'}',
                          color: Colors.greenAccent,
                        ),
                      ),
                    ],
                  ),
                  if (_metricsError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _metricsError!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Pending approvals
                  _ActionCard(
                    icon: Icons.pending_actions,
                    title: 'Pending Approvals',
                    subtitle: _loadingMetrics
                        ? 'Loading approval counts...'
                        : '${_metrics?['vendor_pending_documents'] ?? 0} vendor verifications pending',
                    onTap: () {},
                  ),
                  const SizedBox(height: 24),

                  // Dashboard charts
                  const Text(
                    'Approval & Reservation Charts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _MiniChartCard(
                          title: 'Reservation Status',
                          data: {
                            'Pending': _metrics == null ? 0 : _metrics!['pending_reservations'] ?? 0,
                            'Active': _metrics == null ? 0 : _metrics!['active_reservations'] ?? 0,
                            'Completed': _metrics == null ? 0 : _metrics!['completed_reservations'] ?? 0,
                          },
                          loading: _loadingMetrics,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MiniChartCard(
                          title: 'User Type Distribution',
                          data: {
                            'Customer': _metrics == null ? 0 : _metrics!['total_customers'] ?? 0,
                            'Vendor': _metrics == null ? 0 : _metrics!['total_vendors'] ?? 0,
                            'Security': _metrics == null ? 0 : _metrics!['total_security'] ?? 0,
                            'Admin': _metrics == null ? 0 : _metrics!['total_admins'] ?? 0,
                          },
                          loading: _loadingMetrics,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Management sections
                  const Text(
                    'Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    icon: Icons.local_parking_outlined,
                    title: 'Manage Parking Spaces',
                    subtitle: 'View and edit parking space details',
                    onTap: () => Navigator.of(context).pushNamed('/manage-spaces'),
                  ),
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.videocam_outlined,
                    title: 'CCTV Cameras',
                    subtitle: 'View live parking lot cameras',
                    onTap: () => Navigator.of(context).pushNamed('/cctv-cameras'),
                  ),
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.store_outlined,
                    title: 'Manage Vendors',
                    subtitle: 'Add, edit, or remove parking vendors',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AdminFeatureScreen(
                        title: 'Manage Vendors',
                        description: 'View, approve, and manage vendor accounts.',
                      ),
                    )),
                  ),
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.people_outline,
                    title: 'Manage Users',
                    subtitle: 'View and manage customer accounts',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AdminFeatureScreen(
                        title: 'Manage Users',
                        description: 'Search, filter, and update customer accounts.',
                      ),
                    )),
                  ),
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.security_outlined,
                    title: 'Manage Security',
                    subtitle: 'Control security personnel access',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AdminFeatureScreen(
                        title: 'Manage Security',
                        description: 'Review and assign security staff to parking locations.',
                      ),
                    )),
                  ),
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.receipt_long,
                    title: 'View Reports',
                    subtitle: 'Detailed system and revenue reports',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AdminFeatureScreen(
                        title: 'View Reports',
                        description: 'Analyze bookings, revenue, and operational trends.',
                      ),
                    )),
                  ),
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.settings_outlined,
                    title: 'System Settings',
                    subtitle: 'Configure system-wide parameters',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AdminFeatureScreen(
                        title: 'System Settings',
                        description: 'Edit global settings and application preferences.',
                      ),
                    )),
                  ),
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.warning_outlined,
                    title: 'System Alerts',
                    subtitle: 'View critical system notifications',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AdminFeatureScreen(
                        title: 'System Alerts',
                        description: 'Monitor alerts and system health messages.',
                      ),
                    )),
                  ),
                  const SizedBox(height: 24),

                  // Alerts
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outlined, color: Colors.redAccent, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('System Alert', style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              )),
                              const SizedBox(height: 4),
                              Text(
                                _loadingMetrics
                                    ? 'Loading approval status...'
                                    : '${_metrics?['vendor_pending_documents'] ?? 0} vendors pending verification',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    icon: Icons.logout,
                    title: 'Logout',
                    subtitle: 'Sign out of your account',
                    onTap: () async {
                      await AuthService.logout();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          if (!_isBackendConnected)
            Container(
              color: Colors.red,
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              child: const Text(
                'Warning: Backend server is not reachable. Some features may not work.',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
        ],
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
          Text(value, style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          )),
          Text(label, style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
          )),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _MiniChartCard extends StatelessWidget {
  final String title;
  final Map<String, int> data;
  final bool loading;

  const _MiniChartCard({
    required this.title,
    required this.data,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = data.values.isEmpty ? 1 : data.values.reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            SizedBox(
              height: 100,
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.purpleAccent,
                  strokeWidth: 2.5,
                ),
              ),
            )
          else ...data.entries.map((entry) {
            final barValue = maxValue > 0 ? entry.value / maxValue : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.key} • ${entry.value}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: barValue,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class AdminFeatureScreen extends StatelessWidget {
  final String title;
  final String description;

  const AdminFeatureScreen({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F2E),
        title: Text(title),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(description, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 20),
            const Divider(color: Colors.white12),
            const SizedBox(height: 20),
            const Center(
              child: Icon(Icons.construction, color: Colors.white24, size: 120),
            ),
            const SizedBox(height: 24),
            const Text('This section is in progress.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Color color;
  final String label;

  const _StatusChip({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
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
            Icon(icon, color: Colors.purpleAccent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  )),
                  Text(subtitle, style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  )),
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
