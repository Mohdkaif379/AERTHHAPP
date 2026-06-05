import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  static const Color _bg = Color(0xFF0A0A12);
  static const Color _cardBg = Color(0xFF1C1B23);
  static const Color _gold = Color(0xFFD4A574);
  static const Color _goldMid = Color(0xFFE8C89F);

  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = '${info.version}+${info.buildNumber}';
      });
    }
  }

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
                      'Settings',
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
                      const _SectionTitle(title: 'System Settings'),
                      _buildLinkItem(
                        icon: Icons.language_rounded,
                        title: 'Language',
                        subtitle: 'English (US)',
                        onTap: () {},
                      ),
                      _buildLinkItem(
                        icon: Icons.cloud_download_outlined,
                        title: 'Clear Cache',
                        subtitle: 'Free up storage space',
                        onTap: () {},
                      ),

                      const SizedBox(height: 32),
                      const _SectionTitle(title: 'About'),
                      _buildInfoItem(
                        icon: Icons.info_outline_rounded,
                        title: 'App Version',
                        value: 'v$_appVersion',
                      ),
                      _buildInfoItem(
                        icon: Icons.developer_mode_rounded,
                        title: 'Developer',
                        value: 'Aerthh Team',
                      ),
                      
                      const SizedBox(height: 48),
                      Center(
                        child: Text(
                          'AERTHH',
                          style: TextStyle(
                            color: _gold.withValues(alpha: 0.2),
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 100),
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

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _gold, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _gold,
            activeTrackColor: _gold.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkItem({
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
                Icon(icon, color: _gold, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
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

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _gold, size: 22),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(color: _gold.withValues(alpha: 0.6), fontWeight: FontWeight.bold),
          ),
        ],
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
