import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../main_screen.dart';
import '../../utils/session_manager.dart';

// ─── Color constants ──────────────────────────────────────────────────────────
const _gold = Color(0xFFD4A574);
const _goldMid = Color(0xFFC49A6C);
const _goldLight = Color(0xFFE8C89F);
const _bg = Color(0xFF0A0A12);
const _bg3 = Color(0xFF1C1B23);
const _border = Color(0xFF2E2B38);

class Address {
  final int id;
  final String type;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String addressLine;
  final String city;
  final String state;
  final String zipCode;
  final String country;

  Address({
    required this.id,
    required this.type,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.addressLine,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      type: json['type'] ?? 'shipping',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      addressLine: json['address_line'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      zipCode: json['zip_code'] ?? '',
      country: json['country'] ?? 'India',
    );
  }

  String get fullName => '$firstName $lastName'.trim();
  String get fullAddress => '$addressLine, $city, $state - $zipCode, $country';
}

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  List<Address> _addresses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    if (_addresses.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

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
              _isLoading = false;
              _error = null;
            });
          }
        } else {
          throw Exception(decoded['message'] ?? 'Failed to load addresses');
        }
      } else {
        throw Exception('[${response.statusCode}] Failed to fetch addresses');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteAddress(int id) async {
    HapticFeedback.mediumImpact();
    final token = await SessionManager.getToken();
    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse('https://aerthh.newhopeindia17.com/api/address/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'_method': 'DELETE'}),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address deleted successfully')),
          );
          _fetchAddresses();
        } else {
          throw Exception(decoded['message'] ?? 'Failed to delete');
        }
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  void _onNavbarIndexChanged(int index) {
    HapticFeedback.mediumImpact();
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
        currentIndex: 4, // Profile section
        onIndexChanged: _onNavbarIndexChanged,
        cartCount: mainState?.cartCount ?? 0,
        profileImageUrl: mainState?.profileImageUrl,
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _goldLight, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Addresses',
          style: TextStyle(color: _goldLight, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_outlined, color: _gold, size: 24),
            onPressed: () => _showAddAddressSheet(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bg, Color(0xFF15121D)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _gold))
            : _error != null
                ? _buildErrorView()
                : _addresses.isEmpty
                    ? _buildEmptyView()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                        itemCount: _addresses.length,
                        itemBuilder: (context, index) => _buildAddressCard(_addresses[index]),
                      ),
      ),
    );
  }

  Widget _buildAddressCard(Address address) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bg3.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  address.type.toUpperCase(),
                  style: const TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                onPressed: () => _deleteAddress(address.id),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(address.fullName, style: const TextStyle(color: _goldLight, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(address.fullAddress, style: TextStyle(color: _goldMid.withValues(alpha: 0.7), fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.phone_outlined, color: _gold, size: 14),
              const SizedBox(width: 8),
              Text(address.phone, style: TextStyle(color: _goldMid.withValues(alpha: 0.6), fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_outlined, size: 64, color: _gold.withValues(alpha: 0.3)),
          const SizedBox(height: 20),
          const Text('No addresses found', style: TextStyle(color: _goldLight, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Add an address to start ordering', style: TextStyle(color: _goldMid.withValues(alpha: 0.5))),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _showAddAddressSheet,
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Add Address', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_error ?? 'Unknown error', textAlign: TextAlign.center, style: const TextStyle(color: _goldLight)),
            TextButton(onPressed: _fetchAddresses, child: const Text('Retry', style: TextStyle(color: _gold))),
          ],
        ),
      ),
    );
  }

  void _showAddAddressSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddAddressBottomSheet(onAddressAdded: _fetchAddresses),
    );
  }
}

class _AddAddressBottomSheet extends StatefulWidget {
  final VoidCallback onAddressAdded;
  const _AddAddressBottomSheet({required this.onAddressAdded});

  @override
  State<_AddAddressBottomSheet> createState() => _AddAddressBottomSheetState();
}

class _AddAddressBottomSheetState extends State<_AddAddressBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final token = await SessionManager.getToken();

    try {
      final response = await http.post(
        Uri.parse('https://aerthh.newhopeindia17.com/api/address/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'type': 'shipping',
          'first_name': _firstNameController.text,
          'last_name': _lastNameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'address_line': _addressController.text,
          'city': _cityController.text,
          'state': _stateController.text,
          'zip_code': _zipController.text,
          'country': 'India',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true || decoded['status'] == "true") {
          widget.onAddressAdded();
          if (mounted) Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address added successfully!')));
        } else {
          throw Exception(decoded['message'] ?? 'Failed to add address');
        }
      } else {
        final errorMsg = jsonDecode(response.body)['message'] ?? 'Status: ${response.statusCode}';
        throw Exception(errorMsg);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: _bg3,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add New Address', style: TextStyle(color: _goldLight, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _buildField('First Name', _firstNameController)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildField('Last Name', _lastNameController)),
                ],
              ),
              _buildField('Email Address', _emailController, keyboard: TextInputType.emailAddress),
              _buildField('Phone Number', _phoneController, keyboard: TextInputType.phone),
              _buildField('Address Line', _addressController),
              Row(
                children: [
                  Expanded(child: _buildField('City', _cityController)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildField('State', _stateController)),
                ],
              ),
              _buildField('ZIP Code', _zipController, keyboard: TextInputType.number),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _bg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: _bg)
                      : const Text('Save Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: _goldMid.withValues(alpha: 0.6), fontSize: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _gold.withValues(alpha: 0.2))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _gold)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
          filled: true,
          fillColor: _bg.withValues(alpha: 0.3),
        ),
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
    );
  }
}
