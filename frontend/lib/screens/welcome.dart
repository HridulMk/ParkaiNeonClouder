
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _bgController;

  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _problemsKey = GlobalKey();
  final GlobalKey _aiKey = GlobalKey();
  final GlobalKey _reviewsKey = GlobalKey();
  final GlobalKey _upcomingKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    Navigator.pushNamed(context, '/login');
  }

  void _scrollToKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;

    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  void _openMenu() {
    final List<_MenuItemData> items = [
      _MenuItemData('Features', _featuresKey),
      _MenuItemData('About', _problemsKey),
      _MenuItemData('AI', _aiKey),
      _MenuItemData('Reviews', _reviewsKey),
      _MenuItemData('Upcoming', _upcomingKey),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...items.map(
                  (item) => ListTile(
                    title: Text(
                      item.label,
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.white70),
                    onTap: () {
                      Navigator.pop(context);
                      _scrollToKey(item.keyRef);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _goToLogin();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22D3EE),
                      foregroundColor: const Color(0xFF0B1220),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Get Started'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(20, 255, 255, 255),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFF070D16).withOpacity(0.80),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [Color(0xFF22D3EE), Color(0xFF0EA5A4)],
                ),
              ),
               child: const Icon(Icons.local_parking, color: Color.fromARGB(255, 242, 241, 244), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'ParkAI',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openMenu,
            icon: const Icon(Icons.menu_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgController,
              builder: (_, __) {
                return CustomPaint(
                  painter: _ModernBgPainter(_bgController.value),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _HeroCard(onPrimary: _goToLogin),
                  ),
                ),
                SliverToBoxAdapter(
                  key: _featuresKey,
                  child: _Section(
                    title: 'Features',
                    subtitle: 'Designed for speed, clarity and trust.',
                    child: GridView.count(
                      crossAxisCount: 2,
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.06,
                      children: const [
                        _FeatureTile(
                          icon: Icons.location_searching,
                          title: 'Live Spots',
                          sub: 'Real-time map availability',
                        ),
                        _FeatureTile(
                          icon: Icons.qr_code_2,
                          title: 'QR Entry',
                          sub: 'Contactless entry and exit',
                        ),
                        _FeatureTile(
                          icon: Icons.shield_outlined,
                          title: 'AI Security',
                          sub: 'Anomaly and intrusion alerts',
                        ),
                        _FeatureTile(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Cashless',
                          sub: 'UPI, cards and wallets',
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  key: _problemsKey,
                  child: _Section(
                    title: 'Problems We Solve',
                    subtitle: 'No circling. No guesswork. No stress.',
                    child: const Column(
                      children: [
                        _InfoRow(
                          title: 'Wasted Time',
                          desc: 'Find and reserve nearby slots in seconds.',
                          icon: Icons.timelapse,
                        ),
                        SizedBox(height: 10),
                        _InfoRow(
                          title: 'Unreliable Info',
                          desc: 'Availability updates continuously with AI.',
                          icon: Icons.insights_outlined,
                        ),
                        SizedBox(height: 10),
                        _InfoRow(
                          title: 'Security Gaps',
                          desc: '24/7 CCTV and automated incident notifications.',
                          icon: Icons.gpp_good_outlined,
                        ),
                      ],
                    ),
                  ),
                ),
                
                SliverToBoxAdapter(
                  key: _aiKey,
                  child: _Section(
                    title: 'AI Engine',
                    subtitle: 'Parking predictions that improve every day.',
                    child: const Column(
                      children: [
                        _AIPill(
                          icon: Icons.trending_up,
                          title: 'Demand Forecasting',
                        ),
                        SizedBox(height: 10),
                        _AIPill(
                          icon: Icons.route_outlined,
                          title: 'Smart Routing',
                        ),
                        SizedBox(height: 10),
                        _AIPill(
                          icon: Icons.warning_amber_rounded,
                          title: 'Anomaly Detection',
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
  child: _Section(
    title: 'Advanced Features',
    subtitle: 'Smart automation powered by AI.',
    child: const Column(
      children: [
        _InfoRow(
          title: 'Auto Booking Cancellation',
          desc: 'Bookings cancel automatically after 45 minutes if not checked-in.',
          icon: Icons.timer_off,
        ),
        SizedBox(height: 10),
        _InfoRow(
          title: 'Slot Prediction',
          desc: 'AI predicts future parking availability during peak hours.',
          icon: Icons.insights,
        ),
        SizedBox(height: 10),
        _InfoRow(
          title: 'Real-time Notifications',
          desc: 'Get instant alerts for booking, payments and updates.',
          icon: Icons.notifications,
        ),
      ],
    ),
  ),
),
SliverToBoxAdapter(
  child: _Section(
    title: 'For Vendors',
    subtitle: 'Earn from your unused parking space.',
    child: const Column(
      children: [
        _InfoRow(
          title: 'Earn Income',
          desc: 'Monetize unused parking spaces easily.',
          icon: Icons.attach_money,
        ),
        SizedBox(height: 10),
        _InfoRow(
          title: 'Manage Slots',
          desc: 'Control slot availability and pricing.',
          icon: Icons.dashboard_customize,
        ),
        SizedBox(height: 10),
        _InfoRow(
          title: 'Analytics Dashboard',
          desc: 'Track bookings, earnings and performance.',
          icon: Icons.bar_chart,
        ),
      ],
    ),
  ),
),
                SliverToBoxAdapter(
                  key: _reviewsKey,
                  child: _Section(
                    title: 'User Reviews',
                    subtitle: 'People are parking faster and safer.',
                    child: const Column(
                      children: [
                        _ReviewTile(
                          name: 'Sarah Anderson',
                          text: 'Saved me at least 40 minutes every day.',
                        ),
                        SizedBox(height: 10),
                        _ReviewTile(
                          name: 'Michael Chen',
                          text: 'Our lot revenue grew after switching to ParkAI.',
                        ),
                        SizedBox(height: 10),
                        _ReviewTile(
                          name: 'Emma Rodriguez',
                          text: 'Security events are now caught instantly.',
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  key: _upcomingKey,
                  child: _Section(
                    title: 'Upcoming',
                    subtitle: 'What we are building next.',
                    child: const Column(
                      children: [
                        _InfoRow(
                          title: 'Autonomous Parking',
                          desc: 'Hands-free vehicle docking experiences.',
                          icon: Icons.directions_car_outlined,
                        ),
                        SizedBox(height: 10),
                        _InfoRow(
                          title: 'EV Smart Charging',
                          desc: 'Queue-aware charging slot optimization.',
                          icon: Icons.ev_station_outlined,
                        ),
                        SizedBox(height: 10),
                        _InfoRow(
                          title: 'Voice Assistant',
                          desc: 'Navigate, book and pay with voice commands.',
                          icon: Icons.keyboard_voice_outlined,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: _CtaCard(onTap: _goToLogin),
                  ),
                ),
                const SliverToBoxAdapter(child: _Footer()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItemData {
  final String label;
  final GlobalKey keyRef;
  _MenuItemData(this.label, this.keyRef);
}

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withOpacity(0.66), fontSize: 14),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final VoidCallback onPrimary;
  const _HeroCard({required this.onPrimary});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The Future of Parking',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'AI-powered reservations, live availability and secure entry.',
            style: TextStyle(
              color: Color(0xFF67E8F9),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onPrimary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22D3EE),
                    foregroundColor: const Color(0xFF0B1220),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Start Parking Smart'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/demo');
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: const Color(0xFF22D3EE).withOpacity(0.7),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Watch Demo',
                    style: TextStyle(color: Color(0xFF67E8F9)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(child: _MiniStat(label: 'Available', value: '1,247')),
              SizedBox(width: 10),
              Expanded(child: _MiniStat(label: 'EV Ready', value: '184')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF67E8F9),
              fontWeight: FontWeight.w800,
            ),
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

class _CtaCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CtaCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
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
            'Ready to park smarter?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign up now and unlock 10 free parking reservations.',
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
              child: const Text('Get Started'),
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