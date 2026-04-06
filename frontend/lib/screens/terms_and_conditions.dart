import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final horizontalPadding = ResponsiveUtils.responsivePadding(
      context,
      mobile: 20,
      tablet: 36,
      desktop: 48,
    );
    final titleFontSize = ResponsiveUtils.responsiveFontSize(
      context,
      mobile: 24,
      tablet: 32,
      desktop: 36,
    );
    final headingFontSize = ResponsiveUtils.responsiveFontSize(
      context,
      mobile: 18,
      tablet: 22,
      desktop: 24,
    );
    final bodyFontSize = ResponsiveUtils.responsiveFontSize(
      context,
      mobile: 14,
      tablet: 16,
      desktop: 16,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF0F172A), Color(0xFF1E293B)]
                : const [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: ResponsiveUtils.responsivePadding(context, mobile: 20, tablet: 30, desktop: 40)),
                Text(
                  'Terms and Conditions',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Last updated: April 5, 2026',
                  style: TextStyle(
                    fontSize: bodyFontSize,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(height: ResponsiveUtils.responsivePadding(context, mobile: 24, tablet: 32, desktop: 40)),

                _buildSection(
                  context,
                  '1. Acceptance of Terms',
                  'By accessing and using the ParkAI parking management application ("the App"), you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.',
                  headingFontSize,
                  bodyFontSize,
                  isDark,
                ),

                _buildSection(
                  context,
                  '2. Description of Service',
                  'ParkAI is a comprehensive parking management platform that connects parking space owners (vendors), customers seeking parking, and security personnel. The platform facilitates:\n\n• Parking space registration and management\n• Real-time parking availability\n• Automated booking and payment processing\n• Security monitoring and access control\n• QR code-based entry/exit system',
                  headingFontSize,
                  bodyFontSize,
                  isDark,
                ),

                _buildSection(
                  context,
                  '3. User Accounts and Registration',
                  '3.1 Account Types\n• Customers: Individuals seeking parking spaces\n• Vendors: Parking space owners and managers\n• Security Personnel: Authorized staff for parking facility management\n• Administrators: Platform administrators\n\n3.2 Registration Requirements\n• All users must provide accurate and complete information\n• Vendors must submit verification documents including business license, land ownership proof, and government-issued ID\n• Account approval may require administrative review\n• Users are responsible for maintaining account security',
                  headingFontSize,
                  bodyFontSize,
                  isDark,
                ),

                _buildSection(
                  context,
                  '4. Vendor Responsibilities',
                  '4.1 Parking Space Management\n• Maintain accurate parking space information\n• Ensure parking facilities meet safety standards\n• Provide real-time availability updates\n• Honor confirmed bookings\n\n4.2 Documentation and Compliance\n• Submit valid business licenses and permits\n• Maintain proper land ownership documentation\n• Comply with local parking regulations\n• Keep insurance coverage current\n\n4.3 Financial Obligations\n• Pay platform service fees as agreed\n• Process refunds for cancellations per policy\n• Maintain accurate pricing information',
                  headingFontSize,
                  bodyFontSize,
                  isDark,
                ),

                _buildSection(
                  context,
                  '5. Customer Responsibilities',
                  '5.1 Booking and Usage\n• Provide accurate vehicle and contact information\n• Arrive within designated time windows\n• Follow parking facility rules and signage\n• Report any issues promptly\n\n5.2 Payment Obligations\n• Pay for parking services as booked\n• Cancellation fees apply per policy\n• Disputes must be reported within 24 hours\n\n5.3 Vehicle and Property\n• Park only authorized vehicles\n• Lock vehicles and secure belongings\n• Comply with time limits and restrictions',
                  headingFontSize,
                  bodyFontSize,
                  isDark,
                ),

                _buildSection(
                  context,
                  '6. Security Personnel Responsibilities',
                  '6.1 Access Control\n• Verify QR codes and booking confirmations\n• Monitor parking facility security\n• Report suspicious activities\n• Assist with emergency situations\n\n6.2 Facility Management\n• Maintain parking area cleanliness\n• Report maintenance issues\n• Ensure proper lighting and signage\n• Follow emergency procedures',
                  headingFontSize,
                  bodyFontSize,
                  isDark,
                ),

                _buildSection(
                  context,
                  '7. Payment Terms',
                  '7.1 Booking Fees\n• Non-refundable booking fee charged upfront\n• Hourly rates apply for actual usage\n• Payment processed through secure channels\n\n7.2 Refund Policy\n• Cancellations within 1 hour: Full refund\n• Cancellations within 24 hours: 50% refund\n• No refunds for no-shows or late cancellations\n\n7.3 Payment Methods\n• Credit/Debit cards accepted\n• Digital wallets supported\n• All transactions are secure and encrypted',
                  headingFontSize,
                  bodyFontSize,
                  isDark,
                ),

                _buildSection(
                  context,
                  '8. Privacy and Data Protection',
                  '8.1 Information Collection\n• Personal information for account creation\n• Vehicle details for parking management\n• Payment information for transactions\n• Location data for service provision\n\n8.2 Data Usage\n• Information used solely for service provision\n• Shared only with necessary parties\n• Protected by industry-standard security\n\n8.3 User Rights\n• Access to personal data\n• Data correction capabilities\n• Account deletion option\n• Privacy policy compliance',
                  headingFontSize,
                  bodyFontSize,
                  isDark,
                ),

                _buildSection(
                  context,
                  '9. Liability and Disclaimers',
                  '9.1 Service Availability\n• Platform operates on best-effort basis\n• No guarantees of continuous availability\n• Maintenance windows may affect service\n\n9.2 Vehicle and Property\n• Platform not responsible for vehicle damage\n• Users park at own risk\n• Valuables should be removed from vehicles\n\n9.3 Third-Party Services\n• External payment processors used\n• Users agree to their terms separately\n• Platform not liable for third-party failures',
                  headingFontSize,
                  bodyFontSize,
                  isDark,
                ),

                _buildSection(
                  context,
                  '10. Termination and Suspension',
                  '10.1 Account Termination\n• Users may terminate accounts anytime\n• Platform may suspend for policy violations\n• Outstanding payments must be settled\n\n10.2 Service Termination\n• Platform may discontinue services with notice\n• Data will be retained per privacy policy\n• Refunds processed for active bookings',
                  headingFontSize,
                  bodyFontSize,
                  isDark,
                ),

                _buildSection(
                  context,
                  '11. Intellectual Property',
                  '11.1 Platform Ownership\n• All platform content and technology owned by ParkAI\n• User-generated content rights retained by users\n• Limited license granted for platform use\n\n11.2 Prohibited Uses\n• No reverse engineering or copying\n• No unauthorized access attempts\n• No interference with platform operations',
                  headingFontSize,
                  bodyFontSize,
                  isDark,
                ),

                _buildSection(
                  context,
                  '12. Dispute Resolution',
                  '12.1 Initial Resolution\n• Contact customer support first\n• Most issues resolved through communication\n• Documentation maintained for disputes\n\n12.2 Escalation Process\n• Unresolved issues escalated to management\n• Mediation may be offered\n• Legal action as last resort',
                  headingFontSize,
                  bodyFontSize,
                  isDark,
                ),

                _buildSection(
                  context,
                  '13. Governing Law',
                  'These terms and conditions are governed by and construed in accordance with the laws of the jurisdiction where ParkAI operates. Any disputes arising from these terms shall be subject to the exclusive jurisdiction of the courts in that jurisdiction.',
                  headingFontSize,
                  bodyFontSize,
                  isDark,
                ),

                _buildSection(
                  context,
                  '14. Changes to Terms',
                  'ParkAI reserves the right to modify these terms and conditions at any time. Users will be notified of significant changes via email or app notifications. Continued use of the platform constitutes acceptance of modified terms.',
                  headingFontSize,
                  bodyFontSize,
                  isDark,
                ),

                _buildSection(
                  context,
                  '15. Contact Information',
                  'For questions about these terms and conditions, please contact:\n\nEmail: legal@parkai.com\nPhone: +1 (555) 123-4567\nAddress: 123 Parking Street, City, State 12345\n\nSupport Hours: Monday-Friday, 9 AM - 6 PM (Local Time)',
                  headingFontSize,
                  bodyFontSize,
                  isDark,
                ),

                SizedBox(height: ResponsiveUtils.responsivePadding(context, mobile: 40, tablet: 50, desktop: 60)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String content,
    double headingFontSize,
    double bodyFontSize,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: headingFontSize,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: bodyFontSize,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            height: 1.6,
          ),
        ),
        SizedBox(height: ResponsiveUtils.responsivePadding(context, mobile: 20, tablet: 24, desktop: 28)),
      ],
    );
  }
}