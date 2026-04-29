// lib/widgets/admin/mini_chart_card.dart
import 'package:flutter/material.dart';

class MiniChartCard extends StatelessWidget {
  final String title;
  final Map<String, int> data;
  final bool loading;

  const MiniChartCard({
    super.key,
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
          const SizedBox(height: 16),
          if (loading)
            const SizedBox(
              height: 100,
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.purpleAccent,
                  strokeWidth: 2.5,
                ),
              ),
            )
          else
            ...data.entries.map((entry) {
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