import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _teal = Color(0xFF0EA5A4);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: _teal,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0F7FF), Color(0xFFE8FFF5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Privacy Policy",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),

                Text(
                  "We value your privacy and are committed to protecting your personal information. This Privacy Policy explains how we collect, use, and safeguard your data when you use our application.",
                ),

                SizedBox(height: 16),

                Text(
                  "1. Information We Collect",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  "• Personal details such as name, email, and phone number.\n"
                  "• Location data for providing nearby parking services.\n"
                  "• Payment information for booking transactions.\n"
                  "• Device and usage data to improve app performance.",
                ),

                SizedBox(height: 16),

                Text(
                  "2. How We Use Your Information",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  "• To provide and manage parking services.\n"
                  "• To process bookings and payments.\n"
                  "• To improve user experience.\n"
                  "• To communicate updates and support.",
                ),

                SizedBox(height: 16),

                Text(
                  "3. Data Security",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  "We implement appropriate security measures to protect your data from unauthorized access, alteration, or disclosure.",
                ),

                SizedBox(height: 16),

                Text(
                  "4. Sharing of Information",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  "We do not sell your personal data. Information may be shared only with trusted partners for payment processing or legal requirements.",
                ),

                SizedBox(height: 16),

                Text(
                  "5. Your Rights",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  "You have the right to access, update, or delete your personal data. You can contact us for any privacy-related requests.",
                ),

                SizedBox(height: 16),

                Text(
                  "6. Changes to This Policy",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  "We may update this policy from time to time. Changes will be reflected on this page.",
                ),

                SizedBox(height: 16),

                Text(
                  "7. Contact Us",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  "If you have any questions about this Privacy Policy, please contact us through the app.",
                ),

                SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}