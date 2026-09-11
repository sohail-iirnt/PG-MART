import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// === THE LIVE SETTINGS ENGINES ===
final adminSettingsProvider = StreamProvider<DocumentSnapshot>((ref) =>
    FirebaseFirestore.instance.collection('store_settings').doc('general').snapshots());

// App Control Provider (For Splash Screen Versioning & Maintenance)
final appControlProvider = StreamProvider<DocumentSnapshot>((ref) =>
    FirebaseFirestore.instance.collection('store_settings').doc('app_control').snapshots());

// === NEW: API GATEWAY PROVIDER ===
final gatewaySettingsProvider = StreamProvider<DocumentSnapshot>((ref) =>
    FirebaseFirestore.instance.collection('store_settings').doc('gateways').snapshots());

class AdminSettingsModule extends ConsumerStatefulWidget {
  final bool isDesktop;
  const AdminSettingsModule({super.key, required this.isDesktop});

  @override
  ConsumerState<AdminSettingsModule> createState() => _AdminSettingsModuleState();
}

class _AdminSettingsModuleState extends ConsumerState<AdminSettingsModule> {
  // Business Details
  final _storeNameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _registrationCtrl = TextEditingController();

  // Contact Info
  final _supportPhoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Operational Rules
  final _minOrderCtrl = TextEditingController();
  bool _isStoreOpen = true;

  // Payment Toggles & Keys
  bool _isCodEnabled = true;
  bool _isOnlinePaymentEnabled = true;
  final _razorpayKeyCtrl = TextEditingController(); // === NEW ===

  // App Control & Versioning
  bool _isMaintenance = false;
  final _maintenanceMsgCtrl = TextEditingController();
  final _minVersionCtrl = TextEditingController();
  final _latestVersionCtrl = TextEditingController();

