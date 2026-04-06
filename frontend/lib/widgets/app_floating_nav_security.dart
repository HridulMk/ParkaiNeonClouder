import 'dart:ui';
import 'package:flutter/material.dart';
import '../screens/cctv_cameras.dart';
import '../screens/logs_screen.dart';
import '../screens/gate_camera.dart';

class AppFloatingNavSecurity extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const AppFloatingNavSecurity({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final compact = width < 380;
            final iconSize = compact ? 20.0 : 22.0;
            final labelSize = compact ? 10.0 : 11.0;

            return SizedBox(
              height: 86,
              child: Stack(
                clipBehavior: Clip.none,
                children: [

                  // 🔹 Background Glass Effect
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          height: 66,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.transparent.withOpacity(0.16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 🔹 Nav Items
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8.5,
                    child: Row(
                      children: [
                        Expanded(
                          child: _NavButton(
                            icon: Icons.videocam_outlined,
                            label: 'CCTV',
                            selected: selectedIndex == 0,
                            iconSize: iconSize,
                            labelSize: labelSize,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CCTVCamerasScreen()),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: _NavButton(
                            icon: Icons.qr_code_scanner_outlined,
                            label: 'Scan',
                            selected: selectedIndex == 1,
                            iconSize: iconSize,
                            labelSize: labelSize,
                            onTap: () => onTap(1),
                          ),
                        ),
                        SizedBox(width: compact ? 72 : 84),
                        Expanded(
                          child: _NavButton(
                            icon: Icons.history_toggle_off_outlined,
                            label: 'Logs',
                            selected: selectedIndex == 3,
                            iconSize: iconSize,
                            labelSize: labelSize,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LogsScreen()),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: _NavButton(
                            icon: Icons.smart_toy_outlined,
                            label: 'AI',
                            selected: selectedIndex == 4,
                            iconSize: iconSize,
                            labelSize: labelSize,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const GateCameraScreen()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 🔹 Center Button (Security Dashboard)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: -2,
                    child: Center(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(44),
                        onTap: () => onTap(3),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: compact ? 78 : 86,
                          height: compact ? 78 : 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selectedIndex == 2
                                ? const Color(0xFFCAE6EA)
                                : const Color(0xFFF6F8FA),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x330EA5A4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.security,
                                size: compact ? 24 : 26,
                                color: selectedIndex == 2
                                    ? const Color(0xFF0EA5A4)
                                    : const Color(0xFF222A35),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Security',
                                style: TextStyle(
                                  fontSize: labelSize,
                                  fontWeight: FontWeight.w700,
                                  color: selectedIndex == 2
                                      ? const Color(0xFF0EA5A4)
                                      : const Color(0xFF222A35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double iconSize;
  final double labelSize;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.iconSize,
    required this.labelSize,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? const Color(0xFF0EA5A4)
        : const Color.fromARGB(255, 118, 138, 150);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: iconSize),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: labelSize,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}