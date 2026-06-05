import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../categories/category_screen.dart' show Category;
import '../categories/categories_detail_screen.dart';
import '../brands/brand_screen.dart';
import '../brands/brand_detail_screen.dart';
import '../product/product_details_screen.dart';
import '../product/product_screen.dart';
import '../wishlist/wishlist_screen.dart';
import '../main_screen.dart';
import '../../utils/session_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onProductsTap});

  final VoidCallback? onProductsTap;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ─── Colors ───────────────────────────────────────────────────────────────
  static const Color _bg = Color(0xFF000000);
  static const Color _bg2 = Color(0xFF0D0B08);
  static const Color _bg3 = Color(0xFF14120E);
  static const Color _gold = Color(0xFFB48232);
  static const Color _goldMid = Color(0xFFD4A574);
  static const Color _goldLight = Color(0xFFE8D5A0);
  static const Color _border = Color(0x2EB48232);

  final String _logoUrl =
      "https://res.cloudinary.com/dzve5tof6/image/upload/v1780306934/new_mqp4ja.webp";

  final ScrollController _scrollController = ScrollController();
  static const double _collapseOffset = 10;

  double _scrollOffset = 0;
  bool get _isCollapsed => _scrollOffset > _collapseOffset;

  // ─── Banner carousel ──────────────────────────────────────────────────────
  final PageController _bannerController = PageController();
  static final Uri _bannersUri = Uri.parse(
    'https://aerthh.newhopeindia17.com/api/banners',
  );
  static final Uri _categoriesUri = Uri.parse(
    'https://aerthh.newhopeindia17.com/api/categories',
  );
  static final Uri _productsUri = Uri.parse(
    'https://aerthh.newhopeindia17.com/api/products',
  );
  static final Uri _topSellingUri = Uri.parse(
    'https://aerthh.newhopeindia17.com/api/top-selling',
  );
  static final Uri _brandsUri = Uri.parse(
    'https://aerthh.newhopeindia17.com/api/brands',
  );
  static final Uri _bestSellersUri = Uri.parse(
    'https://aerthh.newhopeindia17.com/api/best-sellers',
  );
  static final Uri _reviewsUri = Uri.parse(
    'https://aerthh.newhopeindia17.com/api/reviews',
  );

  Timer? _bannerTimer;
  int _currentBanner = 0;
  bool _isLoadingBanners = true;
  String? _bannerError;
  List<_BannerData> _banners = [];

  // ─── Categories ───────────────────────────────────────────────────────────
  bool _isLoadingCategories = true;
  String? _categoryError;
  List<Category> _categories = [];
  int? _selectedCategory;

  // Products
  bool _isLoadingProducts = true;
  String? _productError;
  List<_ProductData> _featuredProducts = [];
  bool _isLoadingTopSelling = true;
  String? _topSellingError;
  List<_ProductData> _topSellingProducts = [];

  // Brands
  bool _isLoadingBrands = true;
  String? _brandError;
  List<_BrandData> _brands = [];

  // Best Sellers
  bool _isLoadingBestSellers = true;
  String? _bestSellingError;
  List<_VendorData> _bestSellers = [];

  // Reviews
  bool _isLoadingReviews = true;
  String? _reviewError;
  List<_ReviewData> _reviews = [];

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

  List<_ProductData> _applyFilter(List<_ProductData> source) {
    final list = List<_ProductData>.from(source);
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

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      setState(() => _scrollOffset = _scrollController.offset);
    });

    _fetchBanners();
    _fetchCategories();
    _fetchProducts();
    _fetchTopSellingProducts();
    _fetchBrands();
    _fetchBestSellers();
    _fetchReviews();
    _fetchWishlist();
  }

  Future<void> _fetchBanners() async {
    try {
      final response = await http.get(_bannersUri);
      if (response.statusCode != 200) {
        throw Exception('Banner API failed: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const FormatException('Banner API response is not a list');
      }

      final banners = decoded
          .whereType<Map<String, dynamic>>()
          .map(_BannerData.fromJson)
          .where((banner) => banner.isPublished && banner.imageUrl.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _banners = banners;
        _currentBanner = 0;
        _isLoadingBanners = false;
        _bannerError = null;
      });
      _startBannerTimer();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingBanners = false;
        _bannerError = 'Unable to load banners';
      });
    }
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _categoryError = null;
    });

    try {
      final response = await http.get(_categoriesUri);
      if (response.statusCode != 200) {
        throw Exception('Category API failed: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Category API response is invalid');
      }

      final data = decoded['data'];
      if (data is! List) {
        throw const FormatException('Category API data is invalid');
      }

      final categories = data
          .whereType<Map<String, dynamic>>()
          .map(Category.fromJson)
          .where(
            (category) =>
                category.isActive &&
                category.name.isNotEmpty &&
                category.imageUrl.isNotEmpty,
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedCategory = null;
        _isLoadingCategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categoryError = 'Unable to load categories';
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _productError = null;
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
          .take(6)
          .toList();

      if (!mounted) return;
      setState(() {
        _featuredProducts = products;
        _isLoadingProducts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _productError = 'Unable to load products';
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _fetchTopSellingProducts() async {
    setState(() {
      _isLoadingTopSelling = true;
      _topSellingError = null;
    });

    try {
      final response = await http.get(_topSellingUri);
      if (response.statusCode != 200) {
        throw Exception('Top selling API failed: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final rawProducts = decoded is List
          ? decoded
          : decoded is Map<String, dynamic>
          ? decoded['data']
          : null;

      if (rawProducts is! List) {
        throw const FormatException('Top selling API response is invalid');
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
          .take(4)
          .toList();

      if (!mounted) return;
      setState(() {
        _topSellingProducts = products;
        _isLoadingTopSelling = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _topSellingError = 'Unable to load top selling products';
        _isLoadingTopSelling = false;
      });
    }
  }

  Future<void> _fetchBrands() async {
    setState(() {
      _isLoadingBrands = true;
      _brandError = null;
    });

    try {
      final response = await http.get(_brandsUri);
      if (response.statusCode != 200) {
        throw Exception('Brands API failed: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final rawBrands = decoded is List
          ? decoded
          : decoded is Map<String, dynamic>
          ? decoded['data']
          : null;

      if (rawBrands is! List) {
        throw const FormatException('Brands API response is invalid');
      }

      final brands = rawBrands
          .whereType<Map<String, dynamic>>()
          .map(_BrandData.fromJson)
          .where((brand) => brand.isActive && brand.imageUrl.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _brands = brands;
        _isLoadingBrands = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _brandError = 'Unable to load brands';
        _isLoadingBrands = false;
      });
    }
  }

  Future<void> _fetchBestSellers() async {
    setState(() {
      _isLoadingBestSellers = true;
      _bestSellingError = null;
    });

    try {
      final response = await http.get(_bestSellersUri);
      if (response.statusCode != 200) {
        throw Exception('Best sellers API failed: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final rawVendors = decoded is List
          ? decoded
          : decoded is Map<String, dynamic>
          ? decoded['data']
          : null;

      if (rawVendors is! List) {
        throw const FormatException('Best sellers API response is invalid');
      }

      final vendors = rawVendors
          .whereType<Map<String, dynamic>>()
          .map(_VendorData.fromJson)
          .where((vendor) => vendor.status && vendor.imageUrl.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _bestSellers = vendors;
        _isLoadingBestSellers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bestSellingError = 'Unable to load best sellers';
        _isLoadingBestSellers = false;
      });
    }
  }

  Future<void> _fetchReviews() async {
    setState(() {
      _isLoadingReviews = true;
      _reviewError = null;
    });

    try {
      final response = await http.get(_reviewsUri);
      if (response.statusCode != 200) {
        throw Exception('Reviews API failed: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final rawReviews = decoded is List
          ? decoded
          : decoded is Map<String, dynamic>
          ? decoded['data']
          : null;

      if (rawReviews is! List) {
        throw const FormatException('Reviews API response is invalid');
      }

      final reviews = rawReviews
          .whereType<Map<String, dynamic>>()
          .map(_ReviewData.fromJson)
          .toList();

      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _isLoadingReviews = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reviewError = 'Unable to load reviews';
        _isLoadingReviews = false;
      });
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

  Future<void> _toggleWishlist(int productId) async {
    HapticFeedback.mediumImpact();
    final token = await SessionManager.getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to use wishlist')),
      );
      return;
    }

    final bool isAdding = !_wishlistProductIds.contains(productId);

    // Only allow adding on Home screen as requested
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
      // Revert on error
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

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    if (_banners.length < 2) return;

    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_bannerController.hasClients || _banners.length < 2) {
        return;
      }

      final next = (_currentBanner + 1) % _banners.length;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
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
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearchLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _isSearchLoading = false; });
    }
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

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  void _openProductDetails(BuildContext context, _ProductData product) {
    HapticFeedback.mediumImpact();
    // Add to history when clicked
    if (!_recentSearches.contains(product.name)) {
      setState(() {
        _recentSearches.add(product.name);
        if (_recentSearches.length > 10) _recentSearches.removeAt(0);
      });
    }
    Navigator.of(context).push(
      ProductDetailsScreen.route(
        productId: '${product.id}',
        productName: product.name,
        productPrice: product.displayPrice,
        productImage: product.imageUrl,
      ),
    );
  }

  void _openProductsPage() {
    HapticFeedback.selectionClick();
    if (widget.onProductsTap != null) {
      widget.onProductsTap!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ProductScreen()),
    );
  }

  void _openBrandsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const BrandScreen()),
    );
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

  // ─── Top bar ──────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
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

  // ─── Curved search ────────────────────────────────────────────────────────
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

  // ─── Compact sticky search ────────────────────────────────────────────────
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

  // ─── Search Suggestions Dropdown ──────────────────────────────────────────
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
                    onTap: () => _openProductDetails(context, p),
                  ),
                  Divider(height: 1, color: _border, indent: 16, endIndent: 16),
                ],
              )),

            // Footer
            InkWell(
              onTap: _openProductsPage,
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

  // ─── Banner carousel ──────────────────────────────────────────────────────
  Widget _buildBannerCarousel() {
    if (_isLoadingBanners) {
      return _BannerPlaceholder(
        border: _border,
        bg: _bg3,
        gold: _gold,
        goldLight: _goldLight,
        child: const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: _gold),
        ),
      );
    }

    if (_bannerError != null || _banners.isEmpty) {
      return _BannerPlaceholder(
        border: _border,
        bg: _bg3,
        gold: _gold,
        goldLight: _goldLight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_not_supported_outlined, color: _gold, size: 30),
            const SizedBox(height: 8),
            Text(
              _bannerError ?? 'No banners available',
              style: TextStyle(
                color: _goldLight.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _bannerController,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _currentBanner = i),
            itemBuilder: (context, index) {
              final b = _banners[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: _bg3,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.network(
                  b.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: _bg3,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: _gold.withValues(alpha: 0.7),
                      size: 34,
                    ),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;

                    return Container(
                      color: _bg3,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: _gold,
                        value: loadingProgress.expectedTotalBytes == null
                            ? null
                            : loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),

        // Dot indicators
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (i) {
            final active = i == _currentBanner;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: active ? _gold : _gold.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ─── Category carousel ────────────────────────────────────────────────────
  Widget _buildCategoryCarousel() {
    if (_isLoadingCategories) {
      return const SizedBox(
        height: 96,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: _gold),
          ),
        ),
      );
    }

    if (_categoryError != null || _categories.isEmpty) {
      return SizedBox(
        height: 78,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.category_outlined, color: _gold, size: 20),
              const SizedBox(width: 8),
              Text(
                _categoryError ?? 'No categories available',
                style: TextStyle(
                  color: _goldLight.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 108,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final selected = index == _selectedCategory;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = index);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryDetailScreen(category: cat),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              width: 86,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 72,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: selected ? _gold.withValues(alpha: 0.15) : _bg3,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? _gold : _border,
                        width: selected ? 1.2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      cat.imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: _gold.withValues(alpha: 0.08),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: _goldMid.withValues(alpha: 0.65),
                          size: 24,
                        ),
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;

                        return Container(
                          color: _gold.withValues(alpha: 0.08),
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _gold,
                              value: loadingProgress.expectedTotalBytes == null
                                  ? null
                                  : loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 7),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      cat.name,
                      style: TextStyle(
                        color: selected
                            ? _goldLight
                            : _goldMid.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Brand carousel ──────────────────────────────────────────────────────
  Widget _buildBrandCarousel() {
    if (_isLoadingBrands) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: _gold),
          ),
        ),
      );
    }

    if (_brandError != null || _brands.isEmpty) {
      return SizedBox(
        height: 60,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.business_outlined, color: _gold, size: 20),
              const SizedBox(width: 8),
              Text(
                _brandError ?? 'No brands available',
                style: TextStyle(
                  color: _goldLight.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _brands.length,
        itemBuilder: (context, index) {
          final brand = _brands[index];
          return GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              // Convert _BrandData to Brand model for navigation
              final brandObj = Brand(
                id: brand.id,
                name: brand.name,
                imageUrl: brand.imageUrl,
                isActive: brand.isActive,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BrandDetailScreen(brand: brandObj),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 80,
              child: Column(
                children: [
                  Container(
                    height: 64,
                    width: 64,
                    decoration: BoxDecoration(
                      color: _bg3,
                      shape: BoxShape.circle,
                      border: Border.all(color: _border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      brand.imageUrl,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: _gold.withValues(alpha: 0.08),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: _goldMid.withValues(alpha: 0.65),
                          size: 20,
                        ),
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: _gold.withValues(alpha: 0.08),
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _gold,
                              value: loadingProgress.expectedTotalBytes == null
                                  ? null
                                  : loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    brand.name,
                    style: TextStyle(
                      color: _goldMid.withValues(alpha: 0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Best Sellers carousel ────────────────────────────────────────────────
  Widget _buildBestSellersCarousel() {
    if (_isLoadingBestSellers) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: _gold),
          ),
        ),
      );
    }

    if (_bestSellingError != null || _bestSellers.isEmpty) {
      return SizedBox(
        height: 60,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_outlined, color: _gold, size: 20),
              const SizedBox(width: 8),
              Text(
                _bestSellingError ?? 'No best sellers available',
                style: TextStyle(
                  color: _goldLight.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _bestSellers.length,
        itemBuilder: (context, index) {
          final vendor = _bestSellers[index];
          return Container(
            margin: const EdgeInsets.only(right: 14),
            width: 100,
            child: Column(
              children: [
                Container(
                  height: 76,
                  width: 76,
                  decoration: BoxDecoration(
                    color: _bg3,
                    shape: BoxShape.circle,
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: _gold.withValues(alpha: 0.05),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    vendor.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: _gold.withValues(alpha: 0.08),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: _goldMid.withValues(alpha: 0.65),
                        size: 28,
                      ),
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: _gold.withValues(alpha: 0.08),
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _gold,
                            value: loadingProgress.expectedTotalBytes == null
                                ? null
                                : loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  vendor.name,
                  style: TextStyle(
                    color: _goldLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: _goldMid.withValues(alpha: 0.6),
                      size: 8,
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        vendor.city,
                        style: TextStyle(
                          color: _goldMid.withValues(alpha: 0.6),
                          fontSize: 8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Reviews Carousel ─────────────────────────────────────────────────────
  Widget _buildReviewsCarousel() {
    if (_isLoadingReviews) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: _gold),
          ),
        ),
      );
    }

    if (_reviewError != null || _reviews.isEmpty) {
      return SizedBox(
        height: 60,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.rate_review_outlined, color: _gold, size: 20),
              const SizedBox(width: 8),
              Text(
                _reviewError ?? 'No reviews available',
                style: TextStyle(
                  color: _goldLight.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _reviews.length,
        itemBuilder: (context, index) {
          final review = _reviews[index];
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _bg3,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _gold.withValues(alpha: 0.1),
                      backgroundImage: review.customer.imageUrl.isNotEmpty
                          ? NetworkImage(review.customer.imageUrl)
                          : null,
                      child: review.customer.imageUrl.isEmpty
                          ? Icon(Icons.person, color: _goldMid, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            review.customer.name,
                            style: const TextStyle(
                              color: _goldLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: List.generate(5, (i) {
                              return Icon(
                                i < review.rating
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: _gold,
                                size: 10,
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Text(
                    review.comment,
                    style: TextStyle(
                      color: _goldLight.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Section header ───────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAllTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _goldLight,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSeeAllTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  'See all ➜',
                  style: TextStyle(
                    color: _gold.withValues(alpha: 0.6),
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid({
    required bool isLoading,
    required String? error,
    required List<_ProductData> products,
    required EdgeInsets padding,
    required VoidCallback onRetry,
    required String emptyMessage,
  }) {
    if (isLoading) {
      return const SliverToBoxAdapter(
        child: SizedBox(
          height: 220,
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

    if (error != null || products.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: padding,
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
                  error ?? emptyMessage,
                  style: TextStyle(
                    color: _goldLight.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  TextButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: padding,
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          final product = products[index];
          return _ProductCard(
            product: product,
            gold: _gold,
            goldMid: _goldMid,
            goldLight: _goldLight,
            bg3: _bg3,
            border: _border,
            isWishlisted: _wishlistProductIds.contains(product.id),
            isInCart: _cartProductIds.contains(product.id),
            onTap: () => _openProductDetails(context, product),
            onWishlistTap: () => _toggleWishlist(product.id),
            onAddToCartTap: () => _addToCart(product),
          );
        }, childCount: products.length),
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
              // ── Always visible: logo + wishlist ──────────────────────────
              _buildTopBar(),

              const SizedBox(height: 10),

              // ── Curved search — collapses on scroll ───────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                height: _isCollapsed ? 0 : 68,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: _buildCurvedSearch(),
              ),

              // ── Compact sticky search ─────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                height: _isCollapsed ? 54 : 0,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: _buildCompactSearch(),
              ),

              // ── Scrollable content ────────────────────────────────────────
              Expanded(
                child: Stack(
                  children: [
                    CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        // Banner carousel
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 16),
                            child: _buildBannerCarousel(),
                          ),
                        ),

                        // Category carousel
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildCategoryCarousel(),
                          ),
                        ),

                        SliverToBoxAdapter(
                          child: _buildSectionHeader(
                            'Top Selling Products',
                            onSeeAllTap: _openProductsPage,
                          ),
                        ),
                        _buildProductGrid(
                          isLoading: _isLoadingTopSelling,
                          error: _topSellingError,
                          products: _applyFilter(_topSellingProducts),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                          onRetry: _fetchTopSellingProducts,
                          emptyMessage: 'No top selling products available',
                        ),

                        SliverToBoxAdapter(
                          child: _buildSectionHeader(
                            'Featured Products',
                            onSeeAllTap: _openProductsPage,
                          ),
                        ),
                        _buildProductGrid(
                          isLoading: _isLoadingProducts,
                          error: _productError,
                          products: _applyFilter(_featuredProducts),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
                          onRetry: _fetchProducts,
                          emptyMessage: 'No products available',
                        ),

                        SliverToBoxAdapter(
                          child: _buildSectionHeader(
                            'Shop by Brand',
                            onSeeAllTap: _openBrandsPage,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 22),
                            child: _buildBrandCarousel(),
                          ),
                        ),

                        SliverToBoxAdapter(
                          child: _buildSectionHeader('Customer Feedback'),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 22),
                            child: _buildReviewsCarousel(),
                          ),
                        ),

                        SliverToBoxAdapter(
                          child: _buildSectionHeader('Best Seller'),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 30),
                            child: _buildBestSellersCarousel(),
                          ),
                        ),
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

// ─── Banner data model ────────────────────────────────────────────────────────

class _BannerData {
  const _BannerData({required this.imageUrl, required this.isPublished});

  factory _BannerData.fromJson(Map<String, dynamic> json) {
    final isPublished = json['is_published'];

    return _BannerData(
      imageUrl: json['image']?.toString() ?? '',
      isPublished:
          isPublished == true || isPublished == 1 || isPublished == '1',
    );
  }

  final String imageUrl;
  final bool isPublished;
}

class _BrandData {
  const _BrandData({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.isActive,
  });

  factory _BrandData.fromJson(Map<String, dynamic> json) {
    return _BrandData(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      imageUrl: json['image']?.toString() ?? '',
      isActive:
          json['status'] == 1 ||
          json['status'] == '1' ||
          json['status'] == true,
    );
  }

  final int id;
  final String name;
  final String imageUrl;
  final bool isActive;
}

class _VendorData {
  const _VendorData({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.status,
    required this.city,
    required this.totalSold,
  });

  factory _VendorData.fromJson(Map<String, dynamic> json) {
    return _VendorData(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      imageUrl: json['image']?.toString() ?? '',
      status:
          json['status'] == 1 ||
          json['status'] == '1' ||
          json['status'] == true,
      city: json['city']?.toString() ?? '',
      totalSold: json['total_sold']?.toString() ?? '0',
    );
  }

  final int id;
  final String name;
  final String imageUrl;
  final bool status;
  final String city;
  final String totalSold;
}

class _ReviewData {
  const _ReviewData({
    required this.id,
    required this.rating,
    required this.comment,
    required this.customer,
  });

  factory _ReviewData.fromJson(Map<String, dynamic> json) {
    return _ReviewData(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      rating: int.tryParse(json['rating']?.toString() ?? '') ?? 0,
      comment: json['comment']?.toString() ?? '',
      customer: _CustomerInfo.fromJson(json['customer'] ?? {}),
    );
  }

  final int id;
  final int rating;
  final String comment;
  final _CustomerInfo customer;
}

class _CustomerInfo {
  const _CustomerInfo({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  factory _CustomerInfo.fromJson(Map<String, dynamic> json) {
    final firstName = json['first_name']?.toString() ?? '';
    final lastName = json['last_name']?.toString() ?? '';

    return _CustomerInfo(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: '$firstName $lastName'.trim(),
      imageUrl: json['profile_image']?.toString() ?? '',
    );
  }

  final int id;
  final String name;
  final String imageUrl;
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder({
    required this.border,
    required this.bg,
    required this.gold,
    required this.goldLight,
    required this.child,
  });

  final Color border, bg, gold, goldLight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

// Product data model

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

  // Search field
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

// ─── Wishlist button ──────────────────────────────────────────────────────────

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

// ─── Product card ─────────────────────────────────────────────────────────────

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
