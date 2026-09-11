import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:firebase_analytics/firebase_analytics.dart'; // === NEW: ANALYTICS IMPORT ===
import '../cart/providers/cart_provider.dart';
import '../cart/cart_screen.dart';
import '../address/providers/address_provider.dart';
import 'order_success_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../auth/providers/auth_provider.dart';
import '../address/address_screen.dart'; // === ENSURE ADDRESS SCREEN IS IMPORTED ===

final checkoutSettingsProvider = StreamProvider<DocumentSnapshot>((ref) =>
    FirebaseFirestore.instance.collection('store_settings').doc('general').snapshots());

final activeCouponsProvider = StreamProvider<QuerySnapshot>((ref) =>
    FirebaseFirestore.instance.collection('coupons').where('isActive', isEqualTo: true).snapshots());

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _selectedPaymentMethod = 'COD';
  bool _isLoading = false;
  String? _appliedCouponCode;

  // === 1. RAZORPAY INSTANCE ===
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    // === 2. INITIALIZE LISTENERS ===
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    super.dispose();
    _razorpay.clear();
  }

  // === 3. PAYMENT EVENT HANDLERS ===
  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _finalizeOrderCreation(response.paymentId ?? 'online_payment');
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment Failed or Cancelled', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red)
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  // === 4. START CHECKOUT FLOW ===
  Future<void> _processCheckout(String deliveryAddress, double grandTotal) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final phone = userDoc.data()?['phone'] ?? '';
      String cleanPhone = phone.toString().replaceAll(RegExp(r'[^0-9]'), '');

      if (cleanPhone.isEmpty || cleanPhone.length < 10) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Please add your Mobile Number in your Profile before ordering!', style: TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              )
          );
          Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
        }
        return;
      }
    }

    setState(() => _isLoading = true);

    // === NEW: FIREBASE ANALYTICS (BEGIN CHECKOUT) ===
    final cartItems = ref.read(cartProvider);
    FirebaseAnalytics.instance.logBeginCheckout(
      value: grandTotal,
      currency: 'INR',
      items: cartItems.map((item) => AnalyticsEventItem(
        itemId: item.product.id,
        itemName: item.product.name,
        price: item.product.price,
        quantity: item.quantity,
      )).toList(),
    );

    if (_selectedPaymentMethod == 'COD') {
      _finalizeOrderCreation('COD');
    } else {
      _openRazorpay(grandTotal);
    }
  }

  // === 5. LAUNCH RAZORPAY UI (DYNAMIC KEY FIX) ===
  Future<void> _openRazorpay(double amount) async {
    final user = FirebaseAuth.instance.currentUser;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
    final phone = userDoc.data()?['phone'] ?? user?.phoneNumber ?? '';

    // === DYNAMIC API KEY FETCH ===
    String rzpKey = 'rzp_test_T3pMVmyUqfLCtH'; // Fallback
    try {
      final gatewayDoc = await FirebaseFirestore.instance.collection('store_settings').doc('gateways').get();
      if (gatewayDoc.exists && gatewayDoc.data() != null) {
        final data = gatewayDoc.data() as Map<String, dynamic>;
        rzpKey = data['razorpay_key'] ?? rzpKey;
      }
    } catch (e) {
      debugPrint('Error fetching Razorpay key: $e');
    }

    final int amountInPaise = (amount * 100).toInt();

    var options = {
      'key': rzpKey,
      'amount': amountInPaise,
      'name': 'PG MART',
      'description': 'Wholesale Order',
      'timeout': 120,
      'prefill': {
        'contact': phone,
      },
      'theme': {
        'color': '#4CAF50'
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error: $e');
    }
  }

  // === 6. SAVE TO FIREBASE ===
  Future<void> _finalizeOrderCreation(String paymentId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final cartItems = ref.read(cartProvider);
      final discount = ref.read(discountProvider);
      final feesSnapshot = ref.read(storeFeesProvider).value;

      double baseDeliveryFee = 40.0;
      double freeDelThreshold = 500.0;
      double handlingFee = 15.0;
      double taxRate = 0.0;
      bool isFreeDeliveryActive = false;

      if (feesSnapshot != null && feesSnapshot.exists) {
        final data = feesSnapshot.data() as Map<String, dynamic>;
        baseDeliveryFee = (data['deliveryFee'] ?? 40.0).toDouble();
        freeDelThreshold = (data['freeDeliveryThreshold'] ?? 500.0).toDouble();
        handlingFee = (data['handlingFee'] ?? 15.0).toDouble();
        taxRate = (data['taxRatePercentage'] ?? 0.0).toDouble();
        isFreeDeliveryActive = data['isFreeDeliveryActive'] ?? false;
      }

      final itemTotal = cartItems.fold<double>(0.0, (sum, item) => sum + (item.product.price * item.quantity));
      final isFreeDelivery = isFreeDeliveryActive || (itemTotal >= freeDelThreshold);
      final deliveryFee = isFreeDelivery ? 0.0 : baseDeliveryFee;
      final taxAmount = (itemTotal * taxRate) / 100;
      final grandTotal = (itemTotal + deliveryFee + handlingFee + taxAmount - discount).clamp(0.0, double.infinity);

      final List<Map<String, dynamic>> orderItems = cartItems.map((item) => {
        'productId': item.product.id,
        'name': item.product.name,
        'price': item.product.price,
        'quantity': item.quantity,
        'imageUrl': item.product.imageUrl,
      }).toList();

      final userDocFinal = await FirebaseFirestore.instance.collection('users').doc(user?.uid).get();
      final selectedAddressId = ref.read(selectedAddressProvider);
      final addresses = ref.read(addressStreamProvider).value ?? [];
      final selectedAddress = addresses.firstWhere((addr) => addr.id == selectedAddressId, orElse: () => addresses.first);

      await FirebaseFirestore.instance.collection('orders').add({
        'userId': user?.uid ?? 'guest',
        'userPhone': userDocFinal.data()?['phone'] ?? user?.phoneNumber ?? 'Unknown',
        'items': orderItems,
        'itemTotal': itemTotal,
        'deliveryFee': deliveryFee,
        'handlingFee': handlingFee,
        'taxAmount': taxAmount,
        'discountApplied': discount,
        'appliedCouponCode': _appliedCouponCode ?? '',
        'grandTotal': grandTotal,
        'paymentMethod': _selectedPaymentMethod,
        'paymentId': paymentId,
        'status': 'Placed',
        'createdAt': FieldValue.serverTimestamp(),
        'deliveryAddress': selectedAddress.fullAddress,
      });

      // === NEW: FIREBASE ANALYTICS (PURCHASE LOGGED) ===
      FirebaseAnalytics.instance.logPurchase(
        transactionId: paymentId == 'COD' ? 'COD_${DateTime.now().millisecondsSinceEpoch}' : paymentId,
        value: grandTotal,
        currency: 'INR',
        items: cartItems.map((item) => AnalyticsEventItem(
          itemId: item.product.id,
          itemName: item.product.name,
          price: item.product.price,
          quantity: item.quantity,
        )).toList(),
      );

      ref.read(cartProvider.notifier).clearCart();
      ref.read(discountProvider.notifier).state = 0.0;

      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const OrderSuccessScreen()), (route) => false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save order: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // === 7. APPLY COUPON LOGIC ===
  void _applyCoupon(String code, double discountValue) {
    setState(() => _appliedCouponCode = code);
    ref.read(discountProvider.notifier).state = discountValue;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Coupon $code Applied!'), backgroundColor: Colors.green));
  }

  void _removeCoupon() {
    setState(() => _appliedCouponCode = null);
    ref.read(discountProvider.notifier).state = 0.0;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coupon Removed'), backgroundColor: Colors.orange));
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final discount = ref.watch(discountProvider);
    final feesAsync = ref.watch(storeFeesProvider);

    final settingsAsync = ref.watch(checkoutSettingsProvider);
    final couponsAsync = ref.watch(activeCouponsProvider);

    final selectedAddressId = ref.watch(selectedAddressProvider);
    final addressesAsync = ref.watch(addressStreamProvider);
    final addresses = addressesAsync.value ?? [];

    final selectedAddress = addresses.firstWhere(
          (addr) => addr.id == selectedAddressId,
      orElse: () => addresses.isNotEmpty
          ? addresses.first
      // Fallback if empty
          : AddressModel(id: 'none', title: '', fullAddress: '', phone: ''),
    );

    bool isCodEnabled = true;
    bool isOnlineEnabled = true;

    if (settingsAsync.value != null && settingsAsync.value!.exists) {
      final data = settingsAsync.value!.data() as Map<String, dynamic>;
      isCodEnabled = data['isCodEnabled'] ?? true;
      isOnlineEnabled = data['isOnlinePaymentEnabled'] ?? true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedPaymentMethod == 'COD' && !isCodEnabled && isOnlineEnabled) {
        if(mounted) setState(() => _selectedPaymentMethod = 'Online');
      } else if (_selectedPaymentMethod == 'Online' && !isOnlineEnabled && isCodEnabled) {
        if(mounted) setState(() => _selectedPaymentMethod = 'COD');
      }
    });

    double baseDeliveryFee = 40.0;
    double freeDelThreshold = 500.0;
    double handlingFee = 15.0;
    double taxRate = 0.0;
    bool isFreeDeliveryActive = false;

    if (feesAsync.value != null && feesAsync.value!.exists) {
      final data = feesAsync.value!.data() as Map<String, dynamic>;
      baseDeliveryFee = (data['deliveryFee'] ?? 40.0).toDouble();
      freeDelThreshold = (data['freeDeliveryThreshold'] ?? 500.0).toDouble();
      handlingFee = (data['handlingFee'] ?? 15.0).toDouble();
      taxRate = (data['taxRatePercentage'] ?? 0.0).toDouble();
      isFreeDeliveryActive = data['isFreeDeliveryActive'] ?? false;
    }

    final itemTotal = cartItems.fold<double>(0.0, (sum, item) => sum + (item.product.price * item.quantity));
    final isFreeDelivery = isFreeDeliveryActive || (itemTotal >= freeDelThreshold);
    final deliveryFee = isFreeDelivery ? 0.0 : baseDeliveryFee;
    final taxAmount = (itemTotal * taxRate) / 100;

    final safeDiscount = discount > itemTotal ? itemTotal : discount;
    final grandTotal = (itemTotal + deliveryFee + handlingFee + taxAmount - safeDiscount).clamp(0.0, double.infinity);

    // === 🚨 THE FIX: addresses.isEmpty is NO LONGER DISABLING THE BUTTON 🚨 ===
    final isButtonDisabled = _isLoading || cartItems.isEmpty || (!isCodEnabled && !isOnlineEnabled);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Checkout', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Deliver To', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // === 🚨 THE FIX: DYNAMIC ADDRESS UI 🚨 ===
            if (addresses.isEmpty)
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddressScreen())),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!)
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_off_rounded, color: Colors.red[700], size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('No Address Found', style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('Tap here to add a delivery address', style: TextStyle(color: Colors.red[600], fontSize: 13)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: Colors.red[300], size: 16),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(selectedAddress.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                    const SizedBox(height: 8),
                    Text(selectedAddress.fullAddress, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            const Text('Available Offers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            couponsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => const Text('Could not load offers.'),
                data: (snapshot) {
                  if (snapshot.docs.isEmpty) return const Text('No active offers at the moment.', style: TextStyle(color: Colors.grey));

                  return SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: snapshot.docs.length,
                      itemBuilder: (context, index) {
                        final coupon = snapshot.docs[index].data() as Map<String, dynamic>;

                        final String code = coupon['code'] ?? 'OFFER';
                        final String desc = coupon['description'] ?? 'Special Discount';
                        final double minPurchase = (coupon['minOrderValue'] ?? 0).toDouble();
                        final double discountVal = (coupon['discountAmount'] ?? 0).toDouble();

                        final bool isEligible = itemTotal >= minPurchase;
                        final bool isApplied = _appliedCouponCode == code;

                        return Container(
                          width: 260,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: isApplied ? Colors.green[50] : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isApplied ? Colors.green : (isEligible ? Theme.of(context).primaryColor : Colors.grey[300]!),
                                width: isApplied ? 2 : 1,
                              )
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: isEligible ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                                    child: Text(code, style: TextStyle(fontWeight: FontWeight.bold, color: isEligible ? Theme.of(context).primaryColor : Colors.grey)),
                                  ),
                                  if (isApplied)
                                    GestureDetector(onTap: _removeCoupon, child: const Icon(Icons.cancel, color: Colors.red, size: 20))
                                  else if (isEligible)
                                    GestureDetector(
                                      onTap: () => _applyCoupon(code, discountVal),
                                      child: const Text('APPLY', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                    )
                                ],
                              ),
                              Text(desc, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                              if (!isEligible)
                                Text('Add ₹${(minPurchase - itemTotal).toStringAsFixed(0)} more to unlock', style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold))
                              else if (isApplied)
                                const Text('Coupon Applied!', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold))
                              else
                                Text('Save ₹${discountVal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                }
            ),
            const SizedBox(height: 24),

            const Text('Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            if (!isCodEnabled && !isOnlineEnabled)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [Icon(Icons.warning, color: Colors.red), SizedBox(width: 8), Expanded(child: Text('Checkout is currently disabled by Admin.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))]),
              ),

            if (isCodEnabled) ...[
              GestureDetector(
                onTap: () => setState(() => _selectedPaymentMethod = 'COD'),
                child: _buildPaymentOption(context, Icons.money, 'Cash on Delivery (COD)', _selectedPaymentMethod == 'COD'),
              ),
              const SizedBox(height: 12),
            ],

            if (isOnlineEnabled) ...[
              GestureDetector(
                onTap: () => setState(() => _selectedPaymentMethod = 'Online'),
                child: _buildPaymentOption(context, Icons.security, 'Pay Online (UPI, Card)', _selectedPaymentMethod == 'Online'),
              ),
            ],

            const SizedBox(height: 24),

            const Text('Final Bill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  _buildBillRow('Items Total', '₹${itemTotal.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  _buildBillRow('Delivery Fee', isFreeDelivery ? 'FREE' : '₹${baseDeliveryFee.toStringAsFixed(2)}', isDiscount: isFreeDelivery),
                  const SizedBox(height: 8),
                  _buildBillRow('Handling Fee', '₹${handlingFee.toStringAsFixed(2)}'),

                  if (taxRate > 0) ...[
                    const SizedBox(height: 8),
                    _buildBillRow('Taxes (${taxRate.toStringAsFixed(1)}%)', '₹${taxAmount.toStringAsFixed(2)}'),
                  ],

                  if (safeDiscount > 0) ...[
                    const SizedBox(height: 8),
                    _buildBillRow('Coupon Discount ($_appliedCouponCode)', '-₹${safeDiscount.toStringAsFixed(2)}', isDiscount: true),
                  ],

                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text('₹${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: isButtonDisabled ? Colors.grey : Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            // === 🚨 THE FIX: BUTTON ROUTES TO ADDRESS SCREEN IF NEEDED 🚨 ===
            onPressed: isButtonDisabled ? null : () {
              if (addresses.isEmpty) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AddressScreen()));
              } else {
                _processCheckout(selectedAddress.fullAddress, grandTotal);
              }
            },
            child: _isLoading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                : Text(
                addresses.isEmpty ? 'ADD ADDRESS TO CONTINUE' : 'PLACE ORDER',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(BuildContext context, IconData icon, String title, bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue[50] : Colors.white,
        border: Border.all(color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: isSelected ? Theme.of(context).primaryColor : Colors.grey),
          const SizedBox(width: 16),
          Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          const Spacer(),
          if (isSelected) Icon(Icons.check_circle, color: Theme.of(context).primaryColor),
        ],
      ),
    );
  }

  Widget _buildBillRow(String title, String value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(color: isDiscount ? Colors.green[700] : Colors.grey, fontWeight: isDiscount ? FontWeight.w600 : FontWeight.normal)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isDiscount ? Colors.green : Colors.black87)),
      ],
    );
  }
}