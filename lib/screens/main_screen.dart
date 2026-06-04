import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'auth/profile_screen.dart' as profile;
import 'cart/cart_screen.dart' as cart;
import 'categories/category_screen.dart' as category;
import 'home/home_screen.dart' as home;
import 'product/product_screen.dart' as product;
import '../utils/session_manager.dart';

class MainScreen extends StatefulWidget {
  static final GlobalKey<MainScreenState> mainScreenKey =
      GlobalKey<MainScreenState>();

  MainScreen({Key? key}) : super(key: key ?? mainScreenKey);

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  MainScreenState() : super();

  @override
  void initState() {
    super.initState();
    refresh();
  }

  int currentIndex = 0;
  int _cartCount = 0;
  int get cartCount => _cartCount;
  int _wishlistCount = 0;
  int get wishlistCount => _wishlistCount;
  String? _profileImageUrl;
  String? get profileImageUrl => _profileImageUrl;

  Future<void> refresh() async {
    debugPrint('MainScreen: Refreshing navbar data...');
    await Future.wait([
      _updateProfileImage(),
      _updateCartCount(),
      _updateWishlistCount(),
    ]);
    
    // Sometimes server takes a moment to process the previous ADD request
    // We do one more fetch after a small delay for better reliability
    Future.delayed(const Duration(milliseconds: 800), () {
      _updateCartCount();
      _updateWishlistCount();
    });
  }

  Future<void> _updateProfileImage() async {
    final user = await SessionManager.getUser();
    if (user != null && user['profile_image'] != null) {
      if (mounted) {
        setState(() {
          _profileImageUrl = user['profile_image'].toString();
        });
      }
    }
  }

  Future<void> _updateCartCount() async {
    final token = await SessionManager.getToken();
    if (token == null) return;

    try {
      debugPrint('MainScreen: Fetching cart count...');
      final response = await http.get(
        Uri.parse('https://aerthh.newhopeindia17.com/api/cart'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List cartItems = decoded['data'] ?? [];
        debugPrint('MainScreen: Cart updated. Count: ${cartItems.length}');
        if (mounted) {
          setState(() {
            _cartCount = cartItems.length;
          });
        }
      } else {
        debugPrint('MainScreen: Cart fetch failed. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('MainScreen: Error updating cart: $e');
    }
  }

  Future<void> _updateWishlistCount() async {
    final token = await SessionManager.getToken();
    if (token == null) return;

    try {
      debugPrint('MainScreen: Fetching wishlist count...');
      final response = await http.get(
        Uri.parse('https://aerthh.newhopeindia17.com/api/wishlist'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List wishlistItems = decoded is List ? decoded : (decoded['data'] ?? []);
        debugPrint('MainScreen: Wishlist updated. Count: ${wishlistItems.length}');
        if (mounted) {
          setState(() {
            _wishlistCount = wishlistItems.length;
          });
        }
      } else {
        debugPrint('MainScreen: Wishlist fetch failed. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('MainScreen: Error updating wishlist: $e');
    }
  }

  void onIndexChanged(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      home.HomeScreen(onProductsTap: () => onIndexChanged(2)),
      const category.CategoriesScreen(),
      const product.ProductScreen(),
      const cart.CartScreen(),
      const profile.ProfileScreen(),
    ];

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (currentIndex != 0) {
          setState(() {
            currentIndex = 0;
          });
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: const Color(0xFF0A0A12),
          extendBody: true,
          body: pages[currentIndex],
          bottomNavigationBar: PremiumBottomNavBar(
            currentIndex: currentIndex,
            onIndexChanged: onIndexChanged,
            cartCount: _cartCount,
            profileImageUrl: _profileImageUrl,
          ),
        ),
      ),
    );
  }
}

class PremiumBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onIndexChanged;
  final int cartCount;
  final String? profileImageUrl;

  const PremiumBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.cartCount,
    this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1C1B23).withValues(alpha: 0.85),
                  const Color(0xFF0F0F15).withValues(alpha: 0.9),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFD4A574).withValues(alpha: 0.2),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(0, Icons.home_rounded, 'Home'),
                _buildNavItem(1, Icons.grid_view_rounded, 'Category'),
                _buildNavItem(2, Icons.storefront_rounded, 'Products'),
                _buildNavItem(
                  3,
                  Icons.shopping_bag_rounded,
                  'Cart',
                  hasCart: true,
                ),
                _buildNavItem(
                  4,
                  Icons.person_rounded,
                  'Profile',
                  imageUrl: profileImageUrl,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label, {
    bool hasCart = false,
    String? imageUrl,
  }) {
    final isActive = currentIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onIndexChanged(index),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isActive)
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFD4A574).withValues(alpha: 0.35),
                          const Color(0xFFE8C89F).withValues(alpha: 0.25),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFD4A574).withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (imageUrl != null)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFFE8C89F)
                              : const Color(0xFFD4A574).withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                      ),
                      child: ClipOval(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            icon,
                            size: 20,
                            color: isActive
                                ? const Color(0xFFE8C89F)
                                : const Color(0xFF7A7A7F),
                          ),
                        ),
                      ),
                    )
                  else
                    Icon(
                      icon,
                      size: 24,
                      color: isActive
                          ? const Color(0xFFE8C89F)
                          : const Color(0xFF7A7A7F),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive
                          ? const Color(0xFFE8C89F)
                          : const Color(0xFF7A7A7F),
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (hasCart && cartCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cartCount > 99 ? '99+' : '$cartCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
