import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

final liveOrdersProvider = StreamProvider<QuerySnapshot>((ref) => FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).snapshots());

class AdminOrdersModule extends ConsumerStatefulWidget {
  final bool isDesktop;
  const AdminOrdersModule({super.key, required this.isDesktop});

  @override
  ConsumerState<AdminOrdersModule> createState() => _AdminOrdersModuleState();
}

class _AdminOrdersModuleState extends ConsumerState<AdminOrdersModule> {
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} - ${date.hour > 12 ? date.hour - 12 : date.hour}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> _sendPushNotification(String fcmToken, String title, String body) async {
    try {
      final serviceAccountJson = {
       /*Detailes hidden*/
      };

      List<String> scopes = ["https://www.googleapis.com/auth/firebase.messaging"];
      http.Client client = await clientViaServiceAccount(ServiceAccountCredentials.fromJson(serviceAccountJson), scopes);

      final String projectId = serviceAccountJson['project_id']!;
      final Uri url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

      final payload = {
        'message': {
          'token': fcmToken,
          'notification': { 'title': title, 'body': body },
        }
      };

      await client.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload));
      client.close();
    } catch (e) {
      debugPrint("❌ Error sending V1 push notification: $e");
    }
  }

  Future<void> _updateOrderStatus(String orderId, String currentStatus, String userId) async {
    String newStatus = currentStatus == 'Placed' ? 'Packing' : currentStatus == 'Packing' ? 'Out for Delivery' : 'Delivered';
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': newStatus});

    if (userId != 'guest') {
      try {
        String title = 'Order Update 📦';
        String body = 'Your PG Mart order is now $newStatus!';
        if (newStatus == 'Out for Delivery') { title = 'Out for Delivery! 🚚'; body = 'Your PG Mart order is on its way to you!'; }
        else if (newStatus == 'Delivered') { title = 'Order Delivered! ✅'; body = 'Thank you for shopping with PG Mart. See you next time!'; }

        await FirebaseFirestore.instance.collection('users').doc(userId).collection('notifications').add({
          'title': title, 'body': body, 'type': 'Update', 'createdAt': FieldValue.serverTimestamp(),
        });

        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        final String? token = userDoc.data()?['fcmToken'];
        if (token != null && token.isNotEmpty) await _sendPushNotification(token, title, body);
      } catch (e) {
        debugPrint('Failed to update notifications: $e');
      }
    }
  }

  // === FLIPKART/AMAZON STYLE PDF INVOICE ===
  Future<void> _printInvoice(String orderId, Map<String, dynamic> orderData) async {
    final pdf = pw.Document();
    final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);

    final paymentMethod = orderData['paymentMethod'] ?? 'COD';
    final paymentId = orderData['paymentId'] ?? '';
    final isOnline = paymentMethod != 'COD';

    pw.Widget buildPdfBillRow(String label, dynamic value) {
      return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Rs. $value', style: const pw.TextStyle(fontSize: 10)),
              ]
          )
      );
    }

    pdf.addPage(
        pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return [
                // 1. HEADER (BRANDING & INVOICE DETAILS)
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('PG MART', style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                            pw.Text('PREMIUM CHOICE, LESS RATE', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, letterSpacing: 1)),
                            pw.SizedBox(height: 10),
                            pw.Text('Bhiwandi, Maharashtra, India', style: const pw.TextStyle(fontSize: 10)),
                            pw.Text('Email: support@pgmart.in', style: const pw.TextStyle(fontSize: 10)),
                          ]
                      ),
                      pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                            pw.SizedBox(height: 10),
                            pw.Text('Order ID: ${orderId.toUpperCase()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                            pw.Text('Date: ${_formatTime(orderData['createdAt'] as Timestamp?)}', style: const pw.TextStyle(fontSize: 10)),
                            pw.SizedBox(height: 6),
                            // PAYMENT BADGE
                            pw.Container(
                                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: pw.BoxDecoration(
                                    color: isOnline ? PdfColors.green50 : PdfColors.orange50,
                                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                                    border: pw.Border.all(color: isOnline ? PdfColors.green : PdfColors.orange)
                                ),
                                child: pw.Text(
                                    isOnline ? 'PAID ONLINE (Txn: $paymentId)' : 'CASH ON DELIVERY',
                                    style: pw.TextStyle(color: isOnline ? PdfColors.green800 : PdfColors.orange800, fontWeight: pw.FontWeight.bold, fontSize: 9)
                                )
                            )
                          ]
                      )
                    ]
                ),
                pw.SizedBox(height: 30),

                // 2. SHIPPING DETAILS
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                          child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Billed & Shipped To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.indigo900)),
                                pw.SizedBox(height: 5),
                                pw.Text('${orderData['deliveryAddress']}', style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
                                pw.SizedBox(height: 5),
                                pw.Text('Phone: ${orderData['userPhone']}', style: const pw.TextStyle(fontSize: 11)),
                              ]
                          )
                      ),
                      pw.SizedBox(width: 40),
                    ]
                ),
                pw.SizedBox(height: 30),

                // 3. PRODUCT TABLE
                pw.Table.fromTextArray(
                    context: context,
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo50),
                    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.indigo900),
                    cellStyle: const pw.TextStyle(fontSize: 10),
                    cellAlignments: {
                      0: pw.Alignment.centerLeft,
                      1: pw.Alignment.center,
                      2: pw.Alignment.centerRight,
                      3: pw.Alignment.centerRight,
                    },
                    data: [
                      ['Product Description', 'Qty', 'Unit Price', 'Total Amount'],
                      ...items.map((item) => [
                        item['name'].toString(),
                        item['quantity'].toString(),
                        'Rs. ${item['price']}',
                        'Rs. ${item['price'] * item['quantity']}'
                      ])
                    ]
                ),
                pw.SizedBox(height: 20),

                // 4. FINANCIAL BREAKDOWN
                pw.Container(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Container(
                        width: 250,
                        child: pw.Column(
                            children: [
                              buildPdfBillRow('Item Total', orderData['itemTotal']),
                              buildPdfBillRow('Delivery Fee', orderData['deliveryFee']),
                              buildPdfBillRow('Handling Fee', orderData['handlingFee']),
                              if ((orderData['taxAmount'] ?? 0) > 0)
                                buildPdfBillRow('Tax Amount', orderData['taxAmount']),
                              if ((orderData['discountApplied'] ?? 0) > 0)
                                buildPdfBillRow('Discount', '-${orderData['discountApplied']}'),
                              pw.Divider(color: PdfColors.grey400),
                              pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                                child: pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text('GRAND TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                                      pw.Text('Rs. ${orderData['grandTotal']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.green800)),
                                    ]
                                ),
                              )
                            ]
                        )
                    )
                ),
                pw.SizedBox(height: 40),

                // 5. FOOTER
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 10),
                pw.Text('Thank you for shopping with PG Mart!', style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10, fontStyle: pw.FontStyle.italic), textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 4),
                pw.Text('This is a computer-generated invoice and does not require a physical signature.', style: pw.TextStyle(color: PdfColors.grey600, fontSize: 8), textAlign: pw.TextAlign.center),
              ];
            }
        )
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'PG_Mart_Invoice_${orderId.substring(0, 6)}.pdf'
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(liveOrdersProvider);

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) => Center(child: Text('Error: $e')),
      data: (snapshot) {
        if (snapshot.docs.isEmpty) return const Center(child: Text('No orders yet...', style: TextStyle(color: Colors.grey)));
        return ListView.builder(
          itemCount: snapshot.docs.length,
          itemBuilder: (context, index) {
            final orderData = snapshot.docs[index].data() as Map<String, dynamic>;
            final orderId = snapshot.docs[index].id;
            final status = orderData['status'] ?? 'Placed';
            final userId = orderData['userId'] ?? 'guest';
            final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);

            final paymentMethod = orderData['paymentMethod'] ?? 'COD';
            final paymentId = orderData['paymentId'] ?? '';
            final isOnline = paymentMethod != 'COD';

            Color statusColor = status == 'Delivered' ? Colors.green : status == 'Out for Delivery' ? Colors.purple : status == 'Packing' ? Colors.blue : Colors.orange;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: EdgeInsets.all(widget.isDesktop ? 20 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Order #${orderId.substring(0, 8).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor)), child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)))]),
                    const Divider(height: 16),
                    Text('${orderData['userPhone']} • ${_formatTime(orderData['createdAt'] as Timestamp?)}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('${orderData['deliveryAddress']}', style: const TextStyle(fontSize: 13)),

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: isOnline ? Colors.green[50] : Colors.orange[50], borderRadius: BorderRadius.circular(4), border: Border.all(color: isOnline ? Colors.green : Colors.orange)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(isOnline ? Icons.check_circle : Icons.money, size: 14, color: isOnline ? Colors.green : Colors.orange),
                              const SizedBox(width: 4),
                              Text(isOnline ? 'PAID ONLINE' : 'CASH ON DELIVERY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isOnline ? Colors.green : Colors.orange)),
                            ],
                          ),
                        ),
                        if (isOnline && paymentId.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text('Txn: ${paymentId.length > 10 ? '${paymentId.substring(0, 10)}...' : paymentId}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ]
                      ],
                    ),
                    const SizedBox(height: 12),

                    ...items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text('${item['quantity']}x ${item['name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))), const SizedBox(width: 8), Text('₹${item['price'] * item['quantity']}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))]))),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: Text('Total: ₹${orderData['grandTotal']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Theme.of(context).primaryColor))),
                        Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          IconButton(icon: const Icon(Icons.print, color: Colors.blueGrey), onPressed: () => _printInvoice(orderId, orderData)),
                          if (status != 'Delivered') ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: statusColor, padding: const EdgeInsets.symmetric(horizontal: 12)),
                              onPressed: () => _updateOrderStatus(orderId, status, userId),
                              child: Text(status == 'Placed' ? 'PACKING' : status == 'Packing' ? 'OUT FOR DELIVERY' : 'DELIVERED', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))
                          ),
                        ]),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
