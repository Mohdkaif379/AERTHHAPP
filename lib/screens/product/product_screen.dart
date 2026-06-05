import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'product_details_screen.dart';
import '../main_screen.dart';
import '../wishlist/wishlist_screen.dart';
import '../../utils/session_manager.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute(builder: (_) => const ProductScreen());
  }

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  static const Color _bg = Color(0xFF000000);
  static const Color _bg2 = Color(0xFF0D0B08);
  static const Color _bg3 = Color(0xFF14120E);
  static const Color _gold = Color(0xFFB48232);
  static const Color _goldMid = Color(0xFFD4A574);
  static const Color _goldLight = Color(0xFFE8D5A0);
  static const Color _border = Color(0x2EB48232);

  static final Uri _productsUri = Uri.parse(
    'https://aerthh.newhopeindia17.com/api/products',
  );

  final String _logoUrl =
      'https://res.cloudinary.com/dzve5tof6/image/upload/v1780306934/new_mqp4ja.webp';
  final ScrollController _scrollController = ScrollController();
  static const double _collapseOffset = 10;

  double _scrollOffset = 0;
  bool _isLoading = true;
  String? _error;
  List<_ProductData> _products = [];
  final Set<int> _wishlistProductIds = {};
  final Set<int> _cartProductIds = {};

  // Filter / sort
  String _selectedFilter = 'All';
  static const List<String> _filterOptions = [
    'All',
    'Price: Low to High',
    'Price: High to Low',
    'Name: A to Z',
    'Name: Z to A',
  ];

  // Search
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isSearching = false;
  bool _isSearchLoading = false;
  List<_ProductData> _searchResults = [];
  final List<String> _recentSearches = []; // Simple in-memory history

  List<_ProductData> get _filteredProducts {
    final list = List<_ProductData>.from(_products);
    switch (_selectedFilter) {
      case 'Price: Low to High':
        list.sort((a, b) => a.discountedPrice.compareTo(b.discountedPrice));
        break;
      case 'Price: High to Low':
        list.sort((a, b) => b.discountedPrice.compareTo(a.discountedPrice));
        break;
      case 'Name: A to Z':
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'Name: Z to A':
        list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      default:
        break;
    }
    return list;
  }

  bool get _isCollapsed => _scrollOffset > _collapseOffset;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() => _scrollOffset = _scrollController.offset);
    });
    _fetchProducts();
    _fetchWishlist();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    try {
      final uri = _productsUri.replace(queryParameters: {'product_name': query});
      final response = await http.get(uri);

      if (response.statusCode != 200) throw Exception('Search failed');

      final decoded = jsonDecode(response.body);
      final rawProducts = decoded is List
          ? decoded
          : decoded is Map<String, dynamic>
              ? decoded['data']
              : null;

      if (rawProducts is! List) throw const FormatException('Invalid response');

      final results = rawProducts
          .whereType<Map<String, dynamic>>()
          .map(_ProductData.fromJson)
          .where((p) => p.isActive && p.name.isNotEmpty)
          // Strict relevance filter
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .toList();

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearchLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearchLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _isSearching = true;
          _searchResults = [];
          _isSearchLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSearching = true;
        _isSearchLoading = true;
      });
    }

    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
      if (query.length > 2 && !_recentSearches.contains(query)) {
        _recentSearches.add(query);
        if (_recentSearches.length > 10) _recentSearches.removeAt(0);
      }
    });
  }

  void _onSearchTap() {
    setState(() {
      _isSearching = true;
    });
  }

  void _onSearchCancel() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchResults = [];
    });
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.get(_productsUri);
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

      final products = rawProducts
          .whereType<Map<String, dynamic>>()
          .map(_ProductData.fromJson)
          .where(
            (product) =>
                product.isActive &&
                product.name.isNotEmpty &&
                product.imageUrl.isNotEmpty,
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load products';
        _isLoading = false;
      });
    }
  }

  void _openProductDetails(_ProductData product) {
    if (!_recentSearches.contains(product.name)) {
      setState(() {
        _recentSearches.add(product.name);
        if (_recentSearches.length > 10) _recentSearches.removeAt(0);
      });
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      ProductDetailsScreen.route(
        productId: '${product.id}',
        productName: product.name,
        productPrice: product.displayPrice,
        productImage: product.imageUrl,
      ),
    );
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
        final List rawData = decoded is List ? decoded : (decoded['data'] ?? []);
        
        final Set<int> ids = {};
        for (var item in rawData) {
          if (item['product'] != null && item['product']['id'] != null) {
            ids.add(int.parse(item['product']['id'].toString()));
          }
        }

        if (!mounted) return;
        setState(() {
          _wishlistProductIds.clear();
          _wishlistProductIds.addAll(ids);
        });
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

    final int productId = product.id;
    final bool isAdding = !_wishlistProductIds.contains(productId);

    // Only allow adding on Product screen as requested
    if (!isAdding) return;

    setState(() {
      _wishlistProductIds.add(productId);
    });

    try {
      final response = await http.post(
        Uri.parse('https://aerthh.newhopeindia17.com/api/wishlist/add'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'product_id': productId}),
      );

      final decoded = jsonDecode(response.body);
      final String msg = decoded['message'] ?? (isAdding ? 'Added to wishlist' : 'Removed from wishlist');

      if (response.statusCode == 200 && decoded['status'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
        );
        MainScreen.mainScreenKey.currentState?.refresh();
      } else {
        throw Exception(msg);
      }
    } catch (e) {
      setState(() {
        if (isAdding) {
          _wishlistProductIds.remove(productId);
        } else {
          _wishlistProductIds.add(productId);
        }
      });
      if (!mounted) return;
      
      String errorMsg = e.toString().replaceFirst('Exception: ', '');
      if (errorMsg.contains('ClientException')) {
        errorMsg = 'Network error. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent.withValues(alpha: 0.8)),
      );
    }
  }

  Future<void> _addToCart(_ProductData product) async {
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
          'product_id': product.id,
          'quantity': 1,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          setState(() {
            _cartProductIds.add(product.id);
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(decoded['message'] ?? '${product.name} added to cart'),
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

  Widget _buildTopBar() {
    final canPop = Navigator.of(context).canPop();

    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (canPop) ...[
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                    },
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: _goldMid,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  _logoUrl,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _bg3,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Icon(
                      Icons.business_center_outlined,
                      color: _goldMid,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                'Aerthh',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  color: _goldLight,
                  fontSize: 16,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          _WishlistButton(border: _border, gold: _gold, goldMid: _goldMid),
        ],
      ),
    );
  }

  Widget _buildCurvedSearch() {
    return Container(
      decoration: const BoxDecoration(
        color: _bg2,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: _SearchField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        onTap: _onSearchTap,
        onBackTap: _onSearchCancel,
        showBackButton: _isSearching,
        border: _border,
        goldMid: _goldMid,
        goldLight: _goldLight,
      ),
    );
  }

  Widget _buildCompactSearch() {
    return Container(
      color: _bg.withValues(alpha: 0.97),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: _SearchField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        onTap: _onSearchTap,
        onBackTap: _onSearchCancel,
        showBackButton: _isSearching,
        border: _border,
        goldMid: _goldMid,
        goldLight: _goldLight,
      ),
    );
  }

  Widget _buildSearchSuggestionsDropdown() {
    if (_searchController.text.isEmpty) return const SizedBox.shrink();

    // Show top 10 products as suggestions
    final suggestions = _searchResults.take(10).toList();

    return Positioned(
      top: 0,
      left: 16,
      right: 16,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: _bg3,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PRODUCTS',
                    style: TextStyle(
                      color: _goldMid.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'Showing ${suggestions.length} products',
                    style: TextStyle(
                      color: _goldMid.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),

            if (_isSearchLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _gold)),
              )
            else if (suggestions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No products found',
                    style: TextStyle(color: _goldMid.withValues(alpha: 0.4), fontSize: 13),
                  ),
                ),
              )
            else
              ...suggestions.map((p) => Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 45,
                      height: 45,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.network(p.imageUrl, fit: BoxFit.contain),
                    ),
                    title: Text(
                      p.name,
                      style: const TextStyle(
                        color: _goldLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      p.displayPrice,
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _goldMid.withValues(alpha: 0.4)),
                    onTap: () => _openProductDetails(p),
                  ),
                  Divider(height: 1, color: _border, indent: 16, endIndent: 16),
                ],
              )),

            // Footer
            InkWell(
              onTap: () {
                setState(() => _isSearching = false);
              },
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View all products',
                      style: TextStyle(
                        color: _goldLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: _goldLight),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'All Products',
            style: TextStyle(
              color: _goldLight,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          // ── Filter Dropdown ──────────────────────────────
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _bg3,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedFilter,
                dropdownColor: _bg3,
                iconEnabledColor: _goldMid,
                icon: const Icon(Icons.filter_list_rounded, size: 16),
                isDense: true,
                style: TextStyle(color: _goldMid, fontSize: 11),
                items: _filterOptions.map((opt) {
                  return DropdownMenuItem(
                    value: opt,
                    child: Text(
                      opt,
                      style: TextStyle(
                        color: _selectedFilter == opt ? _goldLight : _goldMid,
                        fontWeight: _selectedFilter == opt
                            ? FontWeight.w700
                            : FontWeight.w400,
                        fontSize: 11,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedFilter = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 260,
          child: Center(
            child: SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: _gold),
            ),
          ),
        ),
      );
    }

    if (_error != null || _products.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              color: _bg3,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, color: _gold, size: 30),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'No products available',
                  style: TextStyle(
                    color: _goldLight.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _fetchProducts,
                    child: const Text('Retry'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          final product = _filteredProducts[index];
          return _ProductCard(
            product: product,
            gold: _gold,
            goldMid: _goldMid,
            goldLight: _goldLight,
            bg3: _bg3,
            border: _border,
            isWishlisted: _wishlistProductIds.contains(product.id),
            isInCart: _cartProductIds.contains(product.id),
            onTap: () => _openProductDetails(product),
            onWishlistTap: () => _toggleWishlist(product),
            onAddToCartTap: () => _addToCart(product),
          );
        }, childCount: _filteredProducts.length),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.66,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                height: _isCollapsed ? 0 : 68,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: _buildCurvedSearch(),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                height: _isCollapsed ? 54 : 0,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: _buildCompactSearch(),
              ),
              Expanded(
                child: Stack(
                  children: [
                    CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverToBoxAdapter(child: _buildSectionHeader()),
                        _buildProductGrid(),
                      ],
                    ),
                    if (_isSearching) _buildSearchSuggestionsDropdown(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductData {
  const _ProductData({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.unitPrice,
    required this.discount,
    required this.discountType,
    required this.isActive,
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
    );
  }

  final int id;
  final String name;
  final String imageUrl;
  final double unitPrice;
  final double discount;
  final String discountType;
  final bool isActive;

  bool get hasDiscount => discount > 0 && discountedPrice < unitPrice;

  double get discountedPrice {
    if (discount <= 0) return unitPrice;

    final discountAmount = discountType == 'percent'
        ? unitPrice * discount / 100
        : discount;
    final price = unitPrice - discountAmount;
    return price < 0 ? 0 : price;
  }

  String get displayPrice => _formatMoney(discountedPrice);

  String get originalPrice => _formatMoney(unitPrice);

  String? get discountLabel {
    if (!hasDiscount) return null;

    if (discountType == 'percent') {
      return '${_formatNumber(discount)}% OFF';
    }

    return 'Flat ${_formatNumber(discount)} OFF';
  }

  static bool _asBool(dynamic value) {
    return value == true || value == 1 || value == '1';
  }

  static double _asDouble(dynamic value) {
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _formatMoney(double value) {
    return 'Rs. ${_formatNumber(value)}';
  }

  static String _formatNumber(double value) {
    final rounded = value.roundToDouble();
    return value == rounded
        ? rounded.toInt().toString()
        : value.toStringAsFixed(2);
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.border,
    required this.goldMid,
    required this.goldLight,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onBackTap,
    this.showBackButton = false,
  });

  final Color border, goldMid, goldLight;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onBackTap;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          if (showBackButton)
            GestureDetector(
              onTap: onBackTap,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.arrow_back_rounded, color: goldMid, size: 20),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(Icons.search_rounded, color: goldMid, size: 18),
            ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              onTap: onTap,
              style: TextStyle(color: goldLight, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search products, brands and more...',
                hintStyle: TextStyle(
                  color: goldMid.withValues(alpha: 0.4),
                  fontSize: 13,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller != null && controller!.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                controller!.clear();
                if (onChanged != null) onChanged!('');
              },
              child: Icon(Icons.close_rounded, color: goldMid, size: 16),
            ),
        ],
      ),
    );
  }
}

