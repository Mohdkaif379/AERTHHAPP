import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../main_screen.dart';
import '../product/product_details_screen.dart';
import 'brand_screen.dart';
import '../../utils/session_manager.dart';

// ─── Color constants ──────────────────────────────────────────────────────────
const _gold = Color(0xFFD4A574);
const _goldMid = Color(0xFFC49A6C);
const _goldLight = Color(0xFFE8C89F);
const _bg = Color(0xFF0A0A12);
const _bg3 = Color(0xFF1C1B23);
const _border = Color(0xFF2E2B38);

// ─── Product data model ───────────────────────────────────────────────────────
class _ProductData {
  const _ProductData({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.unitPrice,
    required this.discount,
    required this.discountType,
    required this.isActive,
    required this.brandId,
  });

  factory _ProductData.fromJson(Map<String, dynamic> json) {
    return _ProductData(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['product_name']?.toString() ?? '',
      imageUrl: json['image']?.toString() ?? '',
      unitPrice: _asDouble(json['unit_price']),
      discount: _asDouble(json['discount']),
      discountType: json['discount_type']?.toString() ?? '',
      isActive: _asBool(json['status']),
      brandId: int.tryParse(json['brand_id']?.toString() ?? '') ?? 0,
    );
  }

  final int id;
  final String name;
  final String imageUrl;
  final double unitPrice;
  final double discount;
  final String discountType;
  final bool isActive;
  final int brandId;

  bool get hasDiscount => discount > 0 && discountedPrice < unitPrice;

  double get discountedPrice {
    if (discount <= 0) return unitPrice;
    final discountAmount = discountType == 'percent'
        ? unitPrice * discount / 100
        : discount;
    final price = unitPrice - discountAmount;
    return price < 0 ? 0 : price;
  }

  String get displayPrice => 'Rs. ${_formatNumber(discountedPrice)}';
  String get originalPrice => 'Rs. ${_formatNumber(unitPrice)}';

  String? get discountLabel {
    if (!hasDiscount) return null;
    if (discountType == 'percent') return '${_formatNumber(discount)}% OFF';
    return 'Flat ${_formatNumber(discount)} OFF';
  }

