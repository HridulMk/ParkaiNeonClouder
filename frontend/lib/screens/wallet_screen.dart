import 'package:flutter/material.dart';
import '../services/parking_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  static const _teal = Color(0xFF0EA5A4);


  Map<String, dynamic>? _wallet;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final res = await ParkingService.getWallet();
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() { _wallet = res['wallet'] as Map<String, dynamic>; _loading = false; });
    } else {
      setState(() { _error = res['error']?.toString(); _loading = false; });
    }
  }

  double get _balance => double.tryParse(_wallet?['balance']?.toString() ?? '0') ?? 0;

  List<Map<String, dynamic>> get _transactions {
    final raw = _wallet?['transactions'];
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    return [];
  }

  Future<void> _showAddMoney() async {
    final amounts = [100, 200, 500, 1000, 2000, 5000];
    double? selected;
    final customCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Money to Wallet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: amounts.map((a) {
                  final isSelected = selected == a.toDouble();
                  return GestureDetector(
                    onTap: () { setModal(() { selected = a.toDouble(); customCtrl.clear(); }); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? _teal : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? _teal : const Color(0xFFE5E7EB)),
                      ),
                      child: Text('Rs $a',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : const Color(0xFF374151))),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: customCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Or enter custom amount',
                  prefixText: 'Rs ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => setModal(() => selected = double.tryParse(v)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: selected == null || selected! <= 0
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _topUp(selected!);
                        },
                  child: Text('Add Rs ${selected?.toStringAsFixed(0) ?? '—'}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _topUp(double amount) async {
    final res = await ParkingService.topUpWallet(amount);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() => _wallet = res['wallet'] as Map<String, dynamic>);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rs ${amount.toStringAsFixed(0)} added to wallet!'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error'] ?? 'Top-up failed'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      appBar: AppBar(
        title: const Text('My Wallet'),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    children: [
                      // ── Balance Card ──────────────────────────────────
                      _BalanceCard(balance: _balance, onAddMoney: _showAddMoney),
                      const SizedBox(height: 20),

                      // ── Quick Add ─────────────────────────────────────
                      _QuickAddRow(onTap: _topUp),
                      const SizedBox(height: 20),

                      // ── Offers ────────────────────────────────────────
                      const _SectionLabel('Offers & Benefits'),
                      const SizedBox(height: 10),
                      const _OffersSection(),
                      const SizedBox(height: 20),

                      // ── Features ──────────────────────────────────────
                      const _SectionLabel('Why use ParkAI Wallet?'),
                      const SizedBox(height: 10),
                      const _FeaturesSection(),
                      const SizedBox(height: 20),

                      // ── Transactions ──────────────────────────────────
                      _SectionLabel('Transaction History (${_transactions.length})'),
                      const SizedBox(height: 10),
                      if (_transactions.isEmpty)
                        _EmptyCard('No transactions yet. Add money to get started!')
                      else
                        ..._transactions.map((t) => _TransactionTile(tx: t)),
                    ],
                  ),
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Balance Card
// ─────────────────────────────────────────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  final double balance;
  final VoidCallback onAddMoney;
  const _BalanceCard({required this.balance, required this.onAddMoney});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5A4), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x330EA5A4), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Rs ${balance.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAddMoney,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Money', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0EA5A4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Add Row
// ─────────────────────────────────────────────────────────────────────────────
class _QuickAddRow extends StatelessWidget {
  final Future<void> Function(double) onTap;
  const _QuickAddRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final amounts = [100, 200, 500, 1000];
    return Row(
      children: amounts.map((a) => Expanded(
        child: GestureDetector(
          onTap: () => onTap(a.toDouble()),
          child: Container(
            margin: EdgeInsets.only(right: a != amounts.last ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Column(
              children: [
                const Icon(Icons.add_circle_outline, color: Color(0xFF0EA5A4), size: 20),
                const SizedBox(height: 4),
                Text('Rs $a', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Offers Section
// ─────────────────────────────────────────────────────────────────────────────
class _OffersSection extends StatelessWidget {
  const _OffersSection();

  @override
  Widget build(BuildContext context) {
    final offers = [
      _Offer('10% Cashback', 'Get 10% cashback on your first wallet top-up above Rs 500', Icons.percent, const Color(0xFF22C55E)),
      _Offer('Free Booking', 'Book 5 slots and get your 6th booking fee free', Icons.card_giftcard, const Color(0xFFF59E0B)),
      _Offer('Weekend Deal', 'Flat Rs 20 off on weekend bookings paid via wallet', Icons.weekend, const Color(0xFF6366F1)),
    ];
    return Column(
      children: offers.map((o) => _OfferCard(offer: o)).toList(),
    );
  }
}

class _Offer {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  const _Offer(this.title, this.subtitle, this.icon, this.color);
}

class _OfferCard extends StatelessWidget {
  final _Offer offer;
  const _OfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: offer.color.withValues(alpha: 0.3)),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: offer.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(offer.icon, color: offer.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(offer.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 3),
                Text(offer.subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: offer.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Claim', style: TextStyle(color: offer.color, fontWeight: FontWeight.w700, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Features Section
// ─────────────────────────────────────────────────────────────────────────────
class _Feature {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _Feature(this.icon, this.color, this.title, this.subtitle);
}

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection();

  @override
  Widget build(BuildContext context) {
    final features = [
      _Feature(Icons.flash_on, const Color(0xFF0EA5A4), 'Instant Payment', 'Pay booking & final fees instantly without re-entering card details'),
      _Feature(Icons.security, const Color(0xFF22C55E), 'Secure & Safe', 'Your wallet balance is encrypted and protected'),
      _Feature(Icons.history, const Color(0xFF6366F1), 'Full History', 'Track every top-up and payment in one place'),
      _Feature(Icons.savings, const Color(0xFFF59E0B), 'Save More', 'Exclusive wallet-only offers and cashback deals'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: features.map((f) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: f.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(f.icon, color: f.color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(f.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 3),
            Text(f.subtitle, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      )).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transaction Tile
// ─────────────────────────────────────────────────────────────────────────────
class _TransactionTile extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final type = tx['transaction_type']?.toString() ?? '';
    final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0;
    final desc = tx['description']?.toString() ?? '';
    final date = tx['created_at']?.toString() ?? '';

    final isCredit = type == 'topup' || type == 'refund';
    final color = isCredit ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final icon = type == 'topup'
        ? Icons.arrow_downward
        : type == 'refund'
            ? Icons.undo
            : Icons.arrow_upward;

    String formattedDate = date;
    try {
      final dt = DateTime.parse(date).toLocal();
      formattedDate = '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc.isNotEmpty ? desc : type.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(formattedDate, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11)),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'} Rs ${amount.toStringAsFixed(2)}',
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14),
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
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827)));
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard(this.message);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6)],
        ),
        child: Text(message, style: const TextStyle(color: Color(0xFF6B7280))),
      );
}