  bool _isSaving = false;
  bool _isGeneralInitialized = false;
  bool _isAppControlInitialized = false;
  bool _isGatewayInitialized = false; // === NEW ===

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      // 1. Save General Settings & Payments
      await FirebaseFirestore.instance.collection('store_settings').doc('general').set({
        'storeName': _storeNameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'registrationNumber': _registrationCtrl.text.trim(),
        'supportPhone': _supportPhoneCtrl.text.trim(),
        'whatsappNumber': _whatsappCtrl.text.trim(),
        'supportEmail': _emailCtrl.text.trim(),
        'minOrderValue': double.tryParse(_minOrderCtrl.text) ?? 0.0,
        'isStoreOpen': _isStoreOpen,
        'isCodEnabled': _isCodEnabled,
        'isOnlinePaymentEnabled': _isOnlinePaymentEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Save App Control (Maintenance & Updates)
      await FirebaseFirestore.instance.collection('store_settings').doc('app_control').set({
        'is_maintenance': _isMaintenance,
        'maintenance_msg': _maintenanceMsgCtrl.text.trim(),
        'min_version_code': int.tryParse(_minVersionCtrl.text.trim()) ?? 1,
        'latest_version_code': int.tryParse(_latestVersionCtrl.text.trim()) ?? 1,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Save Gateway Keys === NEW ===
      await FirebaseFirestore.instance.collection('store_settings').doc('gateways').set({
        'razorpay_key': _razorpayKeyCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All Settings Updated Successfully!'), backgroundColor: Colors.green));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _addressCtrl.dispose();
    _registrationCtrl.dispose();
    _supportPhoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _minOrderCtrl.dispose();
    _maintenanceMsgCtrl.dispose();
    _minVersionCtrl.dispose();
    _latestVersionCtrl.dispose();
    _razorpayKeyCtrl.dispose(); // === NEW ===
    super.dispose();
  }

  // === RESPONSIVE LAYOUT ENGINE ===
  Widget _buildResponsiveRow({required bool isMobile, required Widget child1, required Widget child2}) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          child1,
          const SizedBox(height: 16),
          child2,
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: child1),
          const SizedBox(width: 16),
          Expanded(child: child2),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final generalAsync = ref.watch(adminSettingsProvider);
    final appControlAsync = ref.watch(appControlProvider);
    final gatewayAsync = ref.watch(gatewaySettingsProvider); // === NEW ===

    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Responsive Header
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 12,
          children: [
            SizedBox(
                width: isMobile ? double.infinity : null,
                child: Text('Manage business profile, app updates, and operations.', style: TextStyle(color: Colors.grey, fontSize: widget.isDesktop ? 16 : 14))
            ),
            SizedBox(
              width: isMobile ? double.infinity : null,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                icon: const Icon(Icons.save, color: Colors.white, size: 18),
                label: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('SAVE SETTINGS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: _isSaving ? null : _saveSettings,
              ),
            )
          ],
        ),
        const SizedBox(height: 24),

        Expanded(
          child: (generalAsync.isLoading || appControlAsync.isLoading || gatewayAsync.isLoading)
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [

                    // === INITIALIZATION LOGIC ===
                    Builder(builder: (context) {
                      if (generalAsync.hasValue && !_isGeneralInitialized) {
                        final data = generalAsync.value!.data() as Map<String, dynamic>? ?? {};
                        _storeNameCtrl.text = data['storeName'] ?? 'PG MART';
                        _addressCtrl.text = data['address'] ?? 'Bhiwandi, Maharashtra';
                        _registrationCtrl.text = data['registrationNumber'] ?? '';
                        _supportPhoneCtrl.text = data['supportPhone'] ?? '';
                        _whatsappCtrl.text = data['whatsappNumber'] ?? '';
                        _emailCtrl.text = data['supportEmail'] ?? '';
                        _minOrderCtrl.text = data['minOrderValue']?.toString() ?? '100';
                        _isStoreOpen = data['isStoreOpen'] ?? true;
                        _isCodEnabled = data['isCodEnabled'] ?? true;
                        _isOnlinePaymentEnabled = data['isOnlinePaymentEnabled'] ?? true;
                        _isGeneralInitialized = true;
                      }
                      if (appControlAsync.hasValue && !_isAppControlInitialized) {
                        final data = appControlAsync.value!.data() as Map<String, dynamic>? ?? {};
                        _isMaintenance = data['is_maintenance'] ?? false;
                        _maintenanceMsgCtrl.text = data['maintenance_msg'] ?? 'We are currently upgrading PG Mart. Please check back shortly!';
                        _minVersionCtrl.text = (data['min_version_code'] ?? 1).toString();
                        _latestVersionCtrl.text = (data['latest_version_code'] ?? 1).toString();
                        _isAppControlInitialized = true;
                      }
                      if (gatewayAsync.hasValue && !_isGatewayInitialized) {
                        final data = gatewayAsync.value!.data() as Map<String, dynamic>? ?? {};
                        _razorpayKeyCtrl.text = data['razorpay_key'] ?? '';
                        _isGatewayInitialized = true;
                      }
                      return const SizedBox.shrink();
                    }),

                    // === CARD 1: APP VERSION & MAINTENANCE ===
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _isMaintenance ? Colors.orange : Colors.transparent, width: 2)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [Icon(Icons.security, color: _isMaintenance ? Colors.orange : Colors.grey[700]), const SizedBox(width: 8), Expanded(child: Text('App Version & Maintenance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _isMaintenance ? Colors.orange[800] : Colors.black)))]),
                            const Divider(height: 32),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_isMaintenance ? 'MAINTENANCE MODE ACTIVE' : 'Maintenance Mode Disabled', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _isMaintenance ? Colors.orange : Colors.black)),
                                      const SizedBox(height: 4),
                                      const Text('Instantly locks all users out of the app during critical upgrades.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _isMaintenance,
                                  activeColor: Colors.orange,
                                  onChanged: (val) => setState(() => _isMaintenance = val),
                                )
                              ],
                            ),
                            if (_isMaintenance) ...[
                              const SizedBox(height: 16),
                              TextField(controller: _maintenanceMsgCtrl, decoration: const InputDecoration(labelText: 'Lock Screen Message', border: OutlineInputBorder(), isDense: true)),
                            ],
                            const SizedBox(height: 24),

                            _buildResponsiveRow(
                              isMobile: isMobile,
                              child1: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Min Required Version (Hard Update)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 4),
                                const Text('Forces users to update.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 8),
                                TextField(controller: _minVersionCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.warning, color: Colors.red, size: 18)))
                              ]),
                              child2: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Latest Version (Soft Update)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 4),
                                const Text('Politely suggests an update.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 8),
                                TextField(controller: _latestVersionCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.info, color: Colors.blue, size: 18)))
                              ]),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // === CARD 2: PAYMENT GATEWAYS (UPDATED WITH KEY) ===
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [Icon(Icons.payments, color: Colors.indigo), SizedBox(width: 8), Expanded(child: Text('Payment Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))]),
                            const Divider(height: 32),

                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Cash on Delivery (COD)', style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: const Text('Allow users to pay with cash upon delivery.'),
                              activeColor: Colors.indigo,
                              value: _isCodEnabled,
                              onChanged: (val) => setState(() => _isCodEnabled = val),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Online Payments (Razorpay)', style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: const Text('Allow users to pay via UPI, Cards, and Netbanking.'),
                              activeColor: Colors.indigo,
                              value: _isOnlinePaymentEnabled,
                              onChanged: (val) => setState(() => _isOnlinePaymentEnabled = val),
                            ),

                            // === NEW: SECURE KEY INPUT ===
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            const Text('Razorpay API Key (Live or Test)', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            const Text('Updates immediately across the app without requiring an app store update.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 12),
                            TextField(
                                controller: _razorpayKeyCtrl,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  prefixIcon: Icon(Icons.key, color: Colors.indigo),
                                  hintText: 'rzp_live_xxxxxxxxxxxxxx',
                                )
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // === CARD 3: STORE STATUS (KILL SWITCH) ===
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _isStoreOpen ? Colors.green : Colors.red, width: 2)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [Icon(Icons.power_settings_new, color: _isStoreOpen ? Colors.green : Colors.red), const SizedBox(width: 8), Expanded(child: Text('Operational Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _isStoreOpen ? Colors.green : Colors.red)))]),
                            const Divider(height: 32),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_isStoreOpen ? 'Store is OPEN and accepting orders.' : 'Store is CLOSED.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      const Text('Turn this off to prevent checkout during non-working hours.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _isStoreOpen,
                                  activeColor: Colors.green,
                                  inactiveThumbColor: Colors.red,
                                  onChanged: (val) => setState(() => _isStoreOpen = val),
                                )
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Text('Global Minimum Order Value (₹)', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            const Text('Customers cannot checkout if their cart is below this amount.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: isMobile ? double.infinity : 200,
                              child: TextField(controller: _minOrderCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), prefixText: '₹ ', isDense: true)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // === CARD 4: CONTACT DETAILS ===
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [Icon(Icons.contact_phone, color: Colors.blue), SizedBox(width: 8), Expanded(child: Text('Customer Support Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))]),
                            const Divider(height: 32),

                            _buildResponsiveRow(
                              isMobile: isMobile,
                              child1: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Support Phone No.', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 8), TextField(controller: _supportPhoneCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.phone)))]),
                              child2: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('WhatsApp Business No.', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 8), TextField(controller: _whatsappCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.chat)))]),
                            ),

                            const SizedBox(height: 16),
                            const Text('Support Email ID', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextField(controller: _emailCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, prefixIcon: Icon(Icons.email))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // === CARD 5: LEGAL & BUSINESS ===
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [Icon(Icons.business, color: Colors.orange), SizedBox(width: 8), Expanded(child: Text('Business Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))]),
                            const Divider(height: 32),

                            _buildResponsiveRow(
                              isMobile: isMobile,
                              child1: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Registered Store Name', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 8), TextField(controller: _storeNameCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true))]),
                              child2: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('GSTIN / MSME Udyam No.', style: TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 8), TextField(controller: _registrationCtrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true))]),
                            ),

                            const SizedBox(height: 16),
                            const Text('Complete Store Address', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextField(controller: _addressCtrl, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}