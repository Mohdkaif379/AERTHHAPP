import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../main_screen.dart';
import 'brand_detail_screen.dart';

// ─── Color constants ──────────────────────────────────────────────────────────
const _gold = Color(0xFFD4A574);
const _goldMid = Color(0xFFC49A6C);
const _goldLight = Color(0xFFE8C89F);
const _bg = Color(0xFF0A0A12);
const _bg3 = Color(0xFF1C1B23);
const _border = Color(0xFF2E2B38);

// ─── Model ───────────────────────────────────────────────────────────────────
class Brand {
  const Brand({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.isActive,
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
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

// ─── Screen ───────────────────────────────────────────────────────────────────
class BrandScreen extends StatefulWidget {
  const BrandScreen({super.key});

  @override
  State<BrandScreen> createState() => _BrandScreenState();
}

class _BrandScreenState extends State<BrandScreen> {
  static final Uri _brandsUri = Uri.parse(
    'https://aerthh.newhopeindia17.com/api/brands',
  );

  bool _isLoading = true;
  String? _error;
  List<Brand> _brands = [];

  @override
  void initState() {
    super.initState();
    _fetchBrands();
  }

  Future<void> _fetchBrands() async {
    setState(() {
      _isLoading = true;
      _error = null;
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
          .map(Brand.fromJson)
          .where((brand) => brand.isActive && brand.imageUrl.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _brands = brands;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load brands';
        _isLoading = false;
      });
    }
  }

  void _onNavbarIndexChanged(int index) {
    // Brand screen is accessed from Home, so if user clicks Home tab (0), 
    // we just pop. Otherwise pop and switch tab.
    if (index == 0) {
      Navigator.of(context).pop();
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
        currentIndex: 0, // Highlight Home as it's the parent section
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _buildHeaderButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 16),
          const Text(
            'Premium Brands',
            style: TextStyle(
              color: _goldLight,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              decoration: TextDecoration.none,
            ),
          ),
          const Spacer(),
          _buildHeaderButton(
            icon: Icons.refresh_rounded,
            onTap: _fetchBrands,
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
            border: Border.all(color: _border),
          ),
          child: Icon(icon, color: _goldLight, size: 18),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: _gold,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: _gold,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(
                color: _goldLight,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: _fetchBrands,
              child: const Text('Retry', style: TextStyle(color: _goldMid)),
            ),
          ],
        ),
      );
    }

    if (_brands.isEmpty) {
      return const Center(
        child: Text(
          'No brands available',
          style: TextStyle(
            color: _goldLight,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
            fontSize: 14,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      itemCount: _brands.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, index) {
        final brand = _brands[index];
        return _BrandCardWidget(
          brand: brand,
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BrandDetailScreen(brand: brand),
              ),
            );
          },
        );
      },
    );
  }
}

class _BrandCardWidget extends StatelessWidget {
  const _BrandCardWidget({
    required this.brand,
    required this.onTap,
  });

  final Brand brand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: _bg3,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _gold.withValues(alpha: 0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.04),
                  ),
                  child: Image.network(
                    brand.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.business_rounded,
                      color: _goldMid,
                      size: 32,
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: _border, width: 0.8),
                  ),
                ),
                child: Text(
                  brand.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _goldLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.2,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
