import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../utils/session_manager.dart';
import '../main_screen.dart';

class TrackOrderScreen extends StatefulWidget {
  const TrackOrderScreen({super.key});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  static const Color _bg = Color(0xFF0A0A12);
  static const Color _bg2 = Color(0xFF15121D);
  static const Color _bg3 = Color(0xFF1C1B23);
  static const Color _gold = Color(0xFFD4A574);
  static const Color _goldLight = Color(0xFFE8C89F);

  final TextEditingController _orderIdController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _orderData;
  String? _error;

  Future<void> _trackOrder() async {
    final orderNo = _orderIdController.text.trim();
    if (orderNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an Order ID')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final token = await SessionManager.getToken();
    try {
      final response = await http.post(
        Uri.parse('https://aerthh.newhopeindia17.com/api/track-order'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'order_no': orderNo}),
      );

      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 && decoded['status'] == true) {
        setState(() {
          _orderData = decoded['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = decoded['message'] ?? 'Order not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error: $e';
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
          _trackOrder(); // Re-fetch to update UI
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

  void _showCancelDialog() {
    final orderId = _orderData?['order_id'];
    final orderNo = _orderData?['order_no'];
    if (orderId == null) return;

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
              Text('Are you sure you want to cancel order #$orderNo?', style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
                _cancelOrder(orderId, reasonController.text.trim());
              },
              child: const Text('YES, CANCEL'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      extendBody: true,
      bottomNavigationBar: PremiumBottomNavBar(
        currentIndex: 4,
        onIndexChanged: (index) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          MainScreen.mainScreenKey.currentState?.onIndexChanged(index);
        },
        cartCount: MainScreen.mainScreenKey.currentState?.cartCount ?? 0,
        profileImageUrl: MainScreen.mainScreenKey.currentState?.profileImageUrl,
      ),
      body: Container(
        height: double.infinity,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: _buildHeader(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildInputSection(),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator(color: _gold)),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
                        ),
                      if (_orderData != null && !_isLoading) ...[
                        const SizedBox(height: 40),
                        _buildSectionTitle('Delivery Updates'),
                        const SizedBox(height: 24),
                        _buildTrackingProgress(),
                        const SizedBox(height: 24),
                        _buildOrderInformation(),
                      ],
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildNavButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                const Text(
                  'DELIVERY STATUS',
                  style: TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
              ],
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Row(
                children: [
                  Text('MY ORDERS', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w800)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white38, size: 12),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.1),
            children: [
              TextSpan(text: 'Track Your ', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'Order', style: TextStyle(color: _goldLight)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Enter your order ID or tracking number below to get real-time updates on your delivery status.',
          style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Track Order', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Check latest delivery progress', style: TextStyle(color: Colors.white24, fontSize: 11)),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _orderIdController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'ORD0002',
                    hintStyle: TextStyle(color: Colors.white24),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _bg,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: _trackOrder,
                icon: const Icon(Icons.gps_fixed_rounded, size: 18),
                label: const Text('Track Now', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrackingProgress() {
    final status = _orderData?['status']?.toString().toLowerCase() ?? '';
    final steps = ['pending', 'confirmed', 'packaging', 'shipped', 'delivered'];
    final currentIndex = steps.indexOf(status);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _bg3.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tracking Progress', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          Row(
            children: List.generate(steps.length, (index) {
              final isCompleted = index <= currentIndex;
              final isCurrent = index == currentIndex;
              
              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Container(height: 2, color: index == 0 ? Colors.transparent : (isCompleted ? _gold : Colors.white10))),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isCompleted ? _gold : Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                            border: Border.all(color: isCurrent ? _goldLight : Colors.transparent, width: 2),
                          ),
                          child: Icon(
                            _getStepIcon(steps[index]),
                            size: 12,
                            color: isCompleted ? _bg : Colors.white24,
                          ),
                        ),
                        Expanded(child: Container(height: 2, color: index == steps.length - 1 ? Colors.transparent : (index < currentIndex ? _gold : Colors.white10))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      steps[index].toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isCompleted ? Colors.white70 : Colors.white24,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  IconData _getStepIcon(String step) {
    switch (step) {
      case 'pending': return Icons.timer_outlined;
      case 'confirmed': return Icons.check_rounded;
      case 'packaging': return Icons.inventory_2_outlined;
      case 'shipped': return Icons.local_shipping_outlined;
      case 'delivered': return Icons.home_work_outlined;
      default: return Icons.circle;
    }
  }

  Widget _buildOrderInformation() {
    final product = _orderData?['product'] ?? {};
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _bg3.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gold.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Order Information', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('#${_orderData?['order_no'] ?? ''}', style: const TextStyle(color: _goldLight, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: _bg2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(product['image'] ?? '', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, color: _gold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product['product_name'] ?? 'Product Name', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('SKU: ${product['sku'] ?? 'N/A'}', style: const TextStyle(color: Colors.white24, fontSize: 10)),
                    const SizedBox(height: 8),
                    Text(
                      _stripHtml(product['description'] ?? ''),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white38, fontSize: 10, height: 1.4),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${product['unit_price'] ?? '0'}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(4)),
                    child: Text('Qty: ${_orderData?['quantity'] ?? '1'}', style: const TextStyle(color: Colors.white54, fontSize: 9)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildInfoItem('STATUS', _orderData?['status']?.toString().toUpperCase() ?? '-', isStatus: true),
                _buildInfoDivider(),
                _buildInfoItem('ORDER DATE', _formatDate(_orderData?['created_at'])),
                _buildInfoDivider(),
                _buildInfoItem('EST. DELIVERY', _formatDate(_orderData?['created_at'], addDays: 5)),
                _buildInfoDivider(),
                _buildInfoItem('PAYMENT METHOD', '${_orderData?['payment_status']?.toString().toUpperCase() ?? '-'} (${_orderData?['payment_method']?.toString().toUpperCase() ?? '-'})'),
                _buildInfoDivider(),
                _buildInfoItem('SHIPPING COST', '₹${_orderData?['shipping_cost'] ?? '0.00'}'),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.02), borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount Payable', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                Text('₹${_orderData?['total_price'] ?? '0.00'}', style: const TextStyle(color: _goldLight, fontSize: 20, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          if (_orderData?['status']?.toString().toLowerCase() != 'cancelled' && _orderData?['status']?.toString().toLowerCase() != 'delivered') ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  foregroundColor: Colors.redAccent,
                ),
                onPressed: _showCancelDialog,
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('CANCEL ORDER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {bool isStatus = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        if (isStatus)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
            child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
          )
        else
          Text(value, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildInfoDivider() {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 20), height: 30, width: 1, color: Colors.white10);
  }

  String _formatDate(dynamic dateStr, {int addDays = 0}) {
    if (dateStr == null) return '-';
    try {
      DateTime date = DateTime.parse(dateStr.toString());
      if (addDays > 0) date = date.add(Duration(days: addDays));
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateStr.toString();
    }
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), '');
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Container(height: 2, width: 40, color: _gold),
      ],
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
          child: Icon(icon, color: _goldLight, size: 14),
        ),
      ),
    );
  }
}
