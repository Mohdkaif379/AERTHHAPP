import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../utils/session_manager.dart';
import '../main_screen.dart';

class HistoryItem {
  final int id;
  final String orderNo;
  final String date;
  final String status;
  final double amount;
  final String productName;
  final String productImage;

  HistoryItem({
    required this.id,
    required this.orderNo,
    required this.date,
    required this.status,
    required this.amount,
    required this.productName,
    required this.productImage,
  });

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] ?? {};
    return HistoryItem(
      id: json['id'] ?? 0,
      orderNo: json['order_no'] ?? 'N/A',
      date: json['created_at'] ?? '',
      status: json['status'] ?? 'N/A',
      amount: double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
      productName: product['product_name'] ?? 'Product',
      productImage: product['image'] ?? '',
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const Color _bg = Color(0xFF0A0A12);
  static const Color _bg2 = Color(0xFF15121D);
  static const Color _bg3 = Color(0xFF1C1B23);
  static const Color _gold = Color(0xFFD4A574);
  static const Color _goldLight = Color(0xFFE8C89F);

  List<HistoryItem> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
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
        Uri.parse('https://aerthh.newhopeindia17.com/api/orders/history'),
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
            _history = data.map((e) => HistoryItem.fromJson(e)).toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = decoded['message'] ?? 'Failed to fetch history';
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
                        'Order History',
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
                        _fetchHistory();
                      },
                    ),
                  ],
                ),
              ),

              // History List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: _gold))
                    : _error != null
                        ? _buildErrorState()
                        : _history.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                itemCount: _history.length,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                                itemBuilder: (context, index) => _buildHistoryCard(_history[index]),
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(HistoryItem item) {
    Color statusColor;
    switch (item.status.toLowerCase()) {
      case 'delivered':
        statusColor = Colors.tealAccent;
        break;
      case 'cancelled':
        statusColor = Colors.redAccent;
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${item.orderNo}',
                  style: const TextStyle(color: _goldLight, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
                    child: item.productImage.isNotEmpty
                        ? Image.network(
                            item.productImage,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.history_rounded, color: _gold),
                          )
                        : const Icon(Icons.history_rounded, color: _gold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(_formatDate(item.date), style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                Text(
                  '₹${item.amount.toStringAsFixed(2)}',
                  style: const TextStyle(color: _gold, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: _gold.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          const Text(
            'No History Found',
            style: TextStyle(color: _goldLight, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your past orders will appear here.',
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
                _fetchHistory();
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
