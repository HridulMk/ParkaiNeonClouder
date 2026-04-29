import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/parking_service.dart';
import 'my_bookings.dart';
import 'wallet_screen.dart';
import 'welcome.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _user = {};
  double _walletBalance = 0;
  bool _loading = true;
  File? _profileImage;

  static const _teal = Color(0xFF0EA5A4);

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final resp = await AuthService.getUserProfile();
    final walletResp = await ParkingService.getWallet();
    setState(() {
      _user = (resp['success'] == true && resp['user'] is Map)
          ? Map<String, dynamic>.from(resp['user'] as Map)
          : {};
      _walletBalance = walletResp['success'] == true
          ? (double.tryParse(walletResp['wallet']?['balance']?.toString() ?? '0') ?? 0)
          : 0;
      _loading = false;
    });
  }

  String get _name {
    final n = '${_user['first_name'] ?? ''} ${_user['last_name'] ?? ''}'.trim();
    return n.isNotEmpty ? n : (_user['username'] ?? 'User').toString();
  }

  String get _email => (_user['email'] ?? '').toString();
  String get _phone => (_user['phone'] ?? '').toString();

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _profileImage = File(picked.path));
  }

  Future<void> _showEditName() async {
    final firstCtrl = TextEditingController(text: _user['first_name']?.toString() ?? '');
    final lastCtrl = TextEditingController(text: _user['last_name']?.toString() ?? '');
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Name'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: firstCtrl, decoration: const InputDecoration(labelText: 'First Name')),
            const SizedBox(height: 8),
            TextField(controller: lastCtrl, decoration: const InputDecoration(labelText: 'Last Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _teal),
            onPressed: () {
              setState(() {
                _user['first_name'] = firstCtrl.text.trim();
                _user['last_name'] = lastCtrl.text.trim();
              });
              Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await AuthService.logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming soon!'), duration: const Duration(seconds: 2)),
    );
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // ── Profile Header ──────────────────────────────────
                  _ProfileHeader(
                    name: _name,
                    email: _email,
                    phone: _phone,
                    image: _profileImage,
                    onPickImage: _pickImage,
                    onEditName: _showEditName,
                  ),
                  const SizedBox(height: 20),

                  // ── Account Section ─────────────────────────────────
                  _SectionTitle('Account'),
                  _MenuItem(
                    icon: Icons.book_online_outlined,
                    color: _teal,
                    label: 'Manage Bookings',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('My Bookings'), backgroundColor: _teal, foregroundColor: Colors.white),
                          body: const MyBookingsScreen(),
                        ),
                      ),
                    ),
                  ),
                  _MenuItem(
                    icon: Icons.account_balance_wallet_outlined,
                    color: const Color(0xFF8B5CF6),
                    label: 'Wallet',
                    trailing: _WalletBadge(balance: _walletBalance),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WalletScreen()),
                      );
                      _loadUser(); // refresh balance on return
                    },
                  ),
                  _MenuItem(
                    icon: Icons.card_giftcard_outlined,
                    color: const Color(0xFFF59E0B),
                    label: 'Refer & Earn',
                    onTap: () => _showComingSoon('Refer & Earn'),
                  ),

                  const SizedBox(height: 12),

                  // ── Support Section ─────────────────────────────────
                  _SectionTitle('Support'),
                  _MenuItem(
                    icon: Icons.headset_mic_outlined,
                    color: const Color(0xFF0EA5E9),
                    label: 'Support',
                    onTap: () => _showComingSoon('Support'),
                  ),
                  _MenuItem(
                    icon: Icons.contact_mail_outlined,
                    color: const Color(0xFF22C55E),
                    label: 'Contact Us',
                    onTap: () => _showComingSoon('Contact Us'),
                  ),
                  _MenuItem(
                    icon: Icons.help_outline,
                    color: const Color(0xFF6366F1),
                    label: 'FAQ',
                    onTap: () => _showComingSoon('FAQ'),
                  ),

                  const SizedBox(height: 12),

                  // ── Legal Section ───────────────────────────────────
                  _SectionTitle('Legal'),
                  _MenuItem(
                    icon: Icons.privacy_tip_outlined,
                    color: const Color(0xFF64748B),
                    label: 'Privacy Policy',
                    onTap: () => _showComingSoon('Privacy Policy'),
                  ),

                  const SizedBox(height: 20),

                  // ── Logout ──────────────────────────────────────────
                  _LogoutButton(onTap: _logout),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Header
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final String name, email, phone;
  final File? image;
  final VoidCallback onPickImage, onEditName;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.phone,
    required this.image,
    required this.onPickImage,
    required this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: const Color(0xFF0EA5A4),
                backgroundImage: image != null ? FileImage(image!) : null,
                child: image == null
                    ? Text(initials, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700))
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onPickImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0EA5A4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onEditName,
                child: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0EA5A4)),
              ),
            ],
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(email, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(phone, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6B7280), letterSpacing: 0.5)),
      );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _MenuItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        trailing: trailing ?? const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _WalletBadge extends StatelessWidget {
  final double balance;
  const _WalletBadge({required this.balance});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Rs ${balance.toStringAsFixed(0)}',
            style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
}
