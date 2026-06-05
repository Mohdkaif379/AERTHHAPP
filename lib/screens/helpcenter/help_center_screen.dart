import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

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
                      'Help Center',
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
                      const Text(
                        'How can we help you?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Search for topics or contact our support team.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // FAQ Search Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _gold.withValues(alpha: 0.1)),
                        ),
                        child: const TextField(
                          style: TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            icon: Icon(Icons.search, color: _gold),
                            hintText: 'Search FAQ',
                            hintStyle: TextStyle(color: Colors.white24),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      const _SectionTitle(title: 'Top Questions'),
                      _buildFAQItem(
                        'How do I track my order?',
                        'You can track your order by going to Profile > Track Order and entering your Order ID.',
                      ),
                      _buildFAQItem(
                        'What is the return policy?',
                        'We offer a 7-day return policy for most items. Ensure the product is in its original condition.',
                      ),
                      _buildFAQItem(
                        'How do I update my profile?',
                        'Navigate to Profile > Edit icon (pencil) to update your personal information.',
                      ),

                      const SizedBox(height: 40),
                      const _SectionTitle(title: 'Contact Support'),
                      _buildContactLink(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Live Chat',
                        subtitle: 'https://aerthh.vercel.app/home',
                        onTap: () => _launchURL('https://aerthh.vercel.app/home'),
                      ),
                      _buildContactLink(
                        icon: Icons.email_outlined,
                        title: 'Email Us',
                        subtitle: 'mohdkaif8603@gmail.com',
                        onTap: () => _launchURL('mailto:mohdkaif8603@gmail.com'),
                      ),
                      _buildContactLink(
                        icon: Icons.phone_outlined,
                        title: 'Call Us',
                        subtitle: '+91 9027114840',
                        onTap: () => _launchURL('tel:+919027114840'),
                      ),
                      const SizedBox(height: 40),
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

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $url');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.05)),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(color: _goldMid, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        iconColor: _gold,
        collapsedIconColor: _gold.withValues(alpha: 0.5),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactLink({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _cardBg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _gold.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: _gold, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFD4A574),
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
