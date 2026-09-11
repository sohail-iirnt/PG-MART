import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// === LIVE DATA STREAMS ===
final allOrdersProvider = StreamProvider<QuerySnapshot>((ref) =>
    FirebaseFirestore.instance.collection('orders').snapshots());

final allUsersProvider = StreamProvider<QuerySnapshot>((ref) =>
    FirebaseFirestore.instance.collection('users').snapshots());

class AdminAnalyticsModule extends ConsumerWidget {
  final bool isDesktop;
  const AdminAnalyticsModule({super.key, required this.isDesktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(allOrdersProvider);
    final usersAsync = ref.watch(allUsersProvider);

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) => Center(child: Text('Error loading analytics: $e')),
      data: (ordersSnapshot) {
        final orders = ordersSnapshot.docs;

        // 1. Crunching the Numbers
        double totalRevenue = 0.0;
        double pendingRevenue = 0.0;
        int placed = 0;
        int packing = 0;
        int outForDelivery = 0;
        int delivered = 0;
        int cancelled = 0;

        for (var doc in orders) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'Placed';
          final grandTotal = (data['grandTotal'] ?? 0.0).toDouble();

          if (status == 'Delivered') {
            totalRevenue += grandTotal;
            delivered++;
          } else if (status == 'Cancelled') {
            cancelled++;
          } else {
            pendingRevenue += grandTotal;
            if (status == 'Placed') placed++;
            if (status == 'Packing') packing++;
            if (status == 'Out for Delivery') outForDelivery++;
          }
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Business Overview', style: TextStyle(color: Colors.grey[600], fontSize: isDesktop ? 16 : 14)),
              const SizedBox(height: 16),

              // === TOP KPI CARDS ===
              GridView.count(
                crossAxisCount: isDesktop ? 3 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isDesktop ? 2.5 : 1.5,
                children: [
                  _buildKpiCard(
                    context,
                    title: 'Total Revenue (Delivered)',
                    value: '₹${totalRevenue.toStringAsFixed(0)}',
                    icon: Icons.account_balance_wallet,
                    gradientColors: [Colors.green[700]!, Colors.green[400]!],
                  ),
                  _buildKpiCard(
                    context,
                    title: 'Expected Revenue (Pending)',
                    value: '₹${pendingRevenue.toStringAsFixed(0)}',
                    icon: Icons.trending_up,
                    gradientColors: [Colors.blue[700]!, Colors.blue[400]!],
                  ),
                  usersAsync.when(
                    loading: () => _buildKpiCard(context, title: 'Registered Customers', value: '...', icon: Icons.people, gradientColors: [Colors.purple[700]!, Colors.purple[400]!]),
                    error: (_, __) => _buildKpiCard(context, title: 'Registered Customers', value: 'Error', icon: Icons.people, gradientColors: [Colors.purple[700]!, Colors.purple[400]!]),
                    data: (userSnap) => _buildKpiCard(
                      context,
                      title: 'Registered Customers',
                      value: userSnap.docs.length.toString(),
                      icon: Icons.people,
                      gradientColors: [Colors.purple[700]!, Colors.purple[400]!],
                    ),
                  ),
                  _buildKpiCard(
                    context,
                    title: 'Total Lifetime Orders',
                    value: orders.length.toString(),
                    icon: Icons.shopping_bag,
                    gradientColors: [Colors.orange[700]!, Colors.orange[400]!],
                  ),
                ],
              ),

              const SizedBox(height: 32),
              Text('Live Order Fulfillment', style: TextStyle(color: Colors.grey[600], fontSize: isDesktop ? 16 : 14)),
              const SizedBox(height: 16),

              // === STATUS BREAKDOWN CARDS ===
              GridView.count(
                crossAxisCount: isDesktop ? 5 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isDesktop ? 1.5 : 1.2,
                children: [
                  _buildStatusCard('Placed', placed, Colors.orange),
                  _buildStatusCard('Packing', packing, Colors.blue),
                  _buildStatusCard('Out for Delivery', outForDelivery, Colors.purple),
                  _buildStatusCard('Delivered', delivered, Colors.green),
                  _buildStatusCard('Cancelled', cancelled, Colors.red),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Beautiful Gradient KPI Card
  Widget _buildKpiCard(BuildContext context, {required String title, required String value, required IconData icon, required List<Color> gradientColors}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: gradientColors.last.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
              Icon(icon, color: Colors.white54, size: 24),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  // Clean Status Breakdown Card
  Widget _buildStatusCard(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(count.toString(), style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}