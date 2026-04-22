// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:parking_app/screens/security_home.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import '../services/auth_service.dart';
import '../widgets/app_floating_nav.dart';
import 'dashboard.dart';
import 'customer_dashboar.dart';
import 'my_bookings.dart';
import 'parking_list.dart';
import 'welcome.dart';
import 'demo_working.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 2; // default to Home tab
  bool _isBackendConnected = true;
  Timer? _connectionTimer;

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const MyBookingsScreen();
      case 1:
        return const CustomerDashboardScreen();
      case 2:
        return _HomeContent(key: const ValueKey('homeContent'), onSelect: _onNavTap);
      case 3:
        return ParkingListScreen();
      case 5:
         return const SecurityHomeScreen();
      case 4:
      default:
        return const ProfileScreen();
    }
  }

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _connectionTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkConnection());
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
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

  extendBody: true,
      backgroundColor: Colors.transparent.withOpacity(0.16),
      body: _buildBody(),
      // body: SafeArea(
      //   child: Column(
      //     children: [
      //       Expanded(child: _buildBody()),
      //       if (!_isBackendConnected)
      //         Container(
      //           color: Colors.red,
      //           width: double.infinity,
      //           padding: const EdgeInsets.all(8.0),
      //           child: const Text(
      //             'Warning: Backend server is not reachable. Some features may not work.',
      //             style: TextStyle(color: Colors.white),
      //             textAlign: TextAlign.center,
      //           ),
      //         ),
      //     ],
      //   ),
      // ),
      bottomNavigationBar: AppFloatingNavBar(
        selectedIndex: _selectedIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

class _HomeContent extends StatefulWidget {
  final ValueChanged<int> onSelect;

  const _HomeContent({super.key, required this.onSelect});

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _heroKey = GlobalKey();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _aiKey = GlobalKey();
  final GlobalKey _reviewsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

  extendBody: true,
      backgroundColor: const Color(0xFF050A12),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _ModernBgPainter(_controller.value),
                      size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
                    );
                  },
                ),
                SafeArea(
                  child: Column(
                    children: [
                      _HeroCard(
                        key: _heroKey,
                        onFeaturesTap: () => _scrollToSection(_featuresKey),
                        onAiTap: () => _scrollToSection(_aiKey),
                        onReviewsTap: () => _scrollToSection(_reviewsKey),
                      ),
                      const SizedBox(height: 40),
                      _FeaturesSection(key: _featuresKey),
                      const SizedBox(height: 40),
                      _ProblemsSection(),
                      const SizedBox(height: 40),
                      _AISection(key: _aiKey),
                      const SizedBox(height: 40),
                      _ReviewsSection(key: _reviewsKey),
                      const SizedBox(height: 40),
                      _UpcomingSection(),
                      const SizedBox(height: 40),
                      _CtaCard(onTap: () => widget.onSelect(1)), // Navigate to dashboard
                      const SizedBox(height: 20),
                      const _Footer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final VoidCallback onFeaturesTap;
  final VoidCallback onAiTap;
  final VoidCallback onReviewsTap;

  const _HeroCard({
    super.key,
    required this.onFeaturesTap,
    required this.onAiTap,
    required this.onReviewsTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                'Welcome to ParkAI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmall ? 32 : 40,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Smart parking solutions powered by AI',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: isSmall ? 16 : 18,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _NavButton(
                    label: 'Features',
                    onTap: onFeaturesTap,
                  ),
                  _NavButton(
                    label: 'AI Tech',
                    onTap: onAiTap,
                  ),
                  _NavButton(
                    label: 'Reviews',
                    onTap: onReviewsTap,
                  ),
                  _NavButton(
                    label: 'Watch Demo',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DemoWorkingScreen()),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        backgroundColor: Colors.white.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const Text(
            'Smart Features',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Everything you need for seamless parking',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: const [
                  _FeatureTile(
                    icon: Icons.local_parking,
                    title: 'Real-time Availability',
                    sub: 'Find parking spots instantly with live updates',
                  ),
                  _FeatureTile(
                    icon: Icons.schedule,
                    title: 'Advance Booking',
                    sub: 'Reserve your spot ahead of time',
                  ),
                  _FeatureTile(
                    icon: Icons.payment,
                    title: 'Easy Payments',
                    sub: 'Secure and fast payment processing',
                  ),
                  _FeatureTile(
                    icon: Icons.security,
                    title: 'Secure Parking',
                    sub: 'CCTV monitoring and secure access',
                  ),
                  _FeatureTile(
                    icon: Icons.directions_car,
                    title: 'License Plate Recognition',
                    sub: 'Automated entry with AI-powered recognition',
                  ),
                  _FeatureTile(
                    icon: Icons.analytics,
                    title: 'Usage Analytics',
                    sub: 'Track your parking history and patterns',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF22D3EE).withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF67E8F9), size: 20),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }
}

class _ProblemsSection extends StatelessWidget {
  const _ProblemsSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const Text(
            'Problems We Solve',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Making parking effortless for everyone',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          const SizedBox(height: 24),
          const _InfoRow(
            title: 'No More Parking Woes',
            desc: 'Eliminate the stress of finding parking spots in busy areas',
            icon: Icons.search_off,
          ),
          const SizedBox(height: 12),
          const _InfoRow(
            title: 'Save Time & Money',
            desc: 'Reduce fuel consumption and time spent circling for parking',
            icon: Icons.savings,
          ),
          const SizedBox(height: 12),
          const _InfoRow(
            title: 'Secure & Reliable',
            desc: 'Your vehicle is monitored and protected 24/7',
            icon: Icons.shield,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;

  const _InfoRow({
    required this.title,
    required this.desc,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF22D3EE).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF67E8F9)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AISection extends StatelessWidget {
  const _AISection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const Text(
            'Powered by AI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cutting-edge technology for intelligent parking',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: const [
              _AIPill(icon: Icons.camera_alt, title: 'Computer Vision'),
              _AIPill(icon: Icons.psychology, title: 'Machine Learning'),
              _AIPill(icon: Icons.memory, title: 'Real-time Processing'),
              _AIPill(icon: Icons.security, title: 'Fraud Detection'),
              _AIPill(icon: Icons.trending_up, title: 'Predictive Analytics'),
              _AIPill(icon: Icons.smart_toy, title: 'Automated Systems'),
            ],
          ),
        ],
      ),
    );
  }
}

class _AIPill extends StatelessWidget {
  final IconData icon;
  final String title;

  const _AIPill({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF67E8F9)),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const Text(
            'What Users Say',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Trusted by thousands of drivers',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600 ? 3 : 1;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: const [
                  _ReviewTile(
                    name: 'Sarah Johnson',
                    text: 'ParkAI has completely changed how I park in the city. No more wasted time!',
                  ),
                  _ReviewTile(
                    name: 'Mike Chen',
                    text: 'The AI recognition is incredible. My car is always secure and I get real-time updates.',
                  ),
                  _ReviewTile(
                    name: 'Emma Davis',
                    text: 'Best parking app I\'ve used. The interface is intuitive and payments are seamless.',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final String name;
  final String text;

  const _ReviewTile({
    required this.name,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              SizedBox(width: 6),
              Text('5.0', style: TextStyle(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(color: Colors.white.withOpacity(0.8))),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(color: Color(0xFF67E8F9), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const Text(
            'Coming Soon',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Exciting features on the horizon',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          const SizedBox(height: 24),
          const _InfoRow(
            title: 'Mobile App Integration',
            desc: 'Full mobile experience with push notifications and offline access',
            icon: Icons.phone_android,
          ),
          const SizedBox(height: 12),
          const _InfoRow(
            title: 'IoT Sensor Network',
            desc: 'Ultra-precise parking detection with smart sensors',
            icon: Icons.sensors,
          ),
          const SizedBox(height: 12),
          const _InfoRow(
            title: 'Community Features',
            desc: 'Share parking spots and connect with other drivers',
            icon: Icons.group,
          ),
        ],
      ),
    );
  }
}

class _CtaCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CtaCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF22D3EE).withOpacity(0.22),
            const Color(0xFF0EA5A4).withOpacity(0.16),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ready to explore your dashboard?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Access all your parking features and manage your reservations.',
            style: TextStyle(color: Colors.white.withOpacity(0.84)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22D3EE),
                foregroundColor: const Color(0xFF0B1220),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Go to Dashboard'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
      child: Column(
        children: [
          Divider(color: Colors.white.withOpacity(0.12), height: 1),
          const SizedBox(height: 14),
          Text(
            '© 2026 ParkAI',
            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'Privacy  •  Terms  •  Contact',
            style: TextStyle(color: Colors.white.withOpacity(0.50), fontSize: 12),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: child,
        ),
      ),
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

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            'Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }
}
