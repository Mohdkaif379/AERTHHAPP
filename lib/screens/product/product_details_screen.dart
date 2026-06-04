import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../main_screen.dart';
import '../../utils/session_manager.dart';
import '../order/order_summary.dart';

class ProductDetailsScreen extends StatefulWidget {
  static Route<void> route({
    required String productId,
    required String productName,
    required String productPrice,
    String productImage = '',
  }) {
    return MaterialPageRoute(
      builder: (_) => ProductDetailsScreen(
        productId: productId,
        productName: productName,
        productPrice: productPrice,
        productImage: productImage,
      ),
    );
  }

  final String productId;
  final String productName;
  final String productPrice;
  final String productImage;

  const ProductDetailsScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.productImage,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late String _currentPrice;
  late String _currentName;
  
  _ProductDetail? _productDetail;
  List<_SimilarProduct> _similarProducts = [];
  bool _isLoading = true;
  bool _isLoadingSimilar = true;
  String? _error;
  int _currentImageIndex = 0;
  bool _isDescriptionExpanded = false;
  bool _isWishlisted = false;

  @override
  void initState() {
    super.initState();
    _currentPrice = widget.productPrice;
    _currentName = widget.productName;
    _fetchProductDetails();
    _fetchSimilarProducts();
    _fetchWishlistStatus();
  }

