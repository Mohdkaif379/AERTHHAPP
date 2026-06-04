import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../main_screen.dart';
import '../address/address_screen.dart';
import '../../utils/session_manager.dart';
import '../../utils/razorpay_web.dart' as rzpWeb;

// ─── Color constants ──────────────────────────────────────────────────────────
const _gold = Color(0xFFD4A574);
const _goldMid = Color(0xFFC49A6C);
const _goldLight = Color(0xFFE8C89F);
const _bg = Color(0xFF0A0A12);
const _bg3 = Color(0xFF1C1B23);
const _border = Color(0xFF2E2B38);

class OrderSummaryScreen extends StatefulWidget {
  final List<dynamic> cartItems;
  final double subtotal;
  final double shipping;
  final double tax;
  final double total;

  const OrderSummaryScreen({
    super.key,
    required this.cartItems,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.total,
  });

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  List<Address> _addresses = [];
  int _selectedAddressIndex = 0;
  bool _isLoadingAddresses = true;
  String _paymentMethod = 'COD';
  Razorpay? _razorpay;
  Map<String, dynamic>? _pendingOrderData; // Stores order response for Razorpay callback

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
    if (!kIsWeb) {
      _initRazorpayNative();
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  void _initRazorpayNative() {
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> _cleanupCartAfterOrder(int productId) async {
    final token = await SessionManager.getToken();
    if (token == null) return;

    try {
      await http.post(
        Uri.parse('https://aerthh.newhopeindia17.com/api/cart/remove/$productId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'_method': 'DELETE'}),
      );
      MainScreen.mainScreenKey.currentState?.refresh();
    } catch (e) {
      debugPrint('OrderSummary: Error cleaning cart: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (widget.cartItems.isNotEmpty) {
      _cleanupCartAfterOrder(widget.cartItems.first.productId);
    }
    final orderData = _pendingOrderData?['data'];
    _showSuccessDialog(
      orderNo: orderData?['order_no']?.toString() ?? '-',
      transactionId: response.paymentId ?? orderData?['payment_order_id']?.toString(),
      productName: widget.cartItems.isNotEmpty ? widget.cartItems.first.name : null,
      amount: widget.total,
      paymentMethod: _paymentMethod,
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment Failed: ${response.message}')),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External Wallet: ${response.walletName}')),
    );
  }

  void _showSuccessDialog({
    required String orderNo,
    String? transactionId,
    String? productName,
    double? amount,
    String? paymentMethod,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _bg3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
            ),
            const SizedBox(height: 16),
            const Text(
              'Order Placed!',
              style: TextStyle(color: _goldLight, fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Thank you for your purchase',
              style: TextStyle(color: _goldMid.withValues(alpha: 0.5), fontSize: 13, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _bg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gold.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOrderDetailRow(Icons.receipt_long_outlined, 'Order No', orderNo),
              if (productName != null && productName.isNotEmpty) ...
                [const SizedBox(height: 12), _buildOrderDetailRow(Icons.shopping_bag_outlined, 'Product', productName)],
              if (amount != null) ...
                [const SizedBox(height: 12), _buildOrderDetailRow(Icons.currency_rupee_rounded, 'Amount Paid', '₹${amount.toStringAsFixed(2)}')],
              if (transactionId != null && transactionId.isNotEmpty) ...
                [const SizedBox(height: 12), _buildOrderDetailRow(Icons.tag_rounded, 'Transaction ID', transactionId)],
              if (paymentMethod != null) ...
                [const SizedBox(height: 12), _buildOrderDetailRow(Icons.payment_rounded, 'Payment Method', paymentMethod.toUpperCase())],
              const SizedBox(height: 12),
              _buildOrderDetailRow(Icons.calendar_today_outlined, 'Order Date', _formatDate(DateTime.now())),
              const SizedBox(height: 12),
              _buildOrderDetailRow(Icons.local_shipping_outlined, 'Est. Delivery', _formatDate(DateTime.now().add(const Duration(days: 5)))),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: _bg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                MainScreen.mainScreenKey.currentState?.onIndexChanged(0);
              },
              child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _gold, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: _goldMid.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: _goldLight, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _fetchAddresses() async {
    final token = await SessionManager.getToken();
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('https://aerthh.newhopeindia17.com/api/addresses'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true || decoded['status'] == "true") {
          final List rawData = decoded['data'] ?? [];
          if (mounted) {
            setState(() {
              _addresses = rawData.map((e) => Address.fromJson(e)).toList();
              _isLoadingAddresses = false;
            });
          }
        } else {
          if (mounted) setState(() => _isLoadingAddresses = false);
        }
      } else {
        if (mounted) setState(() => _isLoadingAddresses = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAddresses = false);
    }
  }

  void _onNavbarIndexChanged(int index) {
    HapticFeedback.mediumImpact();
    // Navigate back to main screen and change index
    Navigator.of(context).popUntil((route) => route.isFirst);
    MainScreen.mainScreenKey.currentState?.onIndexChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    final mainState = MainScreen.mainScreenKey.currentState;

    return Scaffold(
      backgroundColor: _bg,
      extendBody: true,
      bottomNavigationBar: PremiumBottomNavBar(
        currentIndex: 3, // Cart section is parent
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
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 110), // Padding for navbar
                  children: [
                    _buildSectionTitle('Items in Order'),
                    const SizedBox(height: 16),
                    ...widget.cartItems.map((item) => _buildOrderItem(item)),
                    const SizedBox(height: 32),
                    _buildSectionHeader(
                      title: 'Shipping Address',
                      onAction: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddressScreen()),
                        );
                        _fetchAddresses();
                      },
                      actionLabel: _addresses.isEmpty ? 'Add' : 'Change',
                    ),
                    const SizedBox(height: 16),
                    _buildAddressSection(),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Payment Method'),
                    const SizedBox(height: 16),
                    _buildPaymentMethodSection(),
                    const SizedBox(height: 32),
                    _buildSectionTitle('Payment Details'),
                    const SizedBox(height: 16),
                    _buildPriceBreakdown(),
                    const SizedBox(height: 24),
                    _buildConfirmButton(),
                  ],
                ),
              ),
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
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _goldLight, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Order Summary',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _goldLight,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48), // Spacer for balance
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF7A7A7F),
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required VoidCallback onAction, required String actionLabel}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionTitle(title),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            actionLabel,
            style: const TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressSection() {
    if (_isLoadingAddresses) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _gold)),
      );
    }

    if (_addresses.isEmpty) {
      return GestureDetector(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddressScreen()));
          _fetchAddresses();
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gold.withValues(alpha: 0.1), style: BorderStyle.solid),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_location_alt_outlined, color: _gold, size: 20),
              SizedBox(width: 12),
              Text('Add Shipping Address', style: TextStyle(color: _gold, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    // Dropdown for Address Selection
    final selectedAddress = _addresses[_selectedAddressIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown Container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: _bg3.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gold.withValues(alpha: 0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedAddressIndex,
              isExpanded: true,
              dropdownColor: _bg3,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _gold),
              elevation: 4,
              borderRadius: BorderRadius.circular(16),
              items: List.generate(_addresses.length, (index) {
                final addr = _addresses[index];
                return DropdownMenuItem<int>(
                  value: index,
                  child: Row(
                    children: [
                      Icon(
                        index == _selectedAddressIndex ? Icons.location_on_rounded : Icons.location_on_outlined,
                        color: _gold,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          addr.fullName,
                          style: const TextStyle(
                            color: _goldLight,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              onChanged: (int? newIndex) {
                if (newIndex != null) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedAddressIndex = newIndex);
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Selected Address Detailed Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _gold.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, color: _gold, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'SHIPPING TO',
                    style: TextStyle(
                      color: Color(0xFF7A7A7F),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      selectedAddress.type.toUpperCase(),
                      style: const TextStyle(color: _gold, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                selectedAddress.fullName,
                style: const TextStyle(color: _goldLight, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                selectedAddress.fullAddress,
                style: TextStyle(color: _goldMid.withValues(alpha: 0.7), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.phone_outlined, color: _gold, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    selectedAddress.phone,
                    style: TextStyle(color: _goldMid.withValues(alpha: 0.6), fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      children: [
        _buildPaymentOption(
          id: 'COD',
          title: 'Cash on Delivery',
          subtitle: 'Pay when your order is delivered',
          icon: Icons.money_rounded,
        ),
        const SizedBox(height: 12),
        _buildPaymentOption(
          id: 'ONLINE',
          title: 'Online Payment',
          subtitle: 'Pay via Card, UPI, or Net Banking',
          icon: Icons.account_balance_wallet_outlined,
        ),
      ],
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _paymentMethod == id;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _paymentMethod = id);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _gold.withValues(alpha: 0.1) : _bg3.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _gold : _gold.withValues(alpha: 0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? _gold.withValues(alpha: 0.2) : _gold.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? _goldLight : _goldMid, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? _goldLight : _goldMid,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isSelected ? _goldLight.withValues(alpha: 0.6) : _goldMid.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: _gold, size: 22)
            else
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _gold.withValues(alpha: 0.2), width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg3.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _gold.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.network(
              item.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, color: _gold, size: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _goldLight, fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quantity: ${item.quantity}',
                  style: TextStyle(color: _goldMid.withValues(alpha: 0.7), fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '₹${item.totalPrice.toStringAsFixed(0)}',
            style: const TextStyle(color: _gold, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bg3.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          _buildPriceRow('Subtotal', '₹${widget.subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 14),
          _buildPriceRow('Shipping Fee', '₹${widget.shipping.toStringAsFixed(2)}'),
          const SizedBox(height: 14),
          _buildPriceRow('Estimated Tax', '₹${widget.tax.toStringAsFixed(2)}'),
          const SizedBox(height: 18),
          Container(height: 1, color: _gold.withValues(alpha: 0.1)),
          const SizedBox(height: 18),
          _buildPriceRow('Total Amount', '₹${widget.total.toStringAsFixed(2)}', isTotal: true),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? _goldLight : const Color(0xFF7A7A7F),
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? _goldLight : _goldMid,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
            fontSize: isTotal ? 20 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _placeOrder,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: const LinearGradient(colors: [_gold, _goldLight]),
            boxShadow: [
              BoxShadow(
                color: _gold.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Confirm Order',
              style: TextStyle(
                color: _bg,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _placeOrder() async {
    print('OrderSummary: Initiating order placement...');
    if (_addresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a shipping address first')));
      return;
    }

    HapticFeedback.mediumImpact();
    
    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: _gold)),
    );

    final token = await SessionManager.getToken();
    final addressId = _addresses[_selectedAddressIndex].id;
    
    if (widget.cartItems.isEmpty) return;
    final item = widget.cartItems.first;

    try {
      final response = await http.post(
        Uri.parse('https://aerthh.newhopeindia17.com/api/order/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'product_id': item.productId,
          'quantity': item.quantity,
          'address_id': addressId,
          'payment_method': _paymentMethod.toLowerCase(),
        }),
      );

      print('OrderSummary: API Status: ${response.statusCode}');
      print('OrderSummary: API Response: ${response.body}');

      // Close Loading
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          if (_paymentMethod == 'ONLINE') {
            print('OrderSummary: Starting Razorpay flow...');
            _pendingOrderData = decoded; // Cache for success callback
            _startRazorpay(decoded);
          } else {
            // Cleanup cart for COD
            _cleanupCartAfterOrder(item.productId);
            final data = decoded['data'];
            _showSuccessDialog(
              orderNo: data['order_no']?.toString() ?? '-',
              productName: item.name,
              amount: widget.total,
              paymentMethod: _paymentMethod,
            );
          }
        } else {
          throw Exception(decoded['message'] ?? 'Failed to create order');
        }
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      print('OrderSummary: Error: $e');
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order Error: $e')));
    }
  }

  void _startRazorpay(Map<String, dynamic> responseData) {
    try {
      final gateway = responseData['payment_gateway'];
      if (gateway == null) {
        _showSuccessDialog(
          orderNo: responseData['data']['order_no']?.toString() ?? 'Success',
          paymentMethod: _paymentMethod,
        );
        return;
      }

      final String razorpayKey = gateway['razorpay_key'];
      final String orderId = gateway['razorpay_order_id'];
      // Razorpay expects amount in paise (smallest currency unit)
      final int amountInPaise = ((gateway['amount'] as num) * 100).round();
      final String phone = _addresses[_selectedAddressIndex].phone;
      final String email = _addresses[_selectedAddressIndex].email;

      if (kIsWeb) {
        // ── Web: use dart:js to call Razorpay JS SDK directly ──────────────
        _startRazorpayWeb(
          key: razorpayKey,
          orderId: orderId,
          amount: amountInPaise,
          phone: phone,
          email: email,
          responseData: responseData,
        );
      } else {
        // ── Mobile: use razorpay_flutter native plugin ──────────────────────
        _razorpay!.open({
          'key': razorpayKey,
          'amount': amountInPaise,
          'name': 'Aerthh',
          'order_id': orderId,
          'description': 'Order Payment',
          'timeout': 300,
          'prefill': {'contact': phone, 'email': email},
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Razorpay Error: $e')));
    }
  }

  void _startRazorpayWeb({
    required String key,
    required String orderId,
    required int amount,
    required String phone,
    required String email,
    required Map<String, dynamic> responseData,
  }) {
    rzpWeb.openRazorpayWeb(
      key: key,
      orderId: orderId,
      amount: amount,
      phone: phone,
      email: email,
      onSuccess: (paymentId) {
        if (widget.cartItems.isNotEmpty) {
          _cleanupCartAfterOrder(widget.cartItems.first.productId);
        }
        final orderData = _pendingOrderData?['data'];
        _showSuccessDialog(
          orderNo: orderData?['order_no']?.toString() ?? '-',
          transactionId: paymentId,
          productName: widget.cartItems.isNotEmpty ? widget.cartItems.first.name : null,
          amount: widget.total,
          paymentMethod: _paymentMethod,
        );
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment Error: $error')),
        );
      },
    );
  }
}
