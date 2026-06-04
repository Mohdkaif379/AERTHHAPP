import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../utils/session_manager.dart';
import '../main_screen.dart';
import 'orders.dart';

class OrderDetailScreen extends StatefulWidget {
  final OrderItem order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  static const Color _bg = Color(0xFF0A0A12);
  static const Color _bg2 = Color(0xFF15121D);
  static const Color _bg3 = Color(0xFF1C1B23);
  static const Color _gold = Color(0xFFD4A574);
  static const Color _goldLight = Color(0xFFE8C89F);

  late String _currentStatus;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status;
  }

  Future<void> _cancelOrder(String reason) async {
    setState(() => _isCancelling = true);
    final token = await SessionManager.getToken();
    try {
      final response = await http.post(
        Uri.parse('https://aerthh.newhopeindia17.com/api/orders/${widget.order.id}/cancel'),
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
        setState(() {
          _currentStatus = 'cancelled';
          _isCancelling = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order cancelled successfully'), backgroundColor: Colors.green),
          );
        }
      } else {
        setState(() => _isCancelling = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(decoded['message'] ?? 'Failed to cancel order'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      setState(() => _isCancelling = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _showCancelDialog() {
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
              Text('Are you sure you want to cancel order #${widget.order.orderNo}?', style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
                _cancelOrder(reasonController.text.trim());
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
              _buildHeader(context),
              
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Card
                      _buildStatusCard(),
                      const SizedBox(height: 24),
                      
                      // Order Tracking
                      _buildSectionTitle('Order Tracking'),
                      const SizedBox(height: 16),
                      _buildTrackingTimeline(),
                      const SizedBox(height: 32),
                      
                      // Item Details
                      _buildSectionTitle('Items'),
                      const SizedBox(height: 16),
                      _buildItemCard(),
                      const SizedBox(height: 32),
                      
                      // Payment & Shipping
                      _buildSectionTitle('Summary'),
                      const SizedBox(height: 16),
                      _buildSummaryCard(),

                      if (_currentStatus.toLowerCase() != 'cancelled' && _currentStatus.toLowerCase() != 'delivered') ...[
                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              foregroundColor: Colors.redAccent,
                            ),
                            onPressed: _isCancelling ? null : _showCancelDialog,
                            icon: _isCancelling 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent))
                                : const Icon(Icons.cancel_outlined),
                            label: Text(_isCancelling ? 'CANCELLING...' : 'CANCEL ORDER', style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
                          ),
                        ),
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          _buildNavButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Text(
              'Order Details',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _goldLight,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    switch (_currentStatus.toLowerCase()) {
      case 'confirmed': statusColor = Colors.greenAccent; break;
      case 'packaging': statusColor = Colors.blueAccent; break;
      case 'delivered': statusColor = Colors.tealAccent; break;
      case 'cancelled': statusColor = Colors.redAccent; break;
      default: statusColor = _gold;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bg3.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gold.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_rounded, color: statusColor, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${widget.order.orderNo}',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Status: ${_currentStatus.toUpperCase()}',
                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingTimeline() {
    return Column(
      children: [
        _buildTimelineStep(
          'Order Placed', 
          'We have received your order', 
          widget.order.date, 
          isActive: true, 
          isCompleted: true
        ),
        _buildTimelineStep(
          'Confirmed', 
          'The vendor has confirmed your order', 
          '', 
          isActive: _currentStatus.toLowerCase() != 'pending', 
          isCompleted: ['confirmed', 'packaging', 'shipped', 'delivered'].contains(_currentStatus.toLowerCase())
        ),
        _buildTimelineStep(
          'Packaging', 
          'Your item is being packed', 
          '', 
          isActive: ['packaging', 'shipped', 'delivered'].contains(_currentStatus.toLowerCase()), 
          isCompleted: ['packaging', 'shipped', 'delivered'].contains(_currentStatus.toLowerCase())
        ),
        _buildTimelineStep(
          'Out for Delivery', 
          'Your package is on the way', 
          '', 
          isActive: _currentStatus.toLowerCase() == 'shipped' || _currentStatus.toLowerCase() == 'delivered', 
          isLast: true
        ),
      ],
    );
  }

  Widget _buildTimelineStep(String title, String subtitle, String date, {bool isActive = false, bool isCompleted = false, bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isCompleted ? _gold : (isActive ? _gold.withValues(alpha: 0.2) : Colors.white10),
                shape: BoxShape.circle,
                border: isCompleted ? null : Border.all(color: isActive ? _gold : Colors.white24, width: 2),
              ),
              child: isCompleted ? const Icon(Icons.check, size: 12, color: _bg) : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? _gold : Colors.white10,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white24,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              if (date.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(date, style: const TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bg3.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _bg2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _gold.withValues(alpha: 0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: widget.order.productImage.isNotEmpty
                  ? Image.network(widget.order.productImage, fit: BoxFit.cover)
                  : const Icon(Icons.shopping_bag_outlined, color: _gold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.order.productName,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Amount: ₹${widget.order.amount.toStringAsFixed(2)}',
                  style: const TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Quantity: 1',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bg3.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gold.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Payment Method', widget.order.paymentMethod.toUpperCase()),
          const Divider(color: Colors.white10, height: 24),
          _buildSummaryRow('Payment Status', widget.order.paymentStatus.toUpperCase(), color: widget.order.paymentStatus.toLowerCase() == 'paid' ? Colors.greenAccent : Colors.orangeAccent),
          const Divider(color: Colors.white10, height: 24),
          _buildSummaryRow('Total Amount', '₹${widget.order.amount.toStringAsFixed(2)}', isBold: true, valueColor: _gold),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? valueColor, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: color ?? valueColor ?? Colors.white70,
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: _gold,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
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
