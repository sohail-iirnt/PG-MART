import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// === THE LIVE FEES ENGINE ===
final adminFeesProvider = StreamProvider<DocumentSnapshot>((ref) =>
    FirebaseFirestore.instance.collection('store_settings').doc('fees').snapshots());

class AdminFeesModule extends ConsumerStatefulWidget {
  final bool isDesktop;
  const AdminFeesModule({super.key, required this.isDesktop});

  @override
  ConsumerState<AdminFeesModule> createState() => _AdminFeesModuleState();
}

class _AdminFeesModuleState extends ConsumerState<AdminFeesModule> {
  final _deliveryFeeCtrl = TextEditingController();
  final _freeDelThresholdCtrl = TextEditingController();
  final _handlingFeeCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController();

  bool _isFreeDeliveryActive = false;
  bool _isSaving = false;

  // THE FIX: This stops the database from overwriting your unsaved edits!
  bool _isInitialized = false;

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('store_settings').doc('fees').set({
        'deliveryFee': double.tryParse(_deliveryFeeCtrl.text) ?? 0.0,
        'freeDeliveryThreshold': double.tryParse(_freeDelThresholdCtrl.text) ?? 0.0,
        'handlingFee': double.tryParse(_handlingFeeCtrl.text) ?? 0.0,
        'taxRatePercentage': double.tryParse(_taxRateCtrl.text) ?? 0.0,
        'isFreeDeliveryActive': _isFreeDeliveryActive,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fees & Taxes updated successfully!'), backgroundColor: Colors.green));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _deliveryFeeCtrl.dispose();
    _freeDelThresholdCtrl.dispose();
    _handlingFeeCtrl.dispose();
    _taxRateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feesAsync = ref.watch(adminFeesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text('Control dynamic pricing, taxes, and delivery rules for the entire platform.', style: TextStyle(color: Colors.grey, fontSize: widget.isDesktop ? 16 : 14))),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              icon: const Icon(Icons.save, color: Colors.white, size: 18),
              label: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('SAVE SETTINGS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _isSaving ? null : _saveSettings,
            )
          ],
        ),
        const SizedBox(height: 24),

        Expanded(
          child: feesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, stack) => Center(child: Text('Error: $e')),
              data: (snapshot) {

                // THE FIX: We only pull data from the cloud the VERY FIRST time the screen opens.
                if (!_isInitialized) {
                  if (snapshot.exists && snapshot.data() != null) {
                    final data = snapshot.data() as Map<String, dynamic>;
                    _deliveryFeeCtrl.text = data['deliveryFee']?.toString() ?? '40';
                    _freeDelThresholdCtrl.text = data['freeDeliveryThreshold']?.toString() ?? '500';
                    _handlingFeeCtrl.text = data['handlingFee']?.toString() ?? '15';
                    _taxRateCtrl.text = data['taxRatePercentage']?.toString() ?? '0';
                    _isFreeDeliveryActive = data['isFreeDeliveryActive'] ?? false;
                  } else {
                    // Defaults for brand new database
                    _deliveryFeeCtrl.text = '40';
                    _freeDelThresholdCtrl.text = '500';
                    _handlingFeeCtrl.text = '15';
                    _taxRateCtrl.text = '0';
                  }
                  _isInitialized = true; // Lock it! No more overwriting!
                }

                return SingleChildScrollView(
                  child: Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        children: [
                          // === CARD 1: DELIVERY SETTINGS ===
                          Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(children: [Icon(Icons.local_shipping, color: Colors.blue), SizedBox(width: 8), Text('Logistics & Delivery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                                  const Divider(height: 32),

                                  // Master Toggle
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: _isFreeDeliveryActive ? Colors.green.withOpacity(0.1) : Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: _isFreeDeliveryActive ? Colors.green : Colors.transparent)),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // === FIX 5: WRAPPED IN EXPANDED TO FIX OVERFLOW ===
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Global Free Delivery Promotion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              Text('Overrides standard fees. Great for festive weekends.', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        Switch(
                                            value: _isFreeDeliveryActive,
                                            activeColor: Colors.green,
                                            onChanged: (val) {
                                              setState(() => _isFreeDeliveryActive = val);
                                            }
                                        )
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  Row(
                                    children: [
                                      Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Standard Delivery Fee (₹)', style: TextStyle(fontWeight: FontWeight.w600)),
                                              const SizedBox(height: 8),
                                              TextField(controller: _deliveryFeeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), prefixText: '₹ ', isDense: true)),
                                            ],
                                          )
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Free Delivery Above (₹)', style: TextStyle(fontWeight: FontWeight.w600)),
                                              const SizedBox(height: 8),
                                              TextField(controller: _freeDelThresholdCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), prefixText: '₹ ', isDense: true)),
                                            ],
                                          )
                                      )
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // === CARD 2: PLATFORM FEES & TAXES ===
                          Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(children: [Icon(Icons.account_balance, color: Colors.purple), SizedBox(width: 8), Text('Platform Fees & Taxes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                                  const Divider(height: 32),

                                  Row(
                                    children: [
                                      Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Handling / Packing Fee (₹)', style: TextStyle(fontWeight: FontWeight.w600)),
                                              const Text('Fixed platform fee per order', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                              const SizedBox(height: 8),
                                              TextField(controller: _handlingFeeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), prefixText: '₹ ', isDense: true)),
                                            ],
                                          )
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Standard Tax Rate (%)', style: TextStyle(fontWeight: FontWeight.w600)),
                                              const Text('Global GST applied if applicable', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                              const SizedBox(height: 8),
                                              TextField(controller: _taxRateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), suffixText: ' %', isDense: true)),
                                            ],
                                          )
                                      )
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
          ),
        ),
      ],
    );
  }
}