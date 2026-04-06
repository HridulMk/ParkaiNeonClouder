// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../services/parking_service.dart';

class ManagePricingScreen extends StatefulWidget {
  const ManagePricingScreen({super.key});

  @override
  State<ManagePricingScreen> createState() => _ManagePricingScreenState();
}

class _ManagePricingScreenState extends State<ManagePricingScreen> {
  List<Map<String, dynamic>> _spaces = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ParkingService.getParkingSpaces();
      setState(() {
        _spaces = data.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _editSpace(Map<String, dynamic> space) {
    final openCtrl = TextEditingController(text: (space['open_time'] ?? '08:00:00').toString());
    final closeCtrl = TextEditingController(text: (space['close_time'] ?? '22:00:00').toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: Text(space['name']?.toString() ?? 'Space',
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Hourly rate (€2.40/hr) is fixed by the system per reservation.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _dialogField(openCtrl, 'Open Time (HH:MM:SS)', Icons.access_time),
            const SizedBox(height: 12),
            _dialogField(closeCtrl, 'Close Time (HH:MM:SS)', Icons.access_time_filled),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.pop(ctx);
              await _updateSpace(space['id'] as int, openCtrl.text.trim(), closeCtrl.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.cyanAccent),
        filled: true,
        fillColor: const Color(0xFF0D1117),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.cyanAccent),
        ),
      ),
    );
  }

  Future<void> _deleteSpace(int spaceId, String spaceName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Delete Parking Space', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to permanently delete "$spaceName"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await ParkingService.deleteParkingSpace(spaceId);
    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parking space deleted'), backgroundColor: Colors.green),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: ${result['error']}'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _updateSpace(int spaceId, String openTime, String closeTime) async {
    final result = await ParkingService.updateParkingSpace(
      spaceId: spaceId,
      openTime: openTime,
      closeTime: closeTime,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Space updated'), backgroundColor: Colors.green),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${result['error']}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text('Manage Spaces', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF161B22),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : _spaces.isEmpty
                  ? const Center(child: Text('No spaces found.', style: TextStyle(color: Colors.white54)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _spaces.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final s = _spaces[i];
                        final isActive = s['is_active'] == true;
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161B22),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.local_parking,
                                  color: isActive ? Colors.cyanAccent : Colors.white30, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s['name']?.toString() ?? 'Space',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Slots: ${s['total_slots'] ?? 0}  •  ${isActive ? "Active" : "Inactive"}',
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${s['open_time'] ?? '--'}  →  ${s['close_time'] ?? '--'}',
                                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.cyanAccent),
                                onPressed: () => _editSpace(s),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () => _deleteSpace(s['id'] as int, s['name']?.toString() ?? 'this space'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
