import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class AdminBulkOrdersModule extends StatelessWidget {
  const AdminBulkOrdersModule({super.key});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _updateStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance.collection('bulk_orders').doc(docId).update({'status': newStatus});
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'contacted': return Colors.blue;
      case 'deal_closed': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk & Event Leads'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('bulk_orders').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No bulk orders yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final createdAt = data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now();

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Type & Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(data['eventType']?.toString().toUpperCase() ?? 'EVENT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: _getStatusColor(data['status']).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text(data['status']?.toString().toUpperCase() ?? 'PENDING', style: TextStyle(color: _getStatusColor(data['status']), fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const Divider(),

                      // Details
                      Text('Date Expected: ${data['expectedDate']}', style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      const Text('Requirements:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(top: 4, bottom: 12),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
                        child: Text(data['requirements'] ?? ''),
                      ),
                      Text('Submitted: ${DateFormat('dd MMM yyyy, hh:mm a').format(createdAt)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),

                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                              onPressed: () => _makePhoneCall(data['phone'] ?? ''),
                              icon: const Icon(Icons.call, size: 18),
                              label: const Text('Call Customer'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            onSelected: (val) => _updateStatus(doc.id, val),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(8)),
                              child: const Text('Change Status', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'pending', child: Text('Mark Pending')),
                              const PopupMenuItem(value: 'contacted', child: Text('Mark Contacted')),
                              const PopupMenuItem(value: 'deal_closed', child: Text('Deal Closed (Won)')),
                              const PopupMenuItem(value: 'rejected', child: Text('Rejected (Lost)')),
                            ],
                          )
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}