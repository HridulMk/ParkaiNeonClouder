import 'package:flutter/material.dart';

import '../services/parking_service.dart';
import 'qr_code.dart';

class PaymentScreen extends StatefulWidget {
  final String slotName;
  final String slotId;
  final int reservationId;
  final double amount;
  /// If true, this is a final fee payment (after checkout), not a booking fee.
  final bool isFinalPayment;
  /// Expected check-in time from booking
  final DateTime? expectedCheckInTime;
  /// Estimated parking duration in minutes
  final int? estimatedDurationMins;

  const PaymentScreen({
    super.key,
    required this.slotName,
    required this.slotId,
    required this.reservationId,
    this.amount = 0,
    this.isFinalPayment = false,
    this.expectedCheckInTime,
    this.estimatedDurationMins,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedPayment = 'wallet';
  bool _isProcessing = false;
  double _walletBalance = 0;
  bool _walletLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    final res = await ParkingService.getWallet();
    if (!mounted) return;
    setState(() {
      _walletBalance = res['success'] == true
          ? (double.tryParse(res['wallet']?['balance']?.toString() ?? '0') ?? 0)
          : 0;
      _walletLoading = false;
    });
  }

  bool get _walletSufficient => _walletBalance >= widget.amount;

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);
    try {
      Map<String, dynamic> result;

      if (_selectedPayment == 'wallet') {
        result = widget.isFinalPayment
            ? await ParkingService.payFinalWithWallet(widget.reservationId)
            : await ParkingService.payBookingWithWallet(widget.reservationId);
      } else {
        // Standard (simulated) payment path
        result = widget.isFinalPayment
            ? await ParkingService.payFinal(widget.reservationId)
            : await ParkingService.payReservation(widget.reservationId);
      }

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (result['success'] == true) {
        final reservation = result['reservation'] as Map<String, dynamic>;
        if (widget.isFinalPayment) {
          Navigator.of(context).pop(true); // just go back on final payment
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => QRCodeScreen(
                slotName: widget.slotName,
                slotId: widget.slotId,
                reservationPk: widget.reservationId,
                reservationCode: reservation['reservation_id']?.toString() ?? 'PKG${widget.reservationId}',
                qrData: reservation['qr_code']?.toString(),
                initialStatus: reservation['status']?.toString() ?? 'reserved',
                initialFinalFee: reservation['final_fee'] == null
                    ? null
                    : double.tryParse(reservation['final_fee'].toString()),
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']?.toString() ?? 'Payment failed'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1117),
        elevation: 0,
        title: Text(widget.isFinalPayment ? 'Final Payment' : 'Booking Payment'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Summary ──────────────────────────────────────────────
            _SummaryCard(
              slotName: widget.slotName,
              amount: widget.amount,
              label: widget.isFinalPayment ? 'Final Fee' : 'Booking Fee',
            ),
            const SizedBox(height: 24),

            // ── Booking Preferences ───────────────────────────────────
            if (widget.expectedCheckInTime != null || widget.estimatedDurationMins != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('Booking Preferences',
                            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (widget.expectedCheckInTime != null)
                      _PreferenceRow(
                        icon: Icons.access_time,
                        label: 'Expected Check-in',
                        value: _formatDateTime(widget.expectedCheckInTime!),
                      ),
                    if (widget.estimatedDurationMins != null) ...[
                      if (widget.expectedCheckInTime != null) const SizedBox(height: 8),
                      _PreferenceRow(
                        icon: Icons.timer,
                        label: 'Duration',
                        value: _formatDuration(widget.estimatedDurationMins!),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Payment Method ────────────────────────────────────────
            const Text('Payment Method',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Wallet tile
            _walletLoading
                ? const Center(child: CircularProgressIndicator())
                : _WalletPaymentTile(
                    balance: _walletBalance,
                    sufficient: _walletSufficient,
                    selected: _selectedPayment == 'wallet',
                    onTap: _walletSufficient ? () => setState(() => _selectedPayment = 'wallet') : null,
                  ),
            const SizedBox(height: 10),

            _PaymentMethodTile(
              icon: Icons.credit_card,
              title: 'Credit / Debit Card',
              selected: _selectedPayment == 'card',
              onTap: () => setState(() => _selectedPayment = 'card'),
            ),
            const SizedBox(height: 10),
            _PaymentMethodTile(
              icon: Icons.phone_android,
              title: 'Mobile Payment',
              selected: _selectedPayment == 'mobile',
              onTap: () => setState(() => _selectedPayment = 'mobile'),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isProcessing ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent.shade700,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: Colors.grey.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.black87)),
                    )
                  : Text(
                      _selectedPayment == 'wallet'
                          ? 'Pay Rs ${widget.amount.toStringAsFixed(2)} from Wallet'
                          : 'Confirm Payment',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isProcessing ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary Card
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String slotName, label;
  final double amount;
  const _SummaryCard({required this.slotName, required this.amount, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Reservation Summary',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _Row('Slot:', slotName, valueColor: Colors.cyanAccent.shade200),
          const SizedBox(height: 8),
          _Row('Stage:', label),
          const Divider(color: Colors.grey, height: 16),
          _Row(label, 'Rs ${amount.toStringAsFixed(2)}',
              valueColor: Colors.tealAccent.shade100, valueFontSize: 18),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final double valueFontSize;
  const _Row(this.label, this.value, {this.valueColor, this.valueFontSize = 14});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: valueFontSize)),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Preference Row (for check-in time and duration)
// ─────────────────────────────────────────────────────────────────────────────
class _PreferenceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _PreferenceRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blue),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13)),
      ],
    );
  }
}

// Helper methods
String _formatDateTime(DateTime dt) {
  final now = DateTime.now();
  final isToday = dt.day == now.day && dt.month == now.month && dt.year == now.year;
  final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  if (isToday) return 'Today, $time';
  return '${dt.day}/${dt.month} $time';
}

String _formatDuration(int mins) {
  if (mins < 60) return '$mins mins';
  final hours = mins ~/ 60;
  final remainingMins = mins % 60;
  if (remainingMins == 0) return '$hours hour${hours > 1 ? 's' : ''}';
  return '$hours hr ${remainingMins} mins';
}

// ─────────────────────────────────────────────────────────────────────────────
// Wallet Payment Tile
// ─────────────────────────────────────────────────────────────────────────────
class _WalletPaymentTile extends StatelessWidget {
  final double balance;
  final bool sufficient, selected;
  final VoidCallback? onTap;
  const _WalletPaymentTile({required this.balance, required this.sufficient, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.cyanAccent.withOpacity(0.1) : const Color(0xFF1A1F2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.cyanAccent : (sufficient ? Colors.grey.shade800 : Colors.red.shade800),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.account_balance_wallet,
                color: selected ? Colors.cyanAccent : (sufficient ? Colors.white70 : Colors.red.shade300), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ParkAI Wallet',
                      style: TextStyle(
                          color: selected ? Colors.cyanAccent : Colors.white70,
                          fontSize: 16,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
                  Text(
                    sufficient
                        ? 'Balance: Rs ${balance.toStringAsFixed(2)}'
                        : 'Insufficient balance (Rs ${balance.toStringAsFixed(2)})',
                    style: TextStyle(
                        color: sufficient ? Colors.green.shade300 : Colors.red.shade300, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? Colors.cyanAccent : (sufficient ? Colors.white54 : Colors.red.shade300),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic Payment Method Tile
// ─────────────────────────────────────────────────────────────────────────────
class _PaymentMethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodTile({required this.icon, required this.title, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.cyanAccent.withOpacity(0.1) : const Color(0xFF1A1F2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? Colors.cyanAccent : Colors.grey.shade800, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.cyanAccent : Colors.white70, size: 24),
            const SizedBox(width: 12),
            Text(title,
                style: TextStyle(
                    color: selected ? Colors.cyanAccent : Colors.white70,
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
            const Spacer(),
            Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? Colors.cyanAccent : Colors.white54, size: 24),
          ],
        ),
      ),
    );
  }
}