  Future<void> _fetchWishlistStatus() async {
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
        final List wishlist = decoded['data'] ?? [];
        final isWishlisted = wishlist.any((item) {
          final p = item['product'] ?? {};
          return p['id'].toString() == widget.productId;
        });

        if (mounted) {
          setState(() {
            _isWishlisted = isWishlisted;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchProductDetails() async {
    try {
      final response = await http.get(
        Uri.parse('https://aerthh.newhopeindia17.com/api/products/${widget.productId}'),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final detail = _ProductDetail.fromJson(decoded);
        if (mounted) {
          setState(() {
            _productDetail = detail;
            _currentName = detail.name;
            _currentPrice = detail.displayPrice;
            _isLoading = false;
          });
        }
      } else {
        throw Exception();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load details';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchSimilarProducts() async {
    try {
      final response = await http.get(
        Uri.parse('https://aerthh.newhopeindia17.com/api/products'),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List rawData = decoded is Map ? (decoded['data'] ?? []) : (decoded ?? []);
        
        final products = rawData
            .whereType<Map<String, dynamic>>()
            .map(_SimilarProduct.fromJson)
            .where((p) => p.id.toString() != widget.productId && p.name.isNotEmpty)
            .take(4)
            .toList();

        if (mounted) {
          setState(() {
            _similarProducts = products;
            _isLoadingSimilar = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingSimilar = false);
      }
    }
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>|&nbsp;'), ' ').trim();
  }

  void _shareProduct() {
    HapticFeedback.selectionClick();
    final message = 'Check out this luxury product on Aerthh!\n\n'
        'Product: $_currentName\n'
        'Price: $_currentPrice (Inclusive of all taxes)\n\n'
        'Download our app to shop more premium products!';
    Share.share(message);
  }

  @override
  Widget build(BuildContext context) {
    final images = _productDetail != null
        ? [widget.productImage, ..._productDetail!.additionalImages]
            .where((img) => img.isNotEmpty)
            .toSet()
            .toList()
        : [widget.productImage].where((img) => img.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A12),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.2),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFE8C89F), size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    _isWishlisted ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                    color: const Color(0xFFE8C89F),
                    size: 22,
                  ),
                  onPressed: () => _toggleWishlist(),
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Color(0xFFE8C89F), size: 22),
                  onPressed: () => _shareProduct(),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 100),
                
                // Image Section
                SizedBox(
                  height: 400,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD4A574).withValues(alpha: 0.15),
                              blurRadius: 100,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),
                      PageView.builder(
                        itemCount: images.isEmpty ? 1 : images.length,
                        onPageChanged: (i) => setState(() => _currentImageIndex = i),
                        itemBuilder: (context, index) {
                          final imgUrl = images.isEmpty ? '' : images[index];
                          return InteractiveViewer(
                            child: Hero(
                              tag: 'product-${widget.productId}',
                              child: Container(
                                margin: const EdgeInsets.all(30),
                                child: imgUrl.isNotEmpty
                                    ? Image.network(
                                        imgUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                                      )
                                    : _buildPlaceholder(),
                              ),
                            ),
                          );
                        },
                      ),
                      if (images.length > 1)
                        Positioned(
                          bottom: 20,
                          child: Row(
                            children: List.generate(images.length, (i) {
                              final active = i == _currentImageIndex;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: active ? 24 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: active ? const Color(0xFFD4A574) : const Color(0xFF7A7A7F).withValues(alpha: 0.4),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),

                // Info Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16151D).withValues(alpha: 0.95),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                    border: Border.all(color: const Color(0xFFD4A574).withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_productDetail?.discountLabel != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4A574).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD4A574).withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            _productDetail!.discountLabel!,
                            style: const TextStyle(color: Color(0xFFE8C89F), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      Text(
                        _currentName,
                        style: const TextStyle(color: Color(0xFFE8C89F), fontSize: 26, fontWeight: FontWeight.w900, height: 1.2),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _currentPrice,
                            style: const TextStyle(color: Color(0xFFD4A574), fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 10),
                          if (_productDetail?.hasDiscount == true)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                _productDetail!.originalPrice,
                                style: TextStyle(color: const Color(0xFF7A7A7F), fontSize: 16, decoration: TextDecoration.lineThrough),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Inclusive of all taxes',
                        style: TextStyle(color: const Color(0xFF7A7A7F).withValues(alpha: 0.7), fontSize: 12),
                      ),
                      const SizedBox(height: 30),
                      
                      if (_isLoading)
                        const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Color(0xFFD4A574))))
                      else if (_error != null)
                        Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
                      else ...[
                        _buildSectionTitle('Product Overview'),
                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _stripHtml(_productDetail!.description),
                              maxLines: _isDescriptionExpanded ? null : 4,
                              overflow: _isDescriptionExpanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: const Color(0xFF7A7A7F)
                                      .withValues(alpha: 0.9),
                                  fontSize: 15,
                                  height: 1.6),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isDescriptionExpanded =
                                      !_isDescriptionExpanded;
                                });
                                HapticFeedback.selectionClick();
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _isDescriptionExpanded
                                        ? 'Read Less'
                                        : 'Read More',
                                    style: const TextStyle(
                                      color: Color(0xFFD4A574),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Icon(
                                    _isDescriptionExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: const Color(0xFFD4A574),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        if (_productDetail!.specs.isNotEmpty) ...[
                          const SizedBox(height: 30),
                          _buildSectionTitle('Specifications'),
                          const SizedBox(height: 16),
                          ..._productDetail!.specs.split(',').map((s) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFD4A574).withValues(alpha: 0.1)),
                                      child: const Icon(Icons.check, color: Color(0xFFD4A574), size: 14),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(s.trim(), style: const TextStyle(color: Color(0xFF7A7A7F), fontSize: 14))),
                                  ],
                                ),
                              )),
                        ],
                        
                        // Similar Products
                        if (_isLoadingSimilar)
                          const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Color(0xFFD4A574))))
                        else if (_similarProducts.isNotEmpty) ...[
                          const SizedBox(height: 40),
                          _buildSectionTitle('Similar Products'),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 240,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _similarProducts.length,
                              itemBuilder: (context, index) {
                                final product = _similarProducts[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      ProductDetailsScreen.route(
                                        productId: product.id.toString(),
                                        productName: product.name,
                                        productPrice: product.displayPrice,
                                        productImage: product.imageUrl,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 160,
                                    margin: const EdgeInsets.only(right: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1C1B23),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFFD4A574).withValues(alpha: 0.05)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                            child: Container(
                                              width: double.infinity,
                                              child: Image.network(
                                                product.imageUrl,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_rounded, color: Color(0xFFD4A574)),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: Color(0xFFE8C89F), fontSize: 14, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                product.displayPrice,
                                                style: const TextStyle(color: Color(0xFFD4A574), fontSize: 13, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1B23),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, -5))],
                border: Border(top: BorderSide(color: const Color(0xFFD4A574).withValues(alpha: 0.1))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildButton(
                      label: 'Add to Cart',
                      icon: Icons.shopping_bag_outlined,
                      isOnSecondary: true,
                      onTap: () => _addToCart(),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildButton(
                      label: 'Buy Now',
                      icon: Icons.flash_on_rounded,
                      isOnSecondary: false,
                      onTap: () => _handleBuyNow(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: Color(0xFFE8C89F), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5),
    );
  }

  Future<void> _toggleWishlist() async {
    HapticFeedback.mediumImpact();
    final token = await SessionManager.getToken();
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to use wishlist')),
      );
      return;
    }

    final bool wasWishlisted = _isWishlisted;
    setState(() {
      _isWishlisted = !_isWishlisted;
    });

    try {
      final response = await http.post(
        Uri.parse('https://aerthh.newhopeindia17.com/api/wishlist/add'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'product_id': int.tryParse(widget.productId) ?? 0}),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded['message'] ?? (wasWishlisted ? 'Removed from wishlist' : 'Added to wishlist')),
            duration: const Duration(seconds: 1),
          ),
        );
        // Refresh wishlist count in main screen
        MainScreen.mainScreenKey.currentState?.refresh();
        // Refresh status in case the API does something unexpected
        _fetchWishlistStatus();
      } else {
        throw Exception();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isWishlisted = wasWishlisted;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update wishlist')),
        );
      }
    }
  }

  Future<void> _addToCart() async {
    HapticFeedback.mediumImpact();

    final token = await SessionManager.getToken();
    if (token == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add items to cart')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://aerthh.newhopeindia17.com/api/cart/add'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'product_id': int.tryParse(widget.productId) ?? 0,
          'quantity': 1,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(decoded['message'] ?? 'Added to cart successfully'),
              duration: const Duration(seconds: 1),
            ),
          );
          MainScreen.mainScreenKey.currentState?.refresh();
        } else {
          throw Exception(decoded['message'] ?? 'Failed to add to cart');
        }
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to cart: $e')),
      );
    }
  }

  void _handleBuyNow() async {
    HapticFeedback.heavyImpact();
    if (_productDetail == null) return;

    final token = await SessionManager.getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to buy products')),
      );
      return;
    }

    final subtotal = _productDetail!.discountedPrice;
    final shipping = _productDetail!.shippingCost;
    final tax = _productDetail!.taxAmount;
    final total = subtotal + shipping + tax;

    final buyNowItem = _BuyNowItem(
      productId: _productDetail!.id,
      name: _productDetail!.name,
      totalPrice: subtotal, // OrderSummary uses item.totalPrice for subtotal line items
      quantity: 1,
      imageUrl: widget.productImage,
    );

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSummaryScreen(
          cartItems: [buyNowItem],
          subtotal: subtotal,
          shipping: shipping,
          tax: tax,
          total: total,
        ),
      ),
    );
  }

  Widget _buildButton({required String label, required IconData icon, required bool isOnSecondary, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: isOnSecondary
                ? null
                : const LinearGradient(colors: [Color(0xFFD4A574), Color(0xFFE8C89F)]),
            color: isOnSecondary ? const Color(0xFFD4A574).withValues(alpha: 0.1) : null,
            border: isOnSecondary ? Border.all(color: const Color(0xFFD4A574).withValues(alpha: 0.3)) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isOnSecondary ? const Color(0xFFE8C89F) : const Color(0xFF0A0A12), size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isOnSecondary ? const Color(0xFFE8C89F) : const Color(0xFF0A0A12),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(Icons.shopping_bag_rounded, size: 80, color: const Color(0xFFD4A574).withValues(alpha: 0.4)),
    );
  }
}

