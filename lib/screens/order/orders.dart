import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../utils/session_manager.dart';
import '../main_screen.dart';
import 'order_detail_screen.dart';

class OrderItem {
  final int id;
  final String orderNo;
  final String date;
  final String status;
  final double amount;
  final String productName;
  final String productImage;
  final String paymentMethod;
  final String paymentStatus;

  OrderItem({
    required this.id,
    required this.orderNo,
    required this.date,
    required this.status,
    required this.amount,
    required this.productName,
    required this.productImage,
    required this.paymentMethod,
    required this.paymentStatus,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] ?? {};
    return OrderItem(
      id: json['id'] ?? 0,
      orderNo: json['order_no'] ?? 'N/A',
      date: json['created_at'] ?? '',
      status: json['status'] ?? 'pending',
      amount: double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
      productName: product['product_name'] ?? 'Product',
      productImage: product['image'] ?? '',
      paymentMethod: json['payment_method'] ?? 'N/A',
      paymentStatus: json['payment_status'] ?? 'N/A',
    );
  }
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const Color _bg = Color(0xFF0A0A12);
  static const Color _bg2 = Color(0xFF15121D);
  static const Color _bg3 = Color(0xFF1C1B23);
  static const Color _gold = Color(0xFFD4A574);
  static const Color _goldLight = Color(0xFFE8C89F);

  List<OrderItem> _orders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    final token = await SessionManager.getToken();
    if (token == null) {
      setState(() {
        _isLoading = false;
        _error = 'Session expired. Please login again.';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://aerthh.newhopeindia17.com/api/orders'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          final List data = decoded['data'] ?? [];
          setState(() {
            _orders = data.map((e) => OrderItem.fromJson(e)).toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = decoded['message'] ?? 'Failed to fetch orders';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelOrder(int orderId, String reason) async {
    final token = await SessionManager.getToken();
    try {
      final response = await http.post(
        Uri.parse('https://aerthh.newhopeindia17.com/api/orders/$orderId/cancel'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          '_method': 'PATCH',
          'cancel_reason': reason,
        }),
      );

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 && decoded['status'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order cancelled successfully'), backgroundColor: Colors.green),
          );
          _fetchOrders(); // Refresh list
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(decoded['message'] ?? 'Failed to cancel order'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showCancelDialog(OrderItem order) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: _bg3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: _gold.withValues(alpha: 0.1))),
          title: const Text('Cancel Order', style: TextStyle(color: _goldLight, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Are you sure you want to cancel order #${order.orderNo}?', style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: reasonController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(hintText: 'Reason for cancellation', hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('NO', style: TextStyle(color: Colors.white38))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide a reason')));
                  return;
                }
                Navigator.pop(context);
                _cancelOrder(order.id, reasonController.text.trim());
              },
              child: const Text('YES, CANCEL'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  void _onNavbarIndexChanged(int index) {
    // Navigate back to MainScreen and switch tabs
    Navigator.of(context).popUntil((route) => route.isFirst);
    MainScreen.mainScreenKey.currentState?.onIndexChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      extendBody: true,
      bottomNavigationBar: PremiumBottomNavBar(
        currentIndex: 4, // Keep Profile as active or 4 for current flow
        onIndexChanged: _onNavbarIndexChanged,
        cartCount: MainScreen.mainScreenKey.currentState?.cartCount ?? 0,
        profileImageUrl: MainScreen.mainScreenKey.currentState?.profileImageUrl,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bg, _bg2],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Row(
                  children: [
                    _buildNavButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'My Orders',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _goldLight,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    _buildNavButton(
                      icon: Icons.refresh_rounded,
                      onTap: () {
                        setState(() => _isLoading = true);
                        _fetchOrders();
                      },
                    ),
                  ],
                ),
              ),

              // Orders List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: _gold))
                    : _error != null
                        ? _buildErrorState()
                        : _orders.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                itemCount: _orders.length,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), // Extra padding for navbar
                                itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderItem order) {
    Color statusColor;
    switch (order.status.toLowerCase()) {
      case 'confirmed':
        statusColor = Colors.greenAccent;
        break;
      case 'packaging':
      case 'processing':
        statusColor = Colors.blueAccent;
        break;
      case 'cancelled':
        statusColor = Colors.redAccent;
        break;
      case 'delivered':
        statusColor = Colors.tealAccent;
        break;
      default:
        statusColor = _gold;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _bg3.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => OrderDetailScreen(order: order)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #${order.orderNo}',
                        style: const TextStyle(
                          color: _goldLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          order.status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (order.status.toLowerCase() != 'cancelled' && order.status.toLowerCase() != 'delivered')
                        IconButton(
                          onPressed: () => _showCancelDialog(order),
                          icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
                          tooltip: 'Cancel Order',
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _bg2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _gold.withValues(alpha: 0.1)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: order.productImage.isNotEmpty
                              ? Image.network(
                                  order.productImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, color: _gold),
                                )
                              : const Icon(Icons.shopping_bag_outlined, color: _gold),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.productName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(order.date),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Payment: ${order.paymentMethod.toUpperCase()} (${order.paymentStatus})',
                              style: TextStyle(
                                color: _gold.withValues(alpha: 0.7),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${order.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: _gold,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: _gold.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          const Text(
            'No Orders Yet',
            style: TextStyle(color: _goldLight, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Keep shopping to find items you love!',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 60, color: Colors.redAccent),
            const SizedBox(height: 20),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchOrders();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton({required IconData icon, required VoidCallback onTap}) {
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
          child: Icon(icon, color: _goldLight, size: 18),
        ),
      ),
    );
  }
}
