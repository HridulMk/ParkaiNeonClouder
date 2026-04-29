import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'notifications_screen.dart';
import 'welcome.dart';

const _bg = Color(0xFF070A12);
const _card = Color(0xFF101826);
const _card2 = Color(0xFF151F30);
const _line = Color(0xFF243247);
const _text = Color(0xFFF8FAFC);
const _muted = Color(0xFF94A3B8);
const _blue = Color(0xFF38BDF8);
const _green = Color(0xFF34D399);
const _amber = Color(0xFFFBBF24);
const _red = Color(0xFFFB7185);
const _violet = Color(0xFFA78BFA);

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _tabs = const [
    _AdminTab('Dashboard', Icons.insights_outlined),
    _AdminTab('Users', Icons.group_outlined),
    _AdminTab('Spaces', Icons.local_parking_outlined),
    _AdminTab('Security', Icons.shield_outlined),
    _AdminTab('Bookings', Icons.confirmation_number_outlined),
  ];

  int _tabIndex = 0;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String _adminName = 'Admin';
  String _adminEmail = 'admin@parkai.com';
  Timer? _timer;

  Map<String, dynamic> _metrics = {};
  Map<String, dynamic> _settings = {};
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _spaces = [];
  List<Map<String, dynamic>> _reservations = [];

  List<Map<String, dynamic>> get _pendingUsers => _users.where((u) => u['is_active'] != true).toList();
  List<Map<String, dynamic>> get _securityUsers => _users.where((u) => u['user_type'] == 'security').toList();
  List<Map<String, dynamic>> get _vendors => _users.where((u) => u['user_type'] == 'vendor').toList();

  @override
  void initState() {
    super.initState();
    _loadAll();
    NotificationService().initialize();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _loadAll(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _refreshing = true);
    }

    try {
      final profile = await AuthService.getUserProfile();
      final results = await Future.wait<dynamic>([
        AdminService.getAdminMetrics(),
        AdminService.getSettings(),
        AdminService.getUsers(),
        AdminService.getSpaces(),
        AdminService.getReservations(),
      ]);

      if (!mounted) return;
      final profileUser = profile['success'] == true ? Map<String, dynamic>.from(profile['user'] as Map) : <String, dynamic>{};
      setState(() {
        _adminName = _displayName(profileUser, fallback: 'Admin');
        _adminEmail = profileUser['email']?.toString() ?? 'admin@parkai.com';
        _metrics = Map<String, dynamic>.from(results[0] as Map);
        _settings = Map<String, dynamic>.from(results[1] as Map);
        _users = _mapList(results[2] as List);
        _spaces = _mapList(results[3] as List);
        _reservations = _mapList(results[4] as List);
        _loading = false;
        _refreshing = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _runAction(Future<void> Function() task, String message) async {
    try {
      await task();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: _green, behavior: SnackBarBehavior.floating),
      );
      await _loadAll(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: _red, behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(primary: _blue, secondary: _green, surface: _card),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _card2,
          labelStyle: const TextStyle(color: _muted),
          prefixIconColor: _muted,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _blue)),
        ),
      ),
      child: Scaffold(
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _blue))
              : Column(
                  children: [
                    _header(),
                    _tabsBar(),
                    if (_error != null) _errorBanner(),
                    Expanded(
                      child: RefreshIndicator(
                        color: _blue,
                        backgroundColor: _card,
                        onRefresh: () => _loadAll(),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
                          children: [_body()],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _blue.withValues(alpha: 0.28)),
            ),
            child: const Icon(Icons.admin_panel_settings_outlined, color: _blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ParkAI Admin', style: const TextStyle(color: _text, fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(_adminEmail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12)),
              ],
            ),
          ),
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: _blue, strokeWidth: 2)),
            ),
          _notificationButton(),
          const SizedBox(width: 8),
          _iconButton(Icons.refresh, () => _loadAll()),
          const SizedBox(width: 8),
          _iconButton(Icons.logout, () {
            _logout();
          }),
        ],
      ),
    );
  }

  Widget _tabsBar() {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final selected = index == _tabIndex;
          final tab = _tabs[index];
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => setState(() => _tabIndex = index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? _blue : _card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected ? _blue : _line),
              ),
              child: Row(
                children: [
                  Icon(tab.icon, size: 17, color: selected ? _bg : _muted),
                  const SizedBox(width: 7),
                  Text(tab.label, style: TextStyle(color: selected ? _bg : _text, fontWeight: FontWeight.w900, fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _body() {
    switch (_tabIndex) {
      case 1:
        return _usersPanel();
      case 2:
        return _spacesPanel();
      case 3:
        return _securityPanel();
      case 4:
        return _bookingsPanel();
      default:
        return _dashboardPanel();
    }
  }

  Widget _dashboardPanel() {
    final bookings = [
      _ChartSlice('Pending', _intMetric('pending_reservations'), _amber),
      _ChartSlice('Active', _intMetric('active_reservations'), _blue),
      _ChartSlice('Done', _intMetric('completed_reservations'), _green),
      _ChartSlice('Cancelled', _intMetric('cancelled_reservations'), _red),
    ];
    final users = [
      _ChartSlice('Customers', _intMetric('total_customers'), _blue),
      _ChartSlice('Vendors', _intMetric('total_vendors'), _green),
      _ChartSlice('Security', _intMetric('total_security'), _amber),
      _ChartSlice('Admins', _intMetric('total_admins'), _violet),
    ];
    final freeSlots = math.max(0, _intMetric('total_slots') - _intMetric('occupied_slots')).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heroCard(),
        const SizedBox(height: 12),
        _kpiGrid(),
        const SizedBox(height: 12),
        _chartCard('Revenue Trend', 'Total revenue and platform commission', SizedBox(
          height: 140,
          child: CustomPaint(
            painter: _SparklinePainter(values: _sparkValues(), color: _green, fillColor: _green.withValues(alpha: 0.12)),
            child: const SizedBox.expand(),
          ),
        )),
        const SizedBox(height: 12),
        _chartCard('Users by Role', '${_intMetric('total_users')} accounts', _donut(users)),
        const SizedBox(height: 12),
        _chartCard('Booking Status', '${_reservations.length} reservations', _bars(bookings)),
        const SizedBox(height: 12),
        _chartCard('Slot Utilization', '${_intMetric('total_slots')} total slots', _bars([
          _ChartSlice('Occupied', _intMetric('occupied_slots'), _amber),
          _ChartSlice('Free', freeSlots, _blue),
          _ChartSlice('Active', _intMetric('active_slots'), _green),
        ])),
        const SizedBox(height: 12),
        _quickActions(),
        const SizedBox(height: 12),
        _sectionTitle('Needs Attention'),
        const SizedBox(height: 10),
        if (_pendingUsers.isEmpty)
          _emptyPanel('No pending users', Icons.verified_outlined)
        else
          ..._pendingUsers.take(4).map(_approvalTile),
      ],
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(24), border: Border.all(color: _line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hello, $_adminName', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('Control users, spaces, security, pricing, and bookings.', style: TextStyle(color: _muted, fontSize: 13)),
                ]),
              ),
              _statusPill(_error == null ? 'Live' : 'Issue', _error == null ? _green : _red),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _heroNumber('Revenue', 'Rs ${_textValue('total_revenue', '0.00')}')),
              Container(width: 1, height: 42, color: _line),
              Expanded(child: _heroNumber('Commission', '${_settings['commission_percentage'] ?? _metrics['commission_percentage'] ?? '10.00'}%')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiGrid() {
    final cards = [
      _Kpi('Users', _textValue('total_users', '0'), Icons.group_outlined, _blue),
      _Kpi('Spaces', _textValue('total_spaces', '0'), Icons.local_parking_outlined, _green),
      _Kpi('Bookings', _textValue('total_reservations', '0'), Icons.confirmation_number_outlined, _amber),
      _Kpi('Pending', _textValue('pending_users', '${_pendingUsers.length}'), Icons.pending_actions_outlined, _red),
    ];
    return GridView.builder(
      itemCount: cards.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.55),
      itemBuilder: (_, index) {
        final item = cards[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(item.icon, color: item.color),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontSize: 24, fontWeight: FontWeight.w900)),
                Text(item.label, style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _quickActions() {
    return _panel('Quick Actions', GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.85,
      children: [
        _actionTile('Add User', Icons.person_add_alt_1, _blue, () => _showUserDialog()),
        _actionTile('Add Space', Icons.add_business_outlined, _green, () => _showSpaceDialog()),
        _actionTile('Commission', Icons.percent, _violet, _showCommissionDialog),
        _actionTile('Approvals', Icons.fact_check_outlined, _amber, () => setState(() => _tabIndex = 1)),
      ],
    ));
  }

  Widget _usersPanel() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _pageHeader('Users & Approvals', 'Approve, reject, create, edit, and remove accounts.', [_pillButton('Add User', Icons.person_add_alt_1, () => _showUserDialog())]),
      const SizedBox(height: 12),
      _sectionTitle('Pending Approval'),
      const SizedBox(height: 10),
      if (_pendingUsers.isEmpty) _emptyPanel('No users waiting', Icons.done_all) else ..._pendingUsers.map(_approvalTile),
      const SizedBox(height: 14),
      _sectionTitle('All Users'),
      const SizedBox(height: 10),
      if (_users.isEmpty) _emptyPanel('No users found', Icons.group_off_outlined) else ..._users.map(_userTile),
    ]);
  }

  Widget _spacesPanel() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _pageHeader('Spaces & Pricing', 'Manage spaces, activity, hourly rates, booking fees, and commission.', [
        _pillButton('Add Space', Icons.add_business_outlined, () => _showSpaceDialog()),
        _pillButton('Commission', Icons.percent, _showCommissionDialog),
      ]),
      const SizedBox(height: 12),
      if (_spaces.isEmpty) _emptyPanel('No parking spaces found', Icons.local_parking_outlined) else ..._spaces.map(_spaceTile),
    ]);
  }

  Widget _securityPanel() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _pageHeader('Security', 'Assign guards and manage security access.', [_pillButton('Add Guard', Icons.person_add_alt_1, () => _showUserDialog(defaultType: 'security'))]),
      const SizedBox(height: 12),
      _chartCard('Guard Coverage', '${_securityUsers.length} guards across ${_spaces.length} spaces', _bars([
        _ChartSlice('Guards', _securityUsers.length, _blue),
        _ChartSlice('Spaces', _spaces.length, _green),
        _ChartSlice('Unassigned', _securityUsers.where((u) => u['assigned_parking_space_id'] == null).length, _red),
      ])),
      const SizedBox(height: 12),
      if (_securityUsers.isEmpty) _emptyPanel('No guards yet', Icons.shield_outlined) else ..._securityUsers.map(_userTile),
    ]);
  }

  Widget _bookingsPanel() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _pageHeader('Bookings', 'Monitor reservations and cancel active bookings.', const []),
      const SizedBox(height: 12),
      _chartCard('Reservation Health', '${_reservations.length} bookings', _bars([
        _ChartSlice('Pending', _intMetric('pending_reservations'), _amber),
        _ChartSlice('Active', _intMetric('active_reservations'), _blue),
        _ChartSlice('Done', _intMetric('completed_reservations'), _green),
        _ChartSlice('Cancelled', _intMetric('cancelled_reservations'), _red),
      ])),
      const SizedBox(height: 12),
      if (_reservations.isEmpty) _emptyPanel('No bookings found', Icons.event_busy_outlined) else ..._reservations.map(_bookingTile),
    ]);
  }

  Widget _approvalTile(Map<String, dynamic> user) {
    return _recordTile(
      icon: Icons.pending_actions_outlined,
      color: _amber,
      title: _displayName(user),
      subtitle: '${user['user_type'] ?? 'user'} - ${user['email'] ?? ''}',
      status: 'Waiting',
      statusColor: _amber,
      actions: [
        _miniButton(Icons.close, _red, () => _confirmReject(user)),
        _miniButton(Icons.check, _green, () => _runAction(() async => AdminService.approveUser(user['id'] as int), 'User approved')),
      ],
    );
  }

  Widget _userTile(Map<String, dynamic> user) {
    final role = user['user_type']?.toString() ?? 'customer';
    final active = user['is_active'] == true;
    return _recordTile(
      icon: _roleIcon(role),
      color: _roleColor(role),
      title: _displayName(user),
      subtitle: '$role - ${user['email'] ?? ''}${role == 'security' ? ' - ${user['assigned_parking_space_name'] ?? 'Unassigned'}' : ''}',
      status: active ? 'Active' : 'Pending',
      statusColor: active ? _green : _red,
      actions: [
        _miniButton(Icons.edit_outlined, _blue, () => _showUserDialog(existing: user)),
        _miniButton(active ? Icons.block : Icons.check_circle_outline, active ? _amber : _green, () {
          _runAction(() async => AdminService.updateUser(user['id'] as int, {'is_active': !active}), active ? 'User deactivated' : 'User activated');
        }),
        _miniButton(Icons.delete_outline, _red, () => _confirmDeleteUser(user)),
      ],
    );
  }

  Widget _spaceTile(Map<String, dynamic> space) {
    final active = space['is_active'] == true;
    return _recordTile(
      icon: Icons.local_parking_outlined,
      color: active ? _green : _muted,
      title: space['name']?.toString() ?? 'Parking Space',
      subtitle: '${space['vendor_name'] ?? 'No vendor'} - ${space['total_slots'] ?? 0} slots - Rs ${space['hourly_rate'] ?? '0.00'}/hr - Fee Rs ${space['booking_fee'] ?? '0.00'}',
      status: active ? 'Active' : 'Inactive',
      statusColor: active ? _green : _muted,
      actions: [
        _miniButton(Icons.tune, _blue, () => _showSpaceDialog(existing: space)),
        _miniButton(active ? Icons.visibility_off_outlined : Icons.visibility_outlined, active ? _amber : _green, () {
          _runAction(() async => AdminService.setSpaceActive(space['id'] as int, !active), active ? 'Space deactivated' : 'Space activated');
        }),
        _miniButton(Icons.delete_outline, _red, () => _confirmDeleteSpace(space)),
      ],
    );
  }

  Widget _bookingTile(Map<String, dynamic> reservation) {
    final status = reservation['status']?.toString() ?? 'unknown';
    final cancellable = status == 'pending_booking_payment' || status == 'reserved' || status == 'checked_in';
    return _recordTile(
      icon: _bookingIcon(status),
      color: _bookingColor(status),
      title: reservation['reservation_id']?.toString() ?? 'Reservation',
      subtitle: '${reservation['user_full_name'] ?? reservation['user_name'] ?? 'Customer'} - ${reservation['parking_space_name'] ?? 'Space'} - ${reservation['slot_label'] ?? 'Slot'} - Rs ${reservation['total_charged'] ?? reservation['amount'] ?? '0.00'}',
      status: _humanize(status),
      statusColor: _bookingColor(status),
      actions: [
        if (cancellable) _miniButton(Icons.cancel_outlined, _red, () => _showCancelBookingDialog(reservation)),
      ],
    );
  }

  Widget _recordTile({required IconData icon, required Color color, required String title, required String subtitle, required String status, required Color statusColor, required List<Widget> actions}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
      child: Column(children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 21)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 12, height: 1.25)),
          ])),
          const SizedBox(width: 8),
          _statusPill(status, statusColor),
        ]),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
        ],
      ]),
    );
  }

  Widget _chartCard(String title, String subtitle, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(24), border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 16),
        child,
      ]),
    );
  }

  Widget _donut(List<_ChartSlice> data) {
    return Row(children: [
      SizedBox(width: 124, height: 124, child: CustomPaint(painter: _DonutPainter(data))),
      const SizedBox(width: 16),
      Expanded(child: Column(children: data.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(item.label, style: const TextStyle(color: _muted, fontSize: 12))),
            Text('${item.value}', style: const TextStyle(color: _text, fontWeight: FontWeight.w800)),
          ]),
        );
      }).toList())),
    ]);
  }

  Widget _bars(List<_ChartSlice> data) {
    final maxValue = data.fold<int>(1, (max, item) => item.value > max ? item.value : max);
    return Column(children: data.map((item) {
      final factor = item.value / maxValue;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          SizedBox(width: 82, child: Text(item.label, style: const TextStyle(color: _muted, fontSize: 12))),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: factor.clamp(0.0, 1.0).toDouble(), minHeight: 10, color: item.color, backgroundColor: _line))),
          const SizedBox(width: 10),
          SizedBox(width: 30, child: Text('${item.value}', textAlign: TextAlign.right, style: const TextStyle(color: _text, fontWeight: FontWeight.w800))),
        ]),
      );
    }).toList());
  }

  Widget _panel(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(24), border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _pageHeader(String title, String subtitle, List<Widget> actions) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(24), border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: _text, fontSize: 21, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: _muted, fontSize: 13, height: 1.35)),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ]),
    );
  }

  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: _red.withValues(alpha: 0.28))),
      child: Row(children: [
        const Icon(Icons.error_outline, color: _red, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(_error!, style: const TextStyle(color: _text, fontSize: 12, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(color: _text, fontSize: 17, fontWeight: FontWeight.w900));

  Widget _emptyPanel(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _line)),
      child: Column(children: [
        Icon(icon, color: _muted, size: 34),
        const SizedBox(height: 8),
        Text(message, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _heroNumber(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }

  Widget _pillButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: ElevatedButton.styleFrom(backgroundColor: _blue, foregroundColor: _bg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)), textStyle: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget _actionTile(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
        child: Row(children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: 12))),
        ]),
      ),
    );
  }

  Widget _miniButton(IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 18)),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Container(width: 38, height: 38, decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(13), border: Border.all(color: _line)), child: Icon(icon, color: _text, size: 19)),
    );
  }

  Widget _notificationButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _iconButton(Icons.notifications_outlined, () {
          _openNotifications();
        }),
        Positioned(
          right: -3,
          top: -4,
          child: AnimatedBuilder(
            animation: NotificationService(),
            builder: (context, _) {
              final count = NotificationService().unreadCount;
              if (count == 0) return const SizedBox.shrink();
              return Container(
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _red,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _bg, width: 2),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 9, height: 1, fontWeight: FontWeight.w900),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showUserDialog({Map<String, dynamic>? existing, String defaultType = 'customer'}) async {
    final editing = existing != null;
    final nameCtrl = TextEditingController(text: editing ? _displayName(existing) : '');
    final usernameCtrl = TextEditingController(text: existing?['username']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: existing?['email']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final passwordCtrl = TextEditingController();
    String userType = existing?['user_type']?.toString() ?? defaultType;
    bool active = existing?['is_active'] == true || !editing;
    int? assignedSpaceId = _intValue(existing?['assigned_parking_space_id']);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: _card,
          title: Text(editing ? 'Edit User' : 'Add User'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _field(nameCtrl, 'Full name', Icons.badge_outlined),
                _field(usernameCtrl, 'Username', Icons.alternate_email, enabled: !editing),
                _field(emailCtrl, 'Email', Icons.mail_outline),
                _field(phoneCtrl, 'Phone', Icons.phone_outlined),
                if (!editing) _field(passwordCtrl, 'Password', Icons.lock_outline, obscure: true),
                DropdownButtonFormField<String>(
                  value: userType,
                  decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.admin_panel_settings_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'customer', child: Text('Customer')),
                    DropdownMenuItem(value: 'vendor', child: Text('Vendor')),
                    DropdownMenuItem(value: 'security', child: Text('Security')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (value) => setDialogState(() {
                    userType = value ?? 'customer';
                    if (userType != 'security') assignedSpaceId = null;
                  }),
                ),
                const SizedBox(height: 12),
                if (userType == 'security')
                  DropdownButtonFormField<int>(
                    value: assignedSpaceId,
                    decoration: const InputDecoration(labelText: 'Assigned space', prefixIcon: Icon(Icons.local_parking_outlined)),
                    items: _spaces.map((space) => DropdownMenuItem<int>(value: space['id'] as int, child: Text(space['name']?.toString() ?? 'Space ${space['id']}'))).toList(),
                    onChanged: (value) => setDialogState(() => assignedSpaceId = value),
                  ),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active account'), value: active, onChanged: (value) => setDialogState(() => active = value)),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (userType == 'security' && assignedSpaceId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assign a parking space for security users')));
                  return;
                }
                final body = <String, dynamic>{
                  'full_name': nameCtrl.text.trim(),
                  'username': usernameCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'user_type': userType,
                  'is_active': active,
                  'assigned_parking_space': assignedSpaceId,
                };
                if (!editing || passwordCtrl.text.trim().isNotEmpty) body['password'] = passwordCtrl.text.trim();
                Navigator.pop(dialogContext);
                _runAction(() async {
                  if (editing) {
                    await AdminService.updateUser(existing['id'] as int, body);
                  } else {
                    await AdminService.createUser(body);
                  }
                }, editing ? 'User updated' : 'User created');
              },
              child: Text(editing ? 'Save' : 'Create'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _showSpaceDialog({Map<String, dynamic>? existing}) async {
    final editing = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final locationCtrl = TextEditingController(text: existing?['location']?.toString() ?? existing?['address']?.toString() ?? '');
    final slotsCtrl = TextEditingController(text: existing?['total_slots']?.toString() ?? '10');
    final openCtrl = TextEditingController(text: _shortTime(existing?['open_time']?.toString()) ?? '08:00');
    final closeCtrl = TextEditingController(text: _shortTime(existing?['close_time']?.toString()) ?? '22:00');
    final hourlyCtrl = TextEditingController(text: existing?['hourly_rate']?.toString() ?? '30.00');
    final bookingCtrl = TextEditingController(text: existing?['booking_fee']?.toString() ?? '20.00');
    int? vendorId = _intValue(existing?['vendor']);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: _card,
          title: Text(editing ? 'Manage Space' : 'Add Parking Space'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _field(nameCtrl, 'Space name', Icons.local_parking_outlined),
                _field(locationCtrl, 'Location', Icons.place_outlined),
                if (!editing) _field(slotsCtrl, 'Number of slots', Icons.grid_view_outlined, keyboardType: TextInputType.number),
                DropdownButtonFormField<int>(
                  value: vendorId,
                  decoration: const InputDecoration(labelText: 'Vendor', prefixIcon: Icon(Icons.store_outlined)),
                  items: _vendors.map((vendor) => DropdownMenuItem<int>(value: vendor['id'] as int, child: Text(_displayName(vendor)))).toList(),
                  onChanged: (value) => setDialogState(() => vendorId = value),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field(openCtrl, 'Open', Icons.access_time)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(closeCtrl, 'Close', Icons.access_time_filled)),
                ]),
                Row(children: [
                  Expanded(child: _field(hourlyCtrl, 'Hourly Rs', Icons.currency_rupee, keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(bookingCtrl, 'Fee Rs', Icons.payments_outlined, keyboardType: TextInputType.number)),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _runAction(() async {
                  if (editing) {
                    await AdminService.updateSpace(existing['id'] as int, {
                      'name': nameCtrl.text.trim(),
                      'location': locationCtrl.text.trim(),
                      'address': locationCtrl.text.trim(),
                      'vendor': vendorId,
                      'open_time': _normalizeTime(openCtrl.text),
                      'close_time': _normalizeTime(closeCtrl.text),
                      'hourly_rate': hourlyCtrl.text.trim(),
                      'booking_fee': bookingCtrl.text.trim(),
                    });
                  } else {
                    final fields = {
                      'name': nameCtrl.text.trim(),
                      'location': locationCtrl.text.trim(),
                      'number_of_slots': slotsCtrl.text.trim(),
                      'open_time': _normalizeTime(openCtrl.text),
                      'close_time': _normalizeTime(closeCtrl.text),
                      'hourly_rate': hourlyCtrl.text.trim(),
                      'booking_fee': bookingCtrl.text.trim(),
                    };
                    if (vendorId != null) fields['vendor'] = vendorId.toString();
                    await AdminService.createSpace(fields);
                  }
                }, editing ? 'Space updated' : 'Space created');
              },
              child: Text(editing ? 'Save' : 'Create'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _showCommissionDialog() async {
    final ctrl = TextEditingController(text: '${_settings['commission_percentage'] ?? _metrics['commission_percentage'] ?? '10.00'}');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Platform Commission'),
        content: _field(ctrl, 'Commission percentage', Icons.percent, keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(onPressed: () {
            Navigator.pop(dialogContext);
            _runAction(() async => AdminService.updateSettings(commissionPercentage: ctrl.text.trim()), 'Commission updated');
          }, child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _showCancelBookingDialog(Map<String, dynamic> reservation) async {
    final ctrl = TextEditingController(text: 'Cancelled by administrator');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Cancel Booking'),
        content: _field(ctrl, 'Reason', Icons.notes_outlined),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Keep')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: _bg), onPressed: () {
            Navigator.pop(dialogContext);
            _runAction(() async => AdminService.cancelReservation(reservation['id'] as int, ctrl.text.trim()), 'Booking cancelled');
          }, child: const Text('Cancel Booking')),
        ],
      ),
    );
  }

  Future<void> _confirmReject(Map<String, dynamic> user) async {
    final ctrl = TextEditingController(text: 'Your account was rejected by an administrator.');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        title: Text('Reject ${_displayName(user)}?'),
        content: _field(ctrl, 'Reason', Icons.notes_outlined),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: _bg), onPressed: () {
            Navigator.pop(dialogContext);
            _runAction(() async => AdminService.rejectUser(user['id'] as int, reason: ctrl.text.trim()), 'User rejected');
          }, child: const Text('Reject')),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteSpace(Map<String, dynamic> space) async {
    if (await _confirm('Delete Parking Space', 'Delete "${space['name']}" and its slots?')) {
      _runAction(() async => AdminService.deleteSpace(space['id'] as int), 'Space deleted');
    }
  }

  Future<void> _confirmDeleteUser(Map<String, dynamic> user) async {
    if (await _confirm('Delete User', 'Delete "${_displayName(user)}" permanently?')) {
      _runAction(() async => AdminService.deleteUser(user['id'] as int), 'User deleted');
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _card,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _red, foregroundColor: _bg), onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    return result == true;
  }

  Widget _field(TextEditingController controller, String label, IconData icon, {bool obscure = false, bool enabled = true, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        enabled: enabled,
        keyboardType: keyboardType,
        style: const TextStyle(color: _text),
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()), (route) => false);
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    if (!mounted) return;
    await NotificationService().fetchHistory();
  }

  List<double> _sparkValues() {
    final revenue = _doubleFrom(_metrics['total_revenue']);
    if (revenue <= 0) return const [8, 10, 9, 13, 12, 16, 15, 18];
    return List.generate(8, (i) => revenue * (0.45 + (i * 0.075)) + (i.isEven ? revenue * 0.06 : 0));
  }

  int _intMetric(String key) => _intFrom(_metrics[key]);
  String _textValue(String key, String fallback) => _metrics[key]?.toString() ?? fallback;

  static List<Map<String, dynamic>> _mapList(List rows) => rows.map((e) => Map<String, dynamic>.from(e as Map)).toList();

  static String _displayName(Map<String, dynamic> user, {String fallback = 'User'}) {
    final display = user['display_name']?.toString();
    if (display != null && display.trim().isNotEmpty) return display;
    final full = user['full_name']?.toString();
    if (full != null && full.trim().isNotEmpty) return full;
    final first = user['first_name']?.toString() ?? '';
    final last = user['last_name']?.toString() ?? '';
    final joined = '$first $last'.trim();
    if (joined.isNotEmpty) return joined;
    return user['username']?.toString() ?? fallback;
  }

  static int _intFrom(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _doubleFrom(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _intValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static String _humanize(String value) {
    return value.replaceAll('_', ' ').split(' ').map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}').join(' ');
  }

  static String _normalizeTime(String value) {
    final trimmed = value.trim();
    return trimmed.length == 5 ? '$trimmed:00' : trimmed;
  }

  static String? _shortTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return value.length >= 5 ? value.substring(0, 5) : value;
  }

  static Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return _violet;
      case 'vendor':
        return _green;
      case 'security':
        return _amber;
      default:
        return _blue;
    }
  }

  static IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings_outlined;
      case 'vendor':
        return Icons.store_outlined;
      case 'security':
        return Icons.shield_outlined;
      default:
        return Icons.person_outline;
    }
  }

  static Color _bookingColor(String status) {
    switch (status) {
      case 'completed':
        return _green;
      case 'cancelled':
        return _red;
      case 'checked_in':
      case 'reserved':
        return _blue;
      case 'checked_out':
        return _violet;
      default:
        return _amber;
    }
  }

  static IconData _bookingIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'checked_in':
        return Icons.login;
      case 'checked_out':
        return Icons.logout;
      default:
        return Icons.event_available_outlined;
    }
  }
}

