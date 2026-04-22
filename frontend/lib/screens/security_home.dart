import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../widgets/app_floating_nav_security.dart';
import 'welcome.dart';
import 'security_qr_scanner.dart';

class SecurityHomeScreen extends StatefulWidget {
  const SecurityHomeScreen({super.key});

  @override
  State<SecurityHomeScreen> createState() => _SecurityHomeScreenState();
}

class _SecurityHomeScreenState extends State<SecurityHomeScreen> {
  bool _isBackendConnected = true;
  Timer? _connectionTimer;
  int _selectedIndex = 3; // Security - Parking List
  String? _assignedSpaceName;

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _connectionTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkConnection());
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userData = await AuthService.getUserData();
    if (mounted) {
      setState(() {
        _assignedSpaceName = userData?['assigned_parking_space_name'] as String?;
      });
    }
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    final connected = await AuthService.checkBackendConnection();
    if (mounted) {
      setState(() => _isBackendConnected = connected);
    }
  }

  void _onNavTap(int index) {
  if (index == _selectedIndex) return;

  if (index == 1) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SecurityQrScannerScreen()),
    );
    return;
  }

  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => const SecurityHomeScreen()),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F2E),
        elevation: 0,
        title: const Text('Security Dashboard'),
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blueAccent.withValues(alpha: 0.15),
                          Colors.blueAccent.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hello, Security!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Monitor parking gates and access',
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                        if (_assignedSpaceName != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Colors.blueAccent, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                _assignedSpaceName!,
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Active gates status
                  const Text(
                    'Gate Status',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GateStatusCard(
                    gateName: 'Main Gate A',
                    status: 'Active',
                    lastAccess: '2 minutes ago',
                    accessCount: 24,
                  ),
                  const SizedBox(height: 10),
                  _GateStatusCard(
                    gateName: 'Gate B - East Wing',
                    status: 'Active',
                    lastAccess: '5 minutes ago',
                    accessCount: 18,
                  ),
                  const SizedBox(height: 10),
                  _GateStatusCard(
                    gateName: 'Gate C - Basement',
                    status: 'Inactive',
                    lastAccess: '1 hour ago',
                    accessCount: 5,
                  ),
                  const SizedBox(height: 24),

                  // Stats
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          icon: Icons.check_circle,
                          label: 'Entries',
                          value: '47',
                          color: Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatBox(
                          icon: Icons.warning,
                          label: 'Alerts',
                          value: '2',
                          color: Colors.orangeAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Quick actions
                  const Text(
                    'Actions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ActionCard(
                    icon: Icons.qr_code_scanner,
                    title: 'Scan QR Code',
                    subtitle: 'Check-in or check-out a vehicle',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SecurityQrScannerScreen()),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.lock_open,
                    title: 'Unlock Gate',
                    subtitle: 'Manually unlock a gate',
                    onTap: () {},
                  ),
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.notifications,
                    title: 'View Alerts',
                    subtitle: 'Check security notifications',
                    onTap: () {},
                  ),
                  const SizedBox(height: 10),
                  _ActionCard(
                    icon: Icons.history,
                    title: 'Access Log',
                    subtitle: 'View entry/exit history',
                    onTap: () {},
                  ),
                  const SizedBox(height: 10),
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
      bottomNavigationBar: AppFloatingNavSecurity(
        selectedIndex: _selectedIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

class _GateStatusCard extends StatelessWidget {
  final String gateName;
  final String status;
  final String lastAccess;
  final int accessCount;

  const _GateStatusCard({
    required this.gateName,
    required this.status,
    required this.lastAccess,
    required this.accessCount,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'Active';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.redAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.router, color: isActive ? Colors.greenAccent : Colors.redAccent, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gateName, style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    )),
                    Text(status, style: TextStyle(
                      color: isActive ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    )),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$accessCount', style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Last: $lastAccess', style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
          )),
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
            Icon(icon, color: Colors.blueAccent, size: 28),
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