class _WishlistButton extends StatelessWidget {
  const _WishlistButton({
    required this.border,
    required this.gold,
    required this.goldMid,
  });

  final Color border, gold, goldMid;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WishlistScreen()),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: border),
              color: gold.withValues(alpha: 0.08),
            ),
            child: Icon(Icons.favorite_border_rounded, color: goldMid, size: 20),
          ),
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: gold,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF000000), width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                '${MainScreen.mainScreenKey.currentState?.wishlistCount ?? 0}',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.gold,
    required this.goldMid,
    required this.goldLight,
    required this.bg3,
    required this.border,
    required this.isWishlisted,
    required this.isInCart,
    required this.onTap,
    required this.onWishlistTap,
    required this.onAddToCartTap,
  });

  final _ProductData product;
  final Color gold, goldMid, goldLight, bg3, border;
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
            color: bg3,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
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
                        color: gold.withValues(alpha: 0.07),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(14),
                        ),
                      ),
                      child: Image.network(
                        product.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 36,
                            color: gold.withValues(alpha: 0.45),
                          ),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;

                          return Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: gold,
                                value:
                                    loadingProgress.expectedTotalBytes == null
                                    ? null
                                    : loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!,
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
                            color: gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: gold.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: goldMid,
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
                              color: isWishlisted ? goldLight : Colors.white,
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
                  style: TextStyle(
                    color: goldLight,
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
                        style: TextStyle(
                          color: goldMid,
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
                            color: goldMid.withValues(alpha: 0.45),
                            fontSize: 10,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: goldMid.withValues(alpha: 0.45),
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
                        gradient: LinearGradient(colors: [gold, goldLight]),
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