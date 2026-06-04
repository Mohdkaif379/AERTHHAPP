import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../main_screen.dart';
import '../order/order_summary.dart';
import '../../utils/session_manager.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<_CartItem> _cartItems = [];
  bool _isLoading = true;
  String? _error;

  static const _baseUrl = 'https://aerthh.newhopeindia17.com/api';
  static const _storageBase = 'https://aerthh.newhopeindia17.com/storage/app/public/';

  double get _subtotal =>
      _cartItems.fold(0, (sum, item) => sum + item.totalPrice);
  double get _totalShipping =>
      _cartItems.fold(0, (sum, item) => sum + item.shippingCost);
  double get _totalTax =>
      _cartItems.fold(0, (sum, item) => sum + item.taxAmount);
  int get _totalItems =>
      _cartItems.fold(0, (sum, item) => sum + item.quantity);
  double get _total => _subtotal + _totalShipping + _totalTax;

  @override
  void initState() {
    super.initState();
    _fetchCart();
  }

  Future<void> _fetchCart() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final token = await SessionManager.getToken();
    if (token == null) {
      if (!mounted) return;
      setState(() {
        _error = 'Please login to view your cart';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/cart'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          final List rawData = decoded['data'] ?? [];
          final items = rawData
              .whereType<Map<String, dynamic>>()
              .map((e) => _CartItem.fromJson(e, _storageBase))
              .toList();
          if (!mounted) return;
          setState(() {
            _cartItems = items;
            _isLoading = false;
          });
        } else {
          throw Exception(decoded['message'] ?? 'Failed to fetch cart');
        }
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load cart: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _removeItem(int index) async {
    HapticFeedback.mediumImpact();
    final item = _cartItems[index];

    final token = await SessionManager.getToken();
    if (token == null) return;

    try {
      http.Response response;
      try {
        // Try proper DELETE first
        response = await http.delete(
          Uri.parse('$_baseUrl/cart/remove/${item.productId}'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'X-HTTP-Method-Override': 'DELETE',
          },
        );
      } catch (_) {
        // Fallback: POST with Laravel method spoofing
        response = await http.post(
          Uri.parse('$_baseUrl/cart/remove/${item.productId}'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'_method': 'DELETE'}),
        );
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          if (!mounted) return;
          setState(() {
            _cartItems.removeAt(index);
          });
          MainScreen.mainScreenKey.currentState?.refresh();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(decoded['message'] ?? 'Item removed from cart'),
              duration: const Duration(seconds: 1),
            ),
          );
        } else {
          throw Exception(decoded['message'] ?? 'Failed to remove item');
        }
      } else {
        throw Exception('[${response.statusCode}] ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove item: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
            // Header with Back Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _buildHeaderButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () {
                      final mainScreen =
                          context.findAncestorStateOfType<MainScreenState>();
                      if (mainScreen != null) {
                        mainScreen.onIndexChanged(0);
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Shopping Cart',
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
                      onPressed: _fetchCart,
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
                      : _cartItems.isEmpty
                          ? _buildEmpty()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              itemCount: _cartItems.length,
                              itemBuilder: (context, index) {
                                final item = _cartItems[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildCartCard(item, index),
                                );
                              },
                            ),
            ),

            // Price Summary
            if (!_isLoading && _error == null && _cartItems.isNotEmpty)
              _buildPriceSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildCartCard(_CartItem item, int index) {
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
              width: 64,
              height: 64,
              color: const Color(0xFFD4A574).withValues(alpha: 0.08),
              child: Image.network(
                item.imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.shopping_bag,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE8C89F),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₹${item.discountedPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Color(0xFFD4A574),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (item.discount > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '₹${item.unitPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: const Color(0xFF7A7A7F).withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                // Quantity Controls
                Row(
                  children: [
                    _buildQtyButton(
                      icon: Icons.remove,
                      onTap: () {
                        if (item.quantity > 1) {
                          setState(() => item.quantity--);
                        }
                      },
                    ),
                    Container(
                      width: 28,
                      alignment: Alignment.center,
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          color: Color(0xFFE8C89F),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    _buildQtyButton(
                      icon: Icons.add,
                      onTap: () {
                        setState(() => item.quantity++);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Delete Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _removeItem(index),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.delete_outline,
                  color: Color(0xFFFF6B6B),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFFD4A574).withValues(alpha: 0.2),
            ),
          ),
          child: Icon(icon, size: 14, color: const Color(0xFFD4A574)),
        ),
      ),
    );
  }

  Widget _buildPriceSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B23),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(
            color: const Color(0xFFD4A574).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ORDER SUMMARY',
            style: TextStyle(
              color: Color(0xFF7A7A7F),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          _PriceRow(
            label: 'Items',
            value: '$_totalItems',
          ),
          const SizedBox(height: 12),
          _PriceRow(
            label: 'Subtotal',
            value: '₹${_subtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 12),
          _PriceRow(
            label: 'Shipping',
            value: '₹${_totalShipping.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 12),
          _PriceRow(
            label: 'Tax',
            value: '₹${_totalTax.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: const Color(0xFFD4A574).withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          _PriceRow(
            label: 'Total',
            value: '₹${_total.toStringAsFixed(2)}',
            isBold: true,
          ),
          const SizedBox(height: 24),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderSummaryScreen(
                      cartItems: _cartItems,
                      subtotal: _subtotal,
                      shipping: _totalShipping,
                      tax: _totalTax,
                      total: _total,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4A574), Color(0xFFE8C89F)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4A574).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Proceed to Checkout',
                    style: TextStyle(
                      color: Color(0xFF0A0A12),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
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
              onPressed: _fetchCart,
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
          Icon(Icons.shopping_bag_outlined,
              size: 64,
              color: const Color(0xFFD4A574).withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text(
            'Your cart is empty',
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

class _CartItem {
  final int id;
  final int productId;
  final String name;
  final double unitPrice;
  final double discount;
  final String discountType;
  final double shippingCost;
  final double taxAmount;
  int quantity;
  final String imageUrl;

  _CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.discount,
    required this.discountType,
    required this.shippingCost,
    required this.taxAmount,
    required this.quantity,
    required this.imageUrl,
  });

  double get discountedPrice {
    if (discountType == 'flat') {
      return unitPrice - discount;
    } else if (discountType == 'percent') {
      return unitPrice - (unitPrice * (discount / 100));
    }
    return unitPrice;
  }

  double get totalPrice => discountedPrice * quantity;

  factory _CartItem.fromJson(Map<String, dynamic> json, String storageBase) {
    final product = json['product'] as Map<String, dynamic>? ?? {};
    final rawImage = product['image']?.toString() ?? '';
    final imageUrl = rawImage.startsWith('http')
        ? rawImage
        : '$storageBase$rawImage';

    return _CartItem(
      id: json['id'] ?? 0,
      productId: int.tryParse(json['product_id']?.toString() ?? '0') ?? 0,
      name: product['product_name']?.toString() ?? '',
      unitPrice: double.tryParse(product['unit_price']?.toString() ?? '0') ?? 0,
      discount: double.tryParse(product['discount']?.toString() ?? '0') ?? 0,
      discountType: product['discount_type']?.toString() ?? '',
      shippingCost: double.tryParse(product['shipping_cost']?.toString() ?? '0') ?? 0,
      taxAmount: double.tryParse(product['tax_amount']?.toString() ?? '0') ?? 0,
      quantity: int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      imageUrl: imageUrl,
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _PriceRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF7A7A7F),
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            fontSize: isBold ? 15 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isBold ? const Color(0xFFE8C89F) : const Color(0xFFD4A574),
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            fontSize: isBold ? 16 : 14,
          ),
        ),
      ],
    );
  }
}
