import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/cart_provider.dart';
import '../checkout/checkout_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// State to hold our active discount amount
final discountProvider = StateProvider<double>((ref) => 0.0);

// === NEW: LIVE FEES PROVIDER ===
final storeFeesProvider = StreamProvider<DocumentSnapshot>((ref) =>
    FirebaseFirestore.instance.collection('store_settings').doc('fees').snapshots());

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  // THE LIVE COUPON BOTTOM SHEET
  void _showCouponSheet(BuildContext context, WidgetRef ref) {
    final TextEditingController couponController = TextEditingController();
    bool isChecking = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 24, right: 24, top: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Apply Coupon', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: couponController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: 'Enter Code (e.g. DIWALI50)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                        onPressed: isChecking ? null : () async {
                          final code = couponController.text.trim().toUpperCase();
                          if (code.isEmpty) return;

                          setSheetState(() => isChecking = true);

                          try {
                            final querySnapshot = await FirebaseFirestore.instance
                                .collection('coupons')
                                .where('code', isEqualTo: code)
                                .limit(1)
                                .get();

                            if (querySnapshot.docs.isEmpty) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid coupon code.'), backgroundColor: Colors.red));
                              setSheetState(() => isChecking = false);
                              return;
                            }

                            final couponData = querySnapshot.docs.first.data();
                            final isActive = couponData['isActive'] ?? false;
                            final minOrderValue = (couponData['minOrderValue'] ?? 0).toDouble();
                            final discountAmount = (couponData['discountAmount'] ?? 0).toDouble();

                            if (!isActive) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This coupon has expired.'), backgroundColor: Colors.red));
                              setSheetState(() => isChecking = false);
                              return;
                            }

                            final cartItems = ref.read(cartProvider);
                            final itemTotal = cartItems.fold<double>(0.0, (sum, item) => sum + (item.product.price * item.quantity));

                            if (itemTotal < minOrderValue) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Minimum order of ₹$minOrderValue required for this coupon.'), backgroundColor: Colors.orange));
                              setSheetState(() => isChecking = false);
                              return;
                            }

                            ref.read(discountProvider.notifier).state = discountAmount;
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('₹${discountAmount.toStringAsFixed(0)} Discount Applied!'), backgroundColor: Colors.green));
                            }
                          } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                            setSheetState(() => isChecking = false);
                          }
                        },
                        child: isChecking
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('APPLY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final discount = ref.watch(discountProvider);

    // === NEW: FETCH LIVE FEES ===
    final feesAsync = ref.watch(storeFeesProvider);

    // Safety Defaults (Just in case the internet drops)
    double baseDeliveryFee = 40.0;
    double freeDelThreshold = 500.0;
    double handlingFee = 15.0;
    double taxRate = 0.0;
    bool isFreeDeliveryActive = false;

    // Overwrite defaults with Live Data if available
    if (feesAsync.value != null && feesAsync.value!.exists) {
      final data = feesAsync.value!.data() as Map<String, dynamic>;
      baseDeliveryFee = (data['deliveryFee'] ?? 40.0).toDouble();
      freeDelThreshold = (data['freeDeliveryThreshold'] ?? 500.0).toDouble();
      handlingFee = (data['handlingFee'] ?? 15.0).toDouble();
      taxRate = (data['taxRatePercentage'] ?? 0.0).toDouble();
      isFreeDeliveryActive = data['isFreeDeliveryActive'] ?? false;
    }

    // === LIVE CALCULATIONS ===
    final itemTotal = cartItems.fold<double>(0.0, (sum, item) => sum + (item.product.price * item.quantity));

    // Delivery Logic (Checks for Master Toggle OR Threshold)
    final isFreeDelivery = isFreeDeliveryActive || (itemTotal >= freeDelThreshold);
    final deliveryFee = isFreeDelivery ? 0.0 : baseDeliveryFee;

    // Tax Logic
    final taxAmount = (itemTotal * taxRate) / 100;

    final grandTotal = (itemTotal + deliveryFee + handlingFee + taxAmount - discount).clamp(0.0, double.infinity);

    // ==========================================
    // EMPTY CART STATE
    // ==========================================
    if (cartItems.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 100, color: Colors.grey[300]),
              const SizedBox(height: 20),
              const Text('Your cart is empty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Add some wholesale items to get started!', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('BROWSE PRODUCTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
              )
            ],
          ),
        ),
      );
    }

    // ==========================================
    // ACTIVE CART STATE
    // ==========================================
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Your Cart', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. ITEMS LIST
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cartItems.length,
              separatorBuilder: (context, index) => Divider(color: Colors.grey[200], height: 1),
              itemBuilder: (context, index) {
                final item = cartItems[index];
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item.product.imageUrl, width: 60, height: 60, fit: BoxFit.cover)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('₹${item.product.price.toStringAsFixed(0)}', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2))),
                        child: Row(
                          children: [
                            IconButton(constraints: const BoxConstraints(minWidth: 32, minHeight: 32), padding: EdgeInsets.zero, icon: Icon(Icons.remove, size: 18, color: Theme.of(context).primaryColor), onPressed: () => cartNotifier.removeSingleItem(item.product.id)),
                            Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(constraints: const BoxConstraints(minWidth: 32, minHeight: 32), padding: EdgeInsets.zero, icon: Icon(Icons.add, size: 18, color: Theme.of(context).primaryColor), onPressed: () => cartNotifier.addToCart(item.product)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // 2. LIVE COUPON SECTION
          GestureDetector(
            onTap: () => _showCouponSheet(context, ref),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: discount > 0 ? Colors.green : Colors.transparent)),
              child: Row(
                children: [
                  Icon(Icons.local_offer_outlined, color: discount > 0 ? Colors.green : Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(child: Text(discount > 0 ? 'Coupon Applied! (-₹${discount.toStringAsFixed(0)})' : 'Apply Coupon Code', style: TextStyle(fontWeight: FontWeight.bold, color: discount > 0 ? Colors.green : Colors.black))),
                  if (discount > 0)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => ref.read(discountProvider.notifier).state = 0.0,
                    )
                  else
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. LIVE BILL DETAILS
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bill Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildBillRow('Item Total', itemTotal),
                const SizedBox(height: 12),

                // Delivery Row dynamically reacts to Admin Panel
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Delivery Fee', style: TextStyle(color: Colors.grey)),
                    Row(
                      children: [
                        if (isFreeDelivery) Text('₹${baseDeliveryFee.toStringAsFixed(0)}', style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 12)),
                        const SizedBox(width: 4),
                        Text(isFreeDelivery ? 'FREE' : '₹${baseDeliveryFee.toStringAsFixed(0)}', style: TextStyle(color: isFreeDelivery ? Colors.green : Colors.black, fontWeight: isFreeDelivery ? FontWeight.bold : FontWeight.normal)),
                      ],
                    )
                  ],
                ),

                const SizedBox(height: 12),
                _buildBillRow('Handling Charge', handlingFee),

                // Show Tax Row ONLY if Admin sets a tax rate > 0
                if (taxRate > 0) ...[
                  const SizedBox(height: 12),
                  _buildBillRow('Taxes (${taxRate.toStringAsFixed(1)}%)', taxAmount),
                ],

                // SHOW DISCOUNT ROW IF APPLIED
                if (discount > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Discount Applied', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      Text('-₹${discount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],

                const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Grand Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('₹${grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ],
                ),

                // Promo Message if close to free delivery
                if (!isFreeDelivery && (freeDelThreshold - itemTotal > 0) && !isFreeDeliveryActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Add ₹${(freeDelThreshold - itemTotal).toStringAsFixed(0)} more to get FREE Delivery!', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),

                // Promo Message if Free Delivery Weekend is Active
                if (isFreeDeliveryActive)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('🎁 Free Delivery Promo Active!', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                  )
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total to pay', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text('₹${grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CheckoutScreen())),
                      child: const Text('CHECKOUT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBillRow(String title, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey)),
        Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}