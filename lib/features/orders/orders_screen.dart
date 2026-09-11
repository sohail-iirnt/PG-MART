import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'order_tracking_screen.dart';
import '../auth/providers/auth_provider.dart';

// === LIVE ORDERS STREAM FOR LOGGED IN USER ===
final userOrdersProvider = StreamProvider<QuerySnapshot?>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null); // Wipes data if logged out

      return FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots();
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  // === NEW: CONDITIONAL CANCELLATION ENGINE ===
  Future<void> _cancelOrder(BuildContext context, String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: const Text('Are you sure you want to cancel this order? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NO', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('YES, CANCEL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': 'Cancelled'});
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order Cancelled Successfully'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cancelling order: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(userOrdersProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('My Orders', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          bottom: TabBar(
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).primaryColor,
            tabs: const [
              Tab(text: 'ACTIVE ORDERS'),
              Tab(text: 'PAST ORDERS'),
            ],
          ),
        ),
        body: ordersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, stack) => Center(child: Text('Error loading orders: $e')),
            data: (snapshot) {
              if (snapshot == null || snapshot.docs.isEmpty) {
                return const Center(child: Text('You have no orders yet.'));
              }

              // Filter Active Orders
              final activeOrders = snapshot.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'Pending';
                return status != 'Delivered' && status != 'Cancelled';
              }).toList();

              // Filter Past Orders
              final pastOrders = snapshot.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] ?? 'Pending';
                return status == 'Delivered' || status == 'Cancelled';
              }).toList();

              return TabBarView(
                children: [
                  // === ACTIVE ORDERS TAB ===
                  activeOrders.isEmpty
                      ? const Center(child: Text('No active orders.'))
                      : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: activeOrders.length,
                    itemBuilder: (context, index) {
                      final data = activeOrders[index].data() as Map<String, dynamic>;
                      final docId = activeOrders[index].id;
                      return _buildLiveOrderCard(context, docId, data);
                    },
                  ),

                  // === PAST ORDERS TAB ===
                  pastOrders.isEmpty
                      ? const Center(child: Text('No past orders.'))
                      : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: pastOrders.length,
                    itemBuilder: (context, index) {
                      final data = pastOrders[index].data() as Map<String, dynamic>;
                      final docId = pastOrders[index].id;
                      return _buildLiveOrderCard(context, docId, data);
                    },
                  ),
                ],
              );
            }
        ),
      ),
    );
  }

  // === DYNAMIC ORDER CARD ===
  Widget _buildLiveOrderCard(BuildContext context, String orderId, Map<String, dynamic> data) {
    final status = data['status'] ?? 'Placed';
    final amount = (data['grandTotal'] ?? 0.0).toString();

    // Determine Color based on status
    Color statusColor = Colors.orange;
    if (status == 'Delivered') statusColor = Colors.green;
    if (status == 'Cancelled') statusColor = Colors.red;
    if (status == 'Out for Delivery') statusColor = Colors.blue;

    // Format Date
    String displayDate = 'Unknown Date';
    if (data['createdAt'] != null) {
      final date = (data['createdAt'] as Timestamp).toDate();
      displayDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => OrderTrackingScreen(orderId: orderId)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(orderId.substring(0, 8).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), // Shortened ID
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                )
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Amount', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('₹$amount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Date / Time', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(displayDate, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                  ],
                ),
              ],
            ),
            // === NEW: CONDITIONAL CANCELLATION BUTTON ===
            if (status == 'Placed') ...[
              const Divider(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _cancelOrder(context, orderId),
                  child: const Text('CANCEL ORDER', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}