  static bool _asBool(dynamic v) => v == true || v == 1 || v == '1';
  static double _asDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  static String _formatNumber(double value) {
    final rounded = value.roundToDouble();
    return value == rounded
        ? rounded.toInt().toString()
        : value.toStringAsFixed(2);
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class BrandDetailScreen extends StatefulWidget {
  const BrandDetailScreen({super.key, required this.brand});

  final Brand brand;

  @override
  State<BrandDetailScreen> createState() => _BrandDetailScreenState();
}

class _BrandDetailScreenState extends State<BrandDetailScreen> {
  static const _productsUrl = 'https://aerthh.newhopeindia17.com/api/products';

  bool _isLoading = true;
  String? _error;
  List<_ProductData> _products = [];
  Set<int> _wishlistProductIds = {};
  Set<int> _cartProductIds = {};

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    await Future.wait([
      _fetchProducts(),
      _fetchWishlist(),
      _fetchCart(),
    ]);
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(Uri.parse(_productsUrl));
      if (response.statusCode != 200) {
        throw Exception('Products API failed: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final rawProducts = decoded is List
          ? decoded
          : decoded is Map<String, dynamic>
          ? decoded['data']
          : null;

      if (rawProducts is! List) {
        throw const FormatException('Products API response is invalid');
      }

      final all = rawProducts
          .whereType<Map<String, dynamic>>()
          .map(_ProductData.fromJson)
          .where(
            (p) =>
                p.isActive &&
                p.name.isNotEmpty &&
                p.imageUrl.isNotEmpty &&
                p.brandId == widget.brand.id,
          )
          .toList();

      if (mounted) {
        setState(() {
          _products = all;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load products';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchWishlist() async {
    final token = await SessionManager.getToken();
    if (token == null) return;
    try {
      final response = await http.get(
        Uri.parse('https://aerthh.newhopeindia17.com/api/wishlist'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List items = decoded is List ? decoded : (decoded['data'] ?? []);
        if (mounted) {
          setState(() {
            _wishlistProductIds = items
                .whereType<Map<String, dynamic>>()
                .map((e) => int.tryParse(e['product_id']?.toString() ?? '') ?? 0)
                .toSet();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchCart() async {
    final token = await SessionManager.getToken();
    if (token == null) return;
    try {
      final response = await http.get(
        Uri.parse('https://aerthh.newhopeindia17.com/api/cart'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List items = decoded['data'] ?? [];
        if (mounted) {
          setState(() {
            _cartProductIds = items
                .whereType<Map<String, dynamic>>()
                .map((e) => int.tryParse(e['product_id']?.toString() ?? '') ?? 0)
                .toSet();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleWishlist(_ProductData product) async {
    HapticFeedback.mediumImpact();
    final token = await SessionManager.getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to use wishlist')),
      );
      return;
    }

    final isAdding = !_wishlistProductIds.contains(product.id);
    setState(() {
      if (isAdding) {
        _wishlistProductIds.add(product.id);
      } else {
        _wishlistProductIds.remove(product.id);
      }
    });

    try {
      final response = await http.post(
        Uri.parse('https://aerthh.newhopeindia17.com/api/wishlist/add'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'product_id': product.id}),
      );
      final decoded = jsonDecode(response.body);
      final String msg = decoded['message'] ?? (isAdding ? 'Added to wishlist' : 'Removed from wishlist');

      if (response.statusCode == 200 && decoded['status'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
        );
        await MainScreen.mainScreenKey.currentState?.refresh();
        if (mounted) setState(() {});
        
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) setState(() {});
        });
      } else {
        throw Exception(msg);
      }
    } catch (e) {
      setState(() {
        if (isAdding) {
          _wishlistProductIds.remove(product.id);
        } else {
          _wishlistProductIds.add(product.id);
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
        ),
      );
    }
  }

  Future<void> _addToCart(_ProductData product) async {
    HapticFeedback.mediumImpact();
    final token = await SessionManager.getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add to cart')),
      );
      return;
    }

    if (_cartProductIds.contains(product.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already in cart'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() => _cartProductIds.add(product.id));

    try {
      final response = await http.post(
        Uri.parse('https://aerthh.newhopeindia17.com/api/cart/add'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'product_id': product.id, 'quantity': 1}),
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
        await MainScreen.mainScreenKey.currentState?.refresh();
        if (mounted) setState(() {});

        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) setState(() {});
        });
      } else {
        throw Exception(decoded['message'] ?? 'Failed to add to cart');
      }
    } catch (e) {
      setState(() => _cartProductIds.remove(product.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
        ),
      );
    }
  }

  void _openProductDetails(_ProductData product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(
          productId: product.id.toString(),
          productName: product.name,
          productPrice: product.displayPrice,
          productImage: product.imageUrl,
        ),
      ),
    ).then((_) => _fetchAll());
  }

  void _onNavbarIndexChanged(int index) {
    // Brands are accessed from Home, so if user clicks Home tab (0), 
    // we just pop. Otherwise pop and switch tab.
    if (index == 0) {
      Navigator.of(context).pop();
      // Ensure we go back to Home if we were somewhere else
      MainScreen.mainScreenKey.currentState?.onIndexChanged(0);
    } else {
      Navigator.of(context).pop();
      MainScreen.mainScreenKey.currentState?.onIndexChanged(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainState = MainScreen.mainScreenKey.currentState;
    
    return Scaffold(
      backgroundColor: _bg,
      extendBody: true,
      bottomNavigationBar: PremiumBottomNavBar(
        currentIndex: 0, 
        onIndexChanged: _onNavbarIndexChanged,
        cartCount: mainState?.cartCount ?? 0,
        profileImageUrl: mainState?.profileImageUrl,
      ),
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
              _buildHeader(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          // Back button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: _border),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _goldLight,
                  size: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Brand avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _gold.withValues(alpha: 0.4), width: 1.5),
              color: _bg3,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.network(
              widget.brand.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.business_rounded,
                color: _goldMid,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.brand.name,
                  style: const TextStyle(
                    color: _goldLight,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _isLoading
                      ? 'Loading...'
                      : '${_products.length} product${_products.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: _goldMid.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _fetchAll,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: _border),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: _goldLight,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.4, color: _gold),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: _gold, size: 40),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: _goldLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: _fetchProducts,
              style: TextButton.styleFrom(foregroundColor: _goldMid),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: _gold.withValues(alpha: 0.45),
              size: 52,
            ),
            const SizedBox(height: 16),
            const Text(
              'No products from this brand',
              style: TextStyle(
                color: _goldLight,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new arrivals',
              style: TextStyle(
                color: _goldMid.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return _ProductCard(
          product: product,
          isWishlisted: _wishlistProductIds.contains(product.id),
          isInCart: _cartProductIds.contains(product.id),
          onTap: () => _openProductDetails(product),
          onWishlistTap: () => _toggleWishlist(product),
          onAddToCartTap: () => _addToCart(product),
        );
      },
    );
  }
}

// ─── Product card ─────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.isWishlisted,
    required this.isInCart,
    required this.onTap,
    required this.onWishlistTap,
    required this.onAddToCartTap,
  });

  final _ProductData product;
  final bool isWishlisted, isInCart;
  final VoidCallback onTap;
  final VoidCallback onWishlistTap;
  final VoidCallback onAddToCartTap;

  @override
  Widget build(BuildContext context) {
    final badge = product.discountLabel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: _bg3,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.07),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14),
                        ),
                      ),
                      child: Image.network(
                        product.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 36,
                            color: _gold.withValues(alpha: 0.45),
                          ),
                        ),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _gold,
                                value: progress.expectedTotalBytes == null
                                    ? null
                                    : progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (badge != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _gold.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: _goldMid,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.42),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: onWishlistTap,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(7),
                            child: Icon(
                              isWishlisted
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isWishlisted ? _goldLight : Colors.white,
                              size: 17,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Text(
                  product.name,
                  style: const TextStyle(
                    color: _goldLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 3, 10, 0),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        product.displayPrice,
                        style: const TextStyle(
                          color: _goldMid,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (product.hasDiscount) ...[
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          product.originalPrice,
                          style: TextStyle(
                            color: _goldMid.withValues(alpha: 0.45),
                            fontSize: 10,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: _goldMid.withValues(alpha: 0.45),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onAddToCartTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          colors: [_gold, _goldLight],
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isInCart
                                ? Icons.check_rounded
                                : Icons.shopping_cart_outlined,
                            color: const Color(0xFF0D0B08),
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isInCart ? 'Added' : 'Add to Cart',
                            style: const TextStyle(
                              color: Color(0xFF0D0B08),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
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
        ),
      ),
    );
  }
}
