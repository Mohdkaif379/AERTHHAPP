import 'package:flutter/material.dart';

class PrivacyCenterScreen extends StatelessWidget {
  const PrivacyCenterScreen({super.key});

  static const Color _bg = Color(0xFF0A0A12);
  static const Color _cardBg = Color(0xFF1C1B23);
  static const Color _gold = Color(0xFFD4A574);
  static const Color _goldMid = Color(0xFFE8C89F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bg, Color(0xFF15121D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _buildHeaderButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 20),
                    const Text(
                      'Privacy Center',
                      style: TextStyle(
                        color: _goldMid,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection('Privacy Policy', 'Last Updated: June 2026'),
                      _buildPolicyText(
                        'Information We Collect',
                        'We collect information you provide directly to us, such as when you create an account, place an order, or contact support. This includes your name, email, phone number, and address.',
                      ),
                      _buildPolicyText(
                        'How We Use Your Data',
                        'Your data is used to process orders, provide support, and send relevant notifications. We do not sell your personal information to third parties.',
                      ),
                      
                      const SizedBox(height: 32),
                      _buildHeaderSection('Terms of Service', 'By using Aerthh, you agree to these terms.'),
                      _buildPolicyText(
                        'Account Responsibility',
                        'You are responsible for maintaining the confidentiality of your account and password. Aerthh reserves the right to terminate accounts that violate our community guidelines.',
                      ),
                      _buildPolicyText(
                        'Purchases and Payments',
                        'All transactions are processed securely. Any refund requests will be handled according to our refund policy established in the Help Center.',
                      ),
                      
                      const SizedBox(height: 40),
                      _buildContactFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _goldMid, size: 18),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: _gold.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPolicyText(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: _goldMid, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildContactFooter() {
    return Center(
      child: Column(
        children: [
          Text(
             'Have questions about your privacy?',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
          ),
          TextButton(
            onPressed: () {},
            child: const Text(
              'Contact Privacy Team',
              style: TextStyle(color: _gold, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
