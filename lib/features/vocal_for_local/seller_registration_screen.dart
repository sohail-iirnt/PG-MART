import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class SellerRegistrationScreen extends StatefulWidget {
  const SellerRegistrationScreen({super.key});

  @override
  State<SellerRegistrationScreen> createState() => _SellerRegistrationScreenState();
}

class _SellerRegistrationScreenState extends State<SellerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _creatorNameCtrl = TextEditingController();
  final _brandNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _fssaiCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();

  String _selectedCategory = 'Home Bakers (Cakes & Sweets)';
  final List<String> _categories = [
    'Home Bakers (Cakes & Sweets)',
    'Crochet & Knitting',
    'Abayas, Hijabs & Modest Wear',
    'Customized Hampers & Gifting',
    'Aromatic Candles & Perfumes',
    'Resin Art & Frames',
    'Homemade Accessories & Jewelry',
    'Spices, Pickles & Snacks',
    'Other Homemade Goods'
  ];

  List<XFile> _sampleImages = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _creatorNameCtrl.dispose();
    _brandNameCtrl.dispose();
    _phoneCtrl.dispose();
    _areaCtrl.dispose();
    _bioCtrl.dispose();
    _fssaiCtrl.dispose();
    _instagramCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 75);
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _sampleImages.addAll(pickedFiles);
        if (_sampleImages.length > 5) {
          _sampleImages = _sampleImages.sublist(0, 5); // Limit to 5 images
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 5 images allowed.')));
        }
      });
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sampleImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload at least 1 sample image of your work.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Please log in to apply.');

      List<String> uploadedImageUrls = [];

      // Upload Images to Firebase Storage
      for (var file in _sampleImages) {
        final fileName = 'seller_${user.uid}_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final ref = FirebaseStorage.instance.ref().child('local_seller_samples/$fileName');
        await ref.putData(await file.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
        uploadedImageUrls.add(await ref.getDownloadURL());
      }

      // Save to Firestore
      await FirebaseFirestore.instance.collection('local_sellers').add({
        'userId': user.uid,
        'creatorName': _creatorNameCtrl.text.trim(),
        'brandName': _brandNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'area': _areaCtrl.text.trim(),
        'category': _selectedCategory,
        'fssaiNumber': _fssaiCtrl.text.trim(),
        'instagramId': _instagramCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'status': 'pending',
        'sampleImages': uploadedImageUrls,
        'isFeatured': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error submitting application: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
              child: const Icon(Icons.celebration, color: Colors.green, size: 60),
            ),
            const SizedBox(height: 24),
            const Text('Application Sent!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Welcome to the B1D Entrepreneurs family. Our team will review your application and contact you shortly.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to profile
                },
                child: const Text('BACK TO HOME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Partner With Us', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- PREMIUM HEADER ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 100, 24, 40),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFFAB47BC)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: const Text('B1D Entrepreneurs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Turn Your Home\nInto a Brand.', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
                  const SizedBox(height: 12),
                  Text('Sell your handcrafted cakes, clothes, and arts to all of Bhiwandi with zero logistical headache.', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.5)),
                ],
              ),
            ),

            // --- FORM SECTION ---
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('1. Brand Details'),
                    _buildTextField(controller: _brandNameCtrl, label: 'Kitchen / Brand Name', icon: Icons.storefront, hint: 'e.g. Shabana\'s Bakes'),
                    const SizedBox(height: 16),
                    _buildTextField(controller: _creatorNameCtrl, label: 'Your Full Name', icon: Icons.person_outline),
                    const SizedBox(height: 16),
                    _buildTextField(controller: _phoneCtrl, label: 'WhatsApp / Call Number', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildTextField(controller: _areaCtrl, label: 'Bhiwandi Area (For Pickup)', icon: Icons.location_on_outlined, hint: 'e.g. Nizampura, near Jama Masjid'),

                    const SizedBox(height: 32),
                    _buildSectionTitle('2. What do you make?'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.purple),
                          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.w500)))).toList(),
                          onChanged: (val) => setState(() => _selectedCategory = val!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(controller: _bioCtrl, label: 'Short Bio / Story', icon: Icons.auto_awesome, maxLines: 3, hint: 'Tell customers about your passion, ingredients, and process...'),

                    const SizedBox(height: 32),
                    _buildSectionTitle('3. Trust & Portfolio (Optional)'),
                    _buildTextField(controller: _instagramCtrl, label: 'Instagram Username', icon: Icons.camera_alt_outlined, hint: '@your_page'),
                    const SizedBox(height: 16),
                    _buildTextField(controller: _fssaiCtrl, label: 'FSSAI License (If food)', icon: Icons.verified_user_outlined),

                    const SizedBox(height: 32),
                    _buildSectionTitle('4. Upload Work Samples'),
                    const Text('Showcase up to 5 clear photos of your products.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ..._sampleImages.map((file) => Stack(
                          children: [
                            Container(
                              height: 90, width: 90,
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.purple[100]!)),
                              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: kIsWeb ? Image.network(file.path, fit: BoxFit.cover) : Image.file(File(file.path), fit: BoxFit.cover)),
                            ),
                            Positioned(top: -4, right: -4, child: GestureDetector(onTap: () => setState(() => _sampleImages.remove(file)), child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, color: Colors.white, size: 14)))),
                          ],
                        )),
                        if (_sampleImages.length < 5)
                          GestureDetector(
                            onTap: _pickImages,
                            child: Container(
                              height: 90, width: 90,
                              decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.purple[200]!, style: BorderStyle.solid)),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, color: Colors.purple[400]),
                                  const SizedBox(height: 4),
                                  Text('Add Photo', style: TextStyle(fontSize: 10, color: Colors.purple[700], fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          )
                      ],
                    ),

                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[700],
                          elevation: 4,
                          shadowColor: Colors.purple.withOpacity(0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: _isSubmitting ? null : _submitApplication,
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('SUBMIT APPLICATION', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, int maxLines = 1, TextInputType? keyboardType, String? hint}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        prefixIcon: maxLines == 1 ? Icon(icon, color: Colors.purple[300]) : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.purple[300]!, width: 2)),
      ),
      validator: (val) {
        if (label.contains('(Optional)')) return null;
        if (val == null || val.trim().isEmpty) return 'Please fill out this field';
        return null;
      },
    );
  }
}