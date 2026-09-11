import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final singleOrderProvider = StreamProvider.family<DocumentSnapshot, String>((ref, orderId) {
  return FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots();
});

class OrderTrackingScreen extends ConsumerWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(singleOrderProvider(orderId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Order Details', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: orderAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, stack) => const Center(child: Text('Error loading details.')),
          data: (doc) {
            if (!doc.exists) return const Center(child: Text('Order not found!'));

            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'Placed';
            final items = List<Map<String, dynamic>>.from(data['items'] ?? []);

            // === NEW: Extract Payment Info ===
            final paymentMethod = data['paymentMethod'] ?? 'COD';
            final paymentId = data['paymentId'] ?? '';
            final isOnline = paymentMethod != 'COD';

            int currentStep = status == 'Packing' ? 1 : status == 'Out for Delivery' ? 2 : status == 'Delivered' ? 3 : 0;
            bool isCancelled = status == 'Cancelled';

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // 1. TIMELINE
                const Text('Tracking Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildTimeline(context, currentStep, isCancelled),
                const Divider(height: 40),

                // 2. ITEMS LIST
                const Text('Items Ordered', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...items.map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(item['imageUrl'] ?? '', width: 50, height: 50, fit: BoxFit.cover)),
                  title: Text(item['name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Qty: ${item['quantity']}'),
                  trailing: Text('₹${(item['price'] * item['quantity']).toInt()}'),
                )),
                const Divider(height: 32),

                // === 3. NEW PAYMENT DETAILS UI ===
                const Text('Payment Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: isOnline ? Colors.green[50] : Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isOnline ? Colors.green[200]! : Colors.orange[200]!)
                  ),
                  child: Row(
                    children: [
                      Icon(isOnline ? Icons.verified_user : Icons.money, color: isOnline ? Colors.green : Colors.orange, size: 30),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isOnline ? 'Paid Online' : 'Cash on Delivery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isOnline ? Colors.green[800] : Colors.orange[900])),
                            if (isOnline && paymentId.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Txn ID: $paymentId', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 32),

                // 4. BILL BREAKDOWN
                const Text('Bill Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildBillRow('Item Total', data['itemTotal']),
                _buildBillRow('Delivery Fee', data['deliveryFee']),
                _buildBillRow('Handling Fee', data['handlingFee']),
                if ((data['taxAmount'] ?? 0) > 0)
                  _buildBillRow('Tax Amount', data['taxAmount']),
                if ((data['discountApplied'] ?? 0) > 0)
                  _buildBillRow('Discount', -data['discountApplied'], isDiscount: true),

                const Divider(thickness: 2),
                _buildBillRow('GRAND TOTAL', data['grandTotal'], isBold: true),
              ],
            );
          }
      ),
    );
  }

  Widget _buildBillRow(String label, dynamic value, {bool isDiscount = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text('₹${(value ?? 0).toInt()}', style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.normal, color: isDiscount ? Colors.green : Colors.black)),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, int currentStep, bool isCancelled) {
    if (isCancelled) return const Center(child: Text('Order Cancelled', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)));

    final steps = ['Placed', 'Packing', 'On Way', 'Delivered'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(steps.length, (index) => Column(
        children: [
          Icon(index <= currentStep ? Icons.check_circle : Icons.circle_outlined,
              color: index <= currentStep ? Theme.of(context).primaryColor : Colors.grey),
          const SizedBox(height: 4),
          Text(steps[index], style: TextStyle(fontSize: 10, color: index <= currentStep ? Colors.black : Colors.grey)),
        ],
      )),
    );
  }
}