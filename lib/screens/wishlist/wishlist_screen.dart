import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../main_screen.dart';
import '../../utils/session_manager.dart';

class WishlistItem {
  final int id;
  final int productId;
  final String name;
  final double price;
  final double? originalPrice;
  final String imageUrl;
  final String? discountLabel;

  WishlistItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    this.originalPrice,
    required this.imageUrl,
    this.discountLabel,
  });

  factory WishlistItem.fromJson(Map<String, dynamic> json, String storageBase) {
    // Determine image URL
    final p = json['product'] ?? {};
    final String rawImage = p['image']?.toString() ?? '';
    final String imageUrl = rawImage.startsWith('http')
        ? rawImage
        : '$storageBase$rawImage';

    // Handle prices
    final double price = double.tryParse((p['unit_price'] ?? 0).toString()) ?? 0.0;
    double? oldPrice;
    String? disc;

    if (p['discount'] != null) {
      final double discountVal = double.tryParse(p['discount'].toString()) ?? 0;
      if (discountVal > 0) {
        disc = p['discount_type'] == 'amount' || p['discount_type'] == 'flat'
            ? '₹${discountVal.toStringAsFixed(0)} OFF' 
            : '${discountVal.toStringAsFixed(0)}% OFF';
        
        final double discAmt = double.tryParse((p['discount_amount'] ?? 0).toString()) ?? 0.0;
        oldPrice = price + discAmt;
      }
    }

    return WishlistItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      productId: int.tryParse(p['id']?.toString() ?? '') ?? 0,
      name: p['product_name']?.toString() ?? 'Unknown Product',
      price: price,
      originalPrice: oldPrice,
      imageUrl: imageUrl,
      discountLabel: disc,
    );
  }
}

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final String _baseUrl = 'https://aerthh.newhopeindia17.com/api';
  final String _storageBase =
      'https://aerthh.newhopeindia17.com/storage/app/public/';

  List<WishlistItem> _wishlistItems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchWishlist();
  }

  Future<void> _fetchWishlist() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final token = await SessionManager.getToken();
    if (token == null) {
      if (!mounted) return;
      setState(() {
        _error = 'Please login to view your wishlist';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/wishlist'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List rawData = decoded is List ? decoded : (decoded['data'] ?? []);
        final items = rawData
            .whereType<Map<String, dynamic>>()
            .map((e) => WishlistItem.fromJson(e, _storageBase))
            .toList();

        if (!mounted) return;
        setState(() {
          _wishlistItems = items;
          _isLoading = false;
        });
        // Also update cart count for the bottom nav bar
        MainScreen.mainScreenKey.currentState?.refresh();
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load wishlist: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFromWishlist(int productId, int index) async {
    HapticFeedback.mediumImpact();
    final token = await SessionManager.getToken();
    if (token == null) return;

    final removedItem = _wishlistItems[index];
    setState(() {
      _wishlistItems.removeAt(index);
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/wishlist/remove/$productId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'_method': 'DELETE'}),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(decoded['message'] ?? 'Item removed from wishlist'),
              duration: const Duration(seconds: 1),
            ),
          );
          MainScreen.mainScreenKey.currentState?.refresh();
        } else {
          throw Exception(decoded['message'] ?? 'Failed to remove item');
        }
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _wishlistItems.insert(index, removedItem);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove item: $e')),
      );
    }
  }

  Future<void> _addToCart(WishlistItem item) async {
    HapticFeedback.mediumImpact();
    final token = await SessionManager.getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add to cart')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/cart/add'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'product_id': item.productId,
          'quantity': 1,
        }),
      );

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 && decoded['status'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded['message'] ?? 'Added to cart'),
            duration: const Duration(seconds: 1),
          ),
        );
        MainScreen.mainScreenKey.currentState?.refresh();
      } else {
        throw Exception(decoded['message'] ?? 'Failed to add to cart');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _onNavBarIndexChanged(int index) {
    if (MainScreen.mainScreenKey.currentState != null) {
      MainScreen.mainScreenKey.currentState!.onIndexChanged(index);
      Navigator.of(context).pop();
    } else {
      // Fallback if MainScreen is not found (shouldn't happen with GlobalKey)
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
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
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _buildHeaderButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Wishlist',
                      style: TextStyle(
                        color: Color(0xFFE8C89F),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (!_isLoading)
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded,
                            color: Color(0xFFD4A574), size: 20),
                        onPressed: _fetchWishlist,
                      ),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFD4A574)))
                    : _error != null
                        ? _buildError()
                        : _wishlistItems.isEmpty
                            ? _buildEmpty()
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _wishlistItems.length,
                                itemBuilder: (context, index) {
                                  final item = _wishlistItems[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _buildWishlistCard(item, index),
                                  );
                                },
                              ),
              ),
              // Aded space for navbar padding
              const SizedBox(height: 70),
            ],
          ),
        ),
      ),
      bottomNavigationBar: PremiumBottomNavBar(
        currentIndex: -1, // No tab active
        onIndexChanged: _onNavBarIndexChanged,
        cartCount: MainScreen.mainScreenKey.currentState?.cartCount ?? 0,
      ),
    );
  }

  Widget _buildWishlistCard(WishlistItem item, int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD4A574).withValues(alpha: 0.15),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1C1B23).withValues(alpha: 0.6),
            const Color(0xFF15121D).withValues(alpha: 0.4),
          ],
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Product Image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 72,
              height: 72,
              color: const Color(0xFFD4A574).withValues(alpha: 0.08),
              child: Image.network(
                item.imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFD4A574),
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE8C89F),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₹${item.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Color(0xFFD4A574),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (item.originalPrice != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '₹${item.originalPrice!.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: const Color(0xFF7A7A7F).withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.discountLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4A574).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.discountLabel!,
                        style: const TextStyle(
                          color: Color(0xFFD4A574),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action Buttons
          Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _addToCart(item),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4A574).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_shopping_cart_rounded,
                      color: Color(0xFFD4A574),
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _removeFromWishlist(item.productId, index),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.delete_outline,
                      color: Color(0xFFFF6B6B),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                color: const Color(0xFFD4A574).withValues(alpha: 0.5), size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF7A7A7F), fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _fetchWishlist,
              child: const Text('Retry',
                  style: TextStyle(color: Color(0xFFD4A574))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_outline_rounded,
              size: 64,
              color: const Color(0xFFD4A574).withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text(
            'Your wishlist is empty',
            style: TextStyle(
              color: Color(0xFFE8C89F),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add products to see them here',
            style: TextStyle(
              color: const Color(0xFF7A7A7F).withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
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
}