class _AdminTab {
  final String label;
  final IconData icon;
  const _AdminTab(this.label, this.icon);
}

class _Kpi {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Kpi(this.label, this.value, this.icon, this.color);
}

class _ChartSlice {
  final String label;
  final int value;
  final Color color;
  const _ChartSlice(this.label, this.value, this.color);
}

class _DonutPainter extends CustomPainter {
  final List<_ChartSlice> data;
  const _DonutPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final stroke = radius * 0.22;
    final rect = Rect.fromCircle(center: center, radius: radius - stroke / 2);
    final total = data.fold<int>(0, (sum, item) => sum + item.value);
    final basePaint = Paint()
      ..color = _line
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, basePaint);
    if (total > 0) {
      double start = -math.pi / 2;
      for (final item in data) {
        if (item.value <= 0) continue;
        final sweep = (item.value / total) * math.pi * 2;
        canvas.drawArc(rect, start, sweep - 0.04, false, Paint()
          ..color = item.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round);
        start += sweep;
      }
    }
    final textPainter = TextPainter(
      text: TextSpan(text: '$total', style: const TextStyle(color: _text, fontSize: 22, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.data != data;
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final Color fillColor;
  const _SparklinePainter({required this.values, required this.color, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final minValue = values.reduce((a, b) => math.min(a, b).toDouble());
    final maxValue = values.reduce((a, b) => math.max(a, b).toDouble());
    final range = math.max(1.0, maxValue - minValue).toDouble();
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? 0.0 : (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] - minValue) / range) * (size.height * 0.72) - size.height * 0.14;
      points.add(Offset(x, y));
    }
    final gridPaint = Paint()
      ..color = _line.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * (i + 1) / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = fillColor);
    canvas.drawPath(path, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);
    for (final point in points) {
      canvas.drawCircle(point, 3.2, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color || oldDelegate.fillColor != fillColor;
  }
}
