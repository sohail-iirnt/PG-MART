import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BulkOrderScreen extends StatefulWidget {
  const BulkOrderScreen({super.key});

  @override
  State<BulkOrderScreen> createState() => _BulkOrderScreenState();
}

class _BulkOrderScreenState extends State<BulkOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _eventTypeController = TextEditingController();
  final _dateController = TextEditingController();
  final _itemsController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitBulkOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Submit to Firebase
      await FirebaseFirestore.instance.collection('bulk_orders').add({
        'userId': user.uid,
        'phone': user.phoneNumber ?? 'No Phone', // Automatically grabs their registered number
        'eventType': _eventTypeController.text.trim(),
        'expectedDate': _dateController.text.trim(),
        'requirements': _itemsController.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Show Success and Pop Screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bulk requirement submitted! Our team will call you shortly with the best rates.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
      Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _eventTypeController.dispose();
    _dateController.dispose();
    _itemsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Bulk & Event Orders', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Graphic
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Theme.of(context).primaryColor, Colors.green[800]!]),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.handshake, color: Colors.white, size: 48),
                  SizedBox(height: 16),
                  Text('Need Wholesale Quantity?', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Weddings, Catering, or Party events. Tell us what you need, and we will give you the best B2B rates.', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),

            // Form
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Event Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _eventTypeController,
                      decoration: InputDecoration(
                        labelText: 'Event Type (e.g., Wedding, Catering)',
                        prefixIcon: const Icon(Icons.event),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) => value!.isEmpty ? 'Please enter the event type' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _dateController,
                      decoration: InputDecoration(
                        labelText: 'Expected Date',
                        prefixIcon: const Icon(Icons.calendar_month),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) => value!.isEmpty ? 'Please enter the expected date' : null,
                    ),
                    const SizedBox(height: 24),

                    const Text('Requirement List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _itemsController,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: 'Example:\n- 50kg Sugar\n- 15L Sunflower Oil\n- 10kg Cashews',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) => value!.isEmpty ? 'Please list your requirements' : null,
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        onPressed: _isLoading ? null : _submitBulkOrder,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('SUBMIT REQUIREMENT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: Text('We will call your registered phone number.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}