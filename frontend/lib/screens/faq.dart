import 'package:flutter/material.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  static const _teal = Color(0xFF0EA5A4);

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        "question": "How do I book a parking space?",
        "answer":
            "Go to the Parking List, choose your desired slot, and click on the Book button to confirm your reservation."
      },
      {
        "question": "How can I cancel my booking?",
        "answer":
            "Navigate to My Bookings, select the booking you want to cancel, and tap on Cancel Booking."
      },
      {
        "question": "What payment methods are supported?",
        "answer":
            "You can pay using UPI, debit/credit cards, or other supported online payment methods."
      },
      {
        "question": "How do I list my parking space?",
        "answer":
            "Go to the Vendor section and add your parking space details such as location, price, and availability."
      },
      {
        "question": "Is my payment secure?",
        "answer":
            "Yes, all payments are processed through secure and encrypted payment gateways."
      },
      {
        "question": "What should I do if I face payment issues?",
        "answer":
            "Try again after checking your internet connection. If the issue persists, contact support."
      },
      {
        "question": "Can I extend my parking time?",
        "answer":
            "Yes, if the slot is available, you can extend your booking from the My Bookings section."
      },
      {
        "question": "How do I contact support?",
        "answer":
            "Go to the Contact Us page from the app menu or chatbot and reach out to our support team."
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQs'),
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
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: faqs.length,
          itemBuilder: (context, index) {
            final faq = faqs[index];
            return _FAQItem(
              question: faq["question"]!,
              answer: faq["answer"]!,
            );
          },
        ),
      ),
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          widget.question,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        iconColor: const Color(0xFF0EA5A4),
        collapsedIconColor: Colors.black54,
        onExpansionChanged: (value) {
          setState(() {
            _isExpanded = value;
          });
        },
        children: [
          Text(
            widget.answer,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}