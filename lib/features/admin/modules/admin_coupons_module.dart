import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// === THE LIVE COUPONS ENGINE ===
final adminCouponsProvider = StreamProvider<QuerySnapshot>((ref) => FirebaseFirestore.instance.collection('coupons').orderBy('createdAt', descending: true).snapshots());

class AdminCouponsModule extends ConsumerStatefulWidget {
  final bool isDesktop;
  const AdminCouponsModule({super.key, required this.isDesktop});

  @override
  ConsumerState<AdminCouponsModule> createState() => _AdminCouponsModuleState();
}

class _AdminCouponsModuleState extends ConsumerState<AdminCouponsModule> {
  Future<void> _toggleCouponStatus(String couponId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('coupons').doc(couponId).update({'isActive': !currentStatus});
  }

  Future<void> _deleteCoupon(String couponId) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete Coupon?'), content: const Text('Are you sure?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: Colors.white)))]));
    if (confirm == true) await FirebaseFirestore.instance.collection('coupons').doc(couponId).delete();
  }

  void _showCouponDialog({String? couponId, Map<String, dynamic>? existingData}) {
    final isEditing = couponId != null;
    final codeCtrl = TextEditingController(text: existingData?['code'] ?? '');
    final discountCtrl = TextEditingController(text: existingData?['discountAmount']?.toString() ?? '');
    final minOrderCtrl = TextEditingController(text: existingData?['minOrderValue']?.toString() ?? '500'); // Default ₹500 min order
    bool isActive = existingData?['isActive'] ?? true;
    bool isSaving = false;

    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Coupon' : 'Create New Coupon', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(width: widget.isDesktop ? 400 : double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: codeCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Coupon Code (e.g. DIWALI50)', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextField(controller: discountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discount (₹)', border: OutlineInputBorder(), prefixText: '₹ '))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: minOrderCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min Order (₹)', border: OutlineInputBorder(), prefixText: '₹ '))),
                  ],
                ),
                const SizedBox(height: 16),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Active', style: TextStyle(fontWeight: FontWeight.w500)), Switch(value: isActive, activeColor: Colors.green, onChanged: (val) => setState(() => isActive = val))]))
              ])),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor), onPressed: isSaving ? null : () async {
                  if(codeCtrl.text.trim().isEmpty || discountCtrl.text.trim().isEmpty) return;
                  setState(() => isSaving = true);
                  try {
                    final couponData = {
                      'code': codeCtrl.text.trim().toUpperCase(),
                      'discountAmount': double.tryParse(discountCtrl.text) ?? 0.0,
                      'minOrderValue': double.tryParse(minOrderCtrl.text) ?? 0.0,
                      'isActive': isActive,
                      'updatedAt': FieldValue.serverTimestamp()
                    };
                    if (isEditing) { await FirebaseFirestore.instance.collection('coupons').doc(couponId).update(couponData); } else { couponData['createdAt'] = FieldValue.serverTimestamp(); await FirebaseFirestore.instance.collection('coupons').add(couponData); }
                    if (mounted) Navigator.pop(context);
                  } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); setState(() => isSaving = false); }
                }, child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : Text(isEditing ? 'UPDATE' : 'CREATE', style: const TextStyle(color: Colors.white))),
              ],
            );
          }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [if (widget.isDesktop) const Text('Manage discount codes and promo offers', style: TextStyle(color: Colors.grey, fontSize: 16)) else const Text('Coupons', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: EdgeInsets.symmetric(horizontal: widget.isDesktop ? 16 : 12, vertical: widget.isDesktop ? 16 : 10)), icon: const Icon(Icons.local_activity, color: Colors.white, size: 18), label: Text(widget.isDesktop ? 'CREATE COUPON' : 'ADD', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)), onPressed: () => _showCouponDialog())]),
        const SizedBox(height: 16),
        Expanded(
          child: Consumer(builder: (context, ref, child) {
            final couponsAsync = ref.watch(adminCouponsProvider);
            return couponsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()), error: (e, stack) => Center(child: Text('Error: $e')),
              data: (snapshot) {
                if (snapshot.docs.isEmpty) return const Center(child: Text('No coupons created yet.'));
                return GridView.builder(
                  // === FIX 1: TALLER ASPECT RATIO FOR MOBILE (0.85) ===
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: widget.isDesktop ? 4 : 2, childAspectRatio: widget.isDesktop ? 1.5 : 0.85, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemCount: snapshot.docs.length,
                  itemBuilder: (context, index) {
                    final data = snapshot.docs[index].data() as Map<String, dynamic>; final docId = snapshot.docs[index].id; final isActive = data['isActive'] ?? true;
                    return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isActive ? Theme.of(context).primaryColor : Colors.grey, width: 1.5)),
                        child: Padding(
                          // === FIX 2: RESPONSIVE PADDING ===
                          padding: EdgeInsets.all(widget.isDesktop ? 16 : 10),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // === FIX 3: FITTED BOX FOR LONG PROMO CODES ===
                                FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(data['code'] ?? '', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: isActive ? Theme.of(context).primaryColor : Colors.grey, letterSpacing: 2))
                                ),
                                const SizedBox(height: 4),

                                FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Flat ₹${data['discountAmount']} OFF', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15))
                                ),

                                FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Min Order: ₹${data['minOrderValue']}', style: const TextStyle(color: Colors.grey, fontSize: 11))
                                ),

                                const Spacer(),

                                // === FIX 4: PREVENT OVERFLOW ON BOTTOM ROW ===
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Switch(value: isActive, activeColor: Colors.green, onChanged: (val) => _toggleCouponStatus(docId, isActive)),
                                        Row(children: [
                                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _showCouponDialog(couponId: docId, existingData: data)),
                                          const SizedBox(width: 12),
                                          IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _deleteCoupon(docId))
                                        ])
                                      ]
                                  ),
                                )
                              ]
                          ),
                        )
                    );
                  },
                );
              },
            );
          }),
        ),
      ],
    );
  }
}