class _SimilarProduct {
  final int id;
  final String name;
  final String imageUrl;
  final double unitPrice;
  final double taxAmount;

  _SimilarProduct({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.unitPrice,
    required this.taxAmount,
  });

  factory _SimilarProduct.fromJson(Map<String, dynamic> json) {
    return _SimilarProduct(
      id: json['id'] ?? 0,
      name: json['product_name'] ?? '',
      imageUrl: json['image'] ?? '',
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0,
      taxAmount: double.tryParse(json['tax_amount']?.toString() ?? '0') ?? 0,
    );
  }

  String get displayPrice => 'Rs. ${(unitPrice + taxAmount).toStringAsFixed(0)}';
}

class _BuyNowItem {
  final int productId;
  final String name;
  final double totalPrice;
  final int quantity;
  final String imageUrl;

  _BuyNowItem({
    required this.productId,
    required this.name,
    required this.totalPrice,
    required this.quantity,
    required this.imageUrl,
  });
}

class _ProductDetail {
  final int id;
  final String name;
  final String description;
  final String imageUrl;
  final double unitPrice;
  final double discount;
  final String discountType;
  final String specs;
  final List<String> additionalImages;
  final double taxAmount;
  final double shippingCost;

  _ProductDetail({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.unitPrice,
    required this.discount,
    required this.discountType,
    required this.specs,
    required this.additionalImages,
    required this.taxAmount,
    required this.shippingCost,
  });

  factory _ProductDetail.fromJson(Map<String, dynamic> json) {
    return _ProductDetail(
      id: json['id'] ?? 0,
      name: json['product_name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image'] ?? '',
      unitPrice: double.tryParse(json['unit_price']?.toString() ?? '0') ?? 0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0,
      discountType: json['discount_type'] ?? '',
      specs: json['attribute_value'] ?? '',
      additionalImages: (json['additional_image'] as List?)?.map((e) => e.toString()).toList() ?? [],
      taxAmount: double.tryParse(json['tax_amount']?.toString() ?? '0') ?? 0,
      shippingCost: double.tryParse(json['shipping_cost']?.toString() ?? '0') ?? 0,
    );
  }

  bool get hasDiscount => discount > 0;
  double get discountedPrice {
    if (discount <= 0) return unitPrice;
    final d = discountType == 'percent' ? unitPrice * discount / 100 : discount;
    return (unitPrice - d).clamp(0, double.infinity);
  }
  String get displayPrice => 'Rs. ${(discountedPrice + taxAmount).toStringAsFixed(0)}';
  String get originalPrice => 'Rs. ${(unitPrice + taxAmount).toStringAsFixed(0)}';
  String? get discountLabel {
    if (!hasDiscount) return null;
    return discountType == 'percent' ? '${discount.toInt()}% OFF' : 'Flat Rs. ${discount.toInt()} OFF';
  }
}
