import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/session_manager.dart';
import 'login_screen.dart';
import '../main_screen.dart';
import '../wishlist/wishlist_screen.dart';
import '../address/address_screen.dart';
import '../order/orders.dart';
import '../order/track_order.dart';
import '../order/history_screen.dart';
import 'my_profile_screen.dart';

class UserProfile {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String avatar;
  final String memberSince;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.avatar,
    required this.memberSince,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id']?.toString() ?? '',
      name: '${map['first_name'] ?? ''} ${map['last_name'] ?? ''}'.trim(),
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      avatar: map['profile_image'] ?? '',
      memberSince: map['created_at'] != null 
          ? DateTime.parse(map['created_at']).year.toString() 
          : '2026',
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userData = await SessionManager.getUser();
    if (userData != null) {
      if (mounted) {
        setState(() {
          _user = UserProfile.fromMap(userData);
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    HapticFeedback.mediumImpact();
    await SessionManager.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  bool isNotificationsEnabled = true;
  bool isPrivateAccount = false;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A12),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFD4A574))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A12), Color(0xFF15121D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with Back Button (Sticky)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _buildHeaderButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () {
                        // Navigate back to Home tab in MainScreen
                        final mainScreen = context.findAncestorStateOfType<MainScreenState>();
                        if (mainScreen != null) {
                          mainScreen.onIndexChanged(0);
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                    const Spacer(),
                    _buildHeaderButton(
                      icon: Icons.edit_outlined,
                      onTap: () async {
                        final updated = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MyProfileScreen()),
                        );
                        if (updated == true) {
                          _loadUserData();
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Enhanced Profile Header
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Glow Background
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD4A574).withValues(alpha: 0.1),
                                  blurRadius: 80,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              // Avatar
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFD4A574).withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                                child: Container(
                                  width: 110,
                                  height: 110,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Color(0xFFD4A574), Color(0xFFE8C89F)],
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: _user?.avatar.isNotEmpty == true
                                        ? Image.network(
                                            _user!.avatar,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(),
                                          )
                                        : _buildAvatarPlaceholder(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Name
                              Text(
                                _user?.name ?? 'Unknown User',
                                style: const TextStyle(
                                  color: Color(0xFFE8C89F),
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // Member Since
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4A574).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Member since ${_user?.memberSince ?? '2026'}',
                                  style: const TextStyle(
                                    color: Color(0xFFD4A574),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Content Sections
                      const _SectionTitle('Contact Information'),
                      _ContactCard(
                        icon: Icons.email_outlined,
                        label: 'Email Address',
                        value: _user?.email ?? 'Not available',
                      ),
                      _ContactCard(
                        icon: Icons.phone_outlined,
                        label: 'Phone Number',
                        value: _user?.phone ?? 'Not available',
                      ),

                      const SizedBox(height: 30),
                      const _SectionTitle('Account Settings'),
                      _SettingsOption(
                        icon: Icons.location_on_outlined,
                        label: 'Shipping Addresses',
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AddressScreen()),
                          );
                        },
                      ),
                      _SettingsOption(
                        icon: Icons.shopping_bag_outlined,
                        label: 'My Orders',
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const OrdersScreen()),
                          );
                        },
                      ),
                      _SettingsOption(
                        icon: Icons.history_rounded,
                        label: 'Order History',
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const HistoryScreen()),
                          );
                        },
                      ),
                      _SettingsOption(
                        icon: Icons.track_changes_rounded,
                        label: 'Track Order',
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const TrackOrderScreen()),
                          );
                        },
                      ),
                      _SettingsOption(
                        icon: Icons.favorite_outline,
                        label: 'My Wishlist',
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const WishlistScreen()),
                          );
                        },
                      ),

                      const SizedBox(height: 30),
                      const _SectionTitle('Preferences'),
                      _ToggleOption(
                        icon: Icons.notifications_none_rounded,
                        label: 'Push Notifications',
                        value: isNotificationsEnabled,
                        onChanged: (v) => setState(() => isNotificationsEnabled = v),
                      ),
                      _ToggleOption(
                        icon: Icons.lock_outline_rounded,
                        label: 'Privacy Mode',
                        value: isPrivateAccount,
                        onChanged: (v) => setState(() => isPrivateAccount = v),
                      ),

                      const SizedBox(height: 30),
                      const _SectionTitle('Support'),
                      _SettingsOption(
                        icon: Icons.help_outline_rounded,
                        label: 'Help Center',
                        onTap: () => HapticFeedback.mediumImpact(),
                      ),
                      _SettingsOption(
                        icon: Icons.shield_outlined,
                        label: 'Privacy Policy',
                        onTap: () => HapticFeedback.mediumImpact(),
                      ),

                      const SizedBox(height: 40),
                      // Logout Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _handleLogout,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                                color: Colors.redAccent.withValues(alpha: 0.05),
                              ),
                              child: const Center(
                                child: Text(
                                  'Sign Out',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
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
          child: Icon(icon, color: const Color(0xFFE8C89F), size: 18),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return const Center(child: Text('👤', style: TextStyle(fontSize: 40)));
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFD4A574),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B23).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4A574).withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFD4A574).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFD4A574), size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF7A7A7F), fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(color: Color(0xFFE8C89F), fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsOption({required this.icon, required this.label, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1B23).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4A574).withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFFD4A574), size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(color: Color(0xFFE8C89F), fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                trailing ?? Icon(Icons.chevron_right_rounded, color: const Color(0xFFD4A574).withValues(alpha: 0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleOption({required this.icon, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B23).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4A574).withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFD4A574), size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFFE8C89F), fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFD4A574),
            activeTrackColor: const Color(0xFFD4A574).withValues(alpha: 0.3),
            inactiveThumbColor: const Color(0xFF7A7A7F),
            inactiveTrackColor: const Color(0xFF7A7A7F).withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }
}
