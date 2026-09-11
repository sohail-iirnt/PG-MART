import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

final adminProductsProvider = StreamProvider<QuerySnapshot>((ref) =>
    FirebaseFirestore.instance.collection('products').orderBy('createdAt', descending: true).snapshots());

class AdminInventoryModule extends ConsumerStatefulWidget {
  final bool isDesktop;
  const AdminInventoryModule({super.key, required this.isDesktop});

  @override
  ConsumerState<AdminInventoryModule> createState() => _AdminInventoryModuleState();
}

class _AdminInventoryModuleState extends ConsumerState<AdminInventoryModule> {
  Future<void> _toggleProductAvailability(String productId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('products').doc(productId).update({'isAvailable': !currentStatus});
  }

  Future<void> _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text('Delete Product?'),
            content: const Text('Are you sure?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('DELETE'))
            ]
        )
    );
    if (confirm == true) await FirebaseFirestore.instance.collection('products').doc(productId).delete();
  }

  void _showProductDialog({String? productId, Map<String, dynamic>? existingData}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ProductEditorDialog(
        productId: productId,
        existingData: existingData,
        isDesktop: widget.isDesktop,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.isDesktop) const Text('Manage catalog & stock', style: TextStyle(color: Colors.grey, fontSize: 16)) else const Text('Live Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: Text(widget.isDesktop ? 'ADD NEW PRODUCT' : 'ADD', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _showProductDialog()
              )
            ]
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Consumer(builder: (context, ref, child) {
            final productsAsync = ref.watch(adminProductsProvider);
            return productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, stack) => Center(child: Text('Error: $e')),
              data: (snapshot) {
                if (snapshot.docs.isEmpty) return const Center(child: Text('No products in database. Add one above!'));
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: widget.isDesktop ? 4 : 2,
                      childAspectRatio: widget.isDesktop ? 0.75 : 0.65,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12
                  ),
                  itemCount: snapshot.docs.length,
                  itemBuilder: (context, index) {
                    final prod = snapshot.docs[index].data() as Map<String, dynamic>;
                    final productId = snapshot.docs[index].id;
                    final isAvailable = prod['isAvailable'] ?? true;

                    String displayImage = '';
                    if (prod['imageUrls'] != null && (prod['imageUrls'] as List).isNotEmpty) {
                      displayImage = prod['imageUrls'][0];
                    } else if (prod['imageUrl'] != null) {
                      displayImage = prod['imageUrl'];
                    }

                    // VOCAL FOR LOCAL BADGE ON ADMIN SIDE
                    final isLocal = (prod['visibilityScope'] == 'local' || prod['visibilityScope'] == 'both');

                    return Card(clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(displayImage, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200], child: const Icon(Icons.image_not_supported))),
                              Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), decoration: BoxDecoration(color: isAvailable ? Colors.green : Colors.red, borderRadius: BorderRadius.circular(6)), child: Text(isAvailable ? 'IN STOCK' : 'OUT', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)))),
                              if (isLocal)
                                Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), decoration: BoxDecoration(color: Colors.purple[700], borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.storefront, color: Colors.white, size: 14))),
                            ]
                        ),
                      ),
                      Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(prod['name'] ?? 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        if(prod['sellerName'] != null && prod['sellerName'].toString().isNotEmpty)
                          Text(prod['sellerName'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 10, color: Colors.purple[700])),
                        Text('₹ ${prod['price']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.green)),
                        if(prod['hasVariants'] == true)
                          const Text('Multiple Variants', style: TextStyle(fontSize: 10, color: Colors.blue)),
                        const Divider(height: 8),
                        FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Switch(value: isAvailable, activeColor: Colors.green, onChanged: (val) => _toggleProductAvailability(productId, isAvailable)),
                                  Row(
                                      children: [
                                        IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20), onPressed: () => _showProductDialog(productId: productId, existingData: prod)),
                                        const SizedBox(width: 8),
                                        IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _deleteProduct(productId))
                                      ]
                                  )
                                ]
                            )
                        )
                      ]))]));
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

class _ProductEditorDialog extends StatefulWidget {
  final String? productId;
  final Map<String, dynamic>? existingData;
  final bool isDesktop;

  const _ProductEditorDialog({this.productId, this.existingData, required this.isDesktop});

  @override
  State<_ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<_ProductEditorDialog> {
  final _nameCtrl = TextEditingController();
  final _baseVariantNameCtrl = TextEditingController();
  final _originalPriceCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _keywordsCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _newCategoryCtrl = TextEditingController();

  // === NEW: VOCAL FOR LOCAL CONTROLLERS ===
  String _visibilityScope = 'both';
  final _sellerNameCtrl = TextEditingController();

  List<String> _categories = [];
  String? _selectedCategory;
  bool _isNewCategory = false;
  List<String> _existingImageUrls = [];
  final List<XFile> _localMainImages = [];
  bool _enableVariants = false;
  List<Map<String, dynamic>> _variants = [];
  String _listPlacement = 'Top of List';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _loadExistingData();
  }

  void _loadExistingData() {
    if (widget.existingData != null) {
      final data = widget.existingData!;
      _nameCtrl.text = data['name'] ?? '';
      _baseVariantNameCtrl.text = data['baseVariantName'] ?? '';
      _originalPriceCtrl.text = data['originalPrice']?.toString() ?? '';
      _priceCtrl.text = data['price']?.toString() ?? '';
      _keywordsCtrl.text = data['keywords'] ?? '';
      _descCtrl.text = data['description'] ?? '';

      // === NEW: LOAD VOCAL FOR LOCAL DATA ===
      _visibilityScope = data['visibilityScope'] ?? 'both';
      _sellerNameCtrl.text = data['sellerName'] ?? '';

      _existingImageUrls = List<String>.from(data['imageUrls'] ?? []);
      if (_existingImageUrls.isEmpty && data['imageUrl'] != null) {
        _existingImageUrls.add(data['imageUrl']);
      }
      _enableVariants = data['hasVariants'] ?? false;
      _variants = List<Map<String, dynamic>>.from(data['variants'] ?? []).map((v) {
        List<String> varImages = List<String>.from(v['imageUrls'] ?? []);
        if (varImages.isEmpty && v['imageUrl'] != null) varImages.add(v['imageUrl']);
        return {
          'name': v['name'] ?? '',
          'price': v['price'] ?? 0.0,
          'originalPrice': v['originalPrice'] ?? 0.0,
          'imageUrls': varImages,
          'localFiles': <XFile>[],
        };
      }).toList();
      _selectedCategory = data['category'];
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('categories').get();
      final Set<String> uniqueCats = snap.docs.map((d) => (d.data()['name'] as String).trim()).toSet();
      setState(() {
        _categories = uniqueCats.toList();
        if (_selectedCategory != null && !_categories.contains(_selectedCategory)) {
          _categories.add(_selectedCategory!);
        }
      });
    } catch (e) {
      debugPrint('Failed to load categories: $e');
    }
  }

  Future<void> _pickMainImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 70);
    if (pickedFiles.isNotEmpty) setState(() => _localMainImages.addAll(pickedFiles));
  }

  void _showImageUrlPrompt({int? variantIndex}) {
    final urlCtrl = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Add Image URL'),
          content: TextField(controller: urlCtrl, decoration: const InputDecoration(hintText: 'https://...')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
            ElevatedButton(onPressed: () {
              if (urlCtrl.text.isNotEmpty) {
                setState(() {
                  if (variantIndex != null) _variants[variantIndex]['imageUrls'].add(urlCtrl.text.trim());
                  else _existingImageUrls.add(urlCtrl.text.trim());
                });
                Navigator.pop(ctx);
              }
            }, child: const Text('ADD')),
          ],
        )
    );
  }

  Widget _buildLocalImagePreview(XFile file) {
    if (kIsWeb) return Image.network(file.path, fit: BoxFit.cover);
    return Image.file(File(file.path), fit: BoxFit.cover);
  }

  Future<void> _saveProduct() async {
    if (_nameCtrl.text.isEmpty || (_existingImageUrls.isEmpty && _localMainImages.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and at least 1 Main Image are required.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      for (var file in _localMainImages) {
        final fileName = 'prod_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final ref = FirebaseStorage.instance.ref().child('product_images/$fileName');
        await ref.putData(await file.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
        _existingImageUrls.add(await ref.getDownloadURL());
      }
      _localMainImages.clear();

      for (var variant in _variants) {
        if (variant['localFiles'] != null && (variant['localFiles'] as List).isNotEmpty) {
          for (XFile file in variant['localFiles']) {
            final fileName = 'var_${DateTime.now().millisecondsSinceEpoch}_${file.name}';
            final ref = FirebaseStorage.instance.ref().child('product_images/$fileName');
            await ref.putData(await file.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
            variant['imageUrls'].add(await ref.getDownloadURL());
          }
          variant['localFiles'].clear();
        }
        variant.remove('localFiles');
      }

      String finalCategory = _selectedCategory ?? 'Uncategorized';
      if (_isNewCategory && _newCategoryCtrl.text.trim().isNotEmpty) {
        finalCategory = _newCategoryCtrl.text.trim();
        await FirebaseFirestore.instance.collection('categories').add({
          'name': finalCategory,
          'imageUrl': _existingImageUrls.first,
          'isActive': true,
          'sortOrder': 99,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      final productData = {
        'name': _nameCtrl.text.trim(),
        'baseVariantName': _baseVariantNameCtrl.text.trim().isEmpty ? 'Main Pack' : _baseVariantNameCtrl.text.trim(),
        'category': finalCategory,
        'originalPrice': double.tryParse(_originalPriceCtrl.text) ?? 0.0,
        'price': double.tryParse(_priceCtrl.text) ?? 0.0,
        'imageUrl': _existingImageUrls.first,
        'imageUrls': _existingImageUrls,
        'description': _descCtrl.text.trim(),
        'keywords': _keywordsCtrl.text.trim().toLowerCase(),
        'hasVariants': _enableVariants,
        'variants': _enableVariants ? _variants : [],

        // === NEW: SAVE VOCAL FOR LOCAL DATA ===
        'visibilityScope': _visibilityScope,
        'sellerName': _sellerNameCtrl.text.trim().isEmpty ? null : _sellerNameCtrl.text.trim(),

        'updatedAt': FieldValue.serverTimestamp()
      };

      if (widget.productId != null) {
        if (_listPlacement == 'Bottom of List') productData['createdAt'] = Timestamp.fromDate(DateTime(2000, 1, 1));
        await FirebaseFirestore.instance.collection('products').doc(widget.productId).update(productData);
      } else {
        productData['isAvailable'] = true;
        productData['createdAt'] = _listPlacement == 'Bottom of List' ? Timestamp.fromDate(DateTime(2000, 1, 1)) : FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('products').add(productData);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.productId != null ? 'Edit Product' : 'Add New Product', style: const TextStyle(fontWeight: FontWeight.bold)),
      insetPadding: const EdgeInsets.all(16),
      content: SizedBox(
          width: widget.isDesktop ? 650 : MediaQuery.of(context).size.width,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- CARD 1: VOCAL FOR LOCAL SETUP ---
                Card(
                  elevation: 0,
                  color: Colors.purple[50],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.purple[100]!)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.storefront, color: Colors.purple[700]),
                            const SizedBox(width: 8),
                            const Text('Vocal for Local Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _visibilityScope,
                          decoration: const InputDecoration(labelText: 'Where should this item show?', border: OutlineInputBorder(), fillColor: Colors.white, filled: true),
                          items: const [
                            DropdownMenuItem(value: 'both', child: Text('Both (Main App & Local Hub)')),
                            DropdownMenuItem(value: 'main', child: Text('Main App Only (Standard Grocery)')),
                            DropdownMenuItem(value: 'local', child: Text('Local Hub Only (Exclusive Items)')),
                          ],
                          onChanged: (val) => setState(() => _visibilityScope = val!),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _sellerNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Maker/Seller Name (Optional)',
                            hintText: 'e.g. Handmade by Shabana',
                            border: OutlineInputBorder(),
                            fillColor: Colors.white,
                            filled: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // --- CARD 2: BASIC INFO ---
                TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Product Name', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(controller: _baseVariantNameCtrl, decoration: const InputDecoration(labelText: 'Base Unit Name (e.g. 1 Kg, 500g)', hintText: 'Defaults to Main Pack if empty', border: OutlineInputBorder())),
                const SizedBox(height: 16),

                // CATEGORY SETUP
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _isNewCategory
                          ? TextField(controller: _newCategoryCtrl, decoration: const InputDecoration(labelText: 'New Category Name', border: OutlineInputBorder()))
                          : DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) => setState(() => _selectedCategory = val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() {
                        _isNewCategory = !_isNewCategory;
                        if (!_isNewCategory) _newCategoryCtrl.clear();
                      }),
                      child: Text(_isNewCategory ? 'Use Existing' : 'Create New'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // PRICING
                Row(
                  children: [
                    Expanded(child: TextField(controller: _originalPriceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'MRP (₹)', border: OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling Price (₹)', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 16),

                // IMAGES
                const Text('Product Images', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._existingImageUrls.map((url) => Stack(
                      children: [
                        Container(height: 80, width: 80, decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, fit: BoxFit.cover))),
                        Positioned(right: 0, top: 0, child: GestureDetector(onTap: () => setState(() => _existingImageUrls.remove(url)), child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)))),
                      ],
                    )),
                    ..._localMainImages.map((file) => Stack(
                      children: [
                        Container(height: 80, width: 80, decoration: BoxDecoration(border: Border.all(color: Colors.blue[300]!), borderRadius: BorderRadius.circular(8)), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: _buildLocalImagePreview(file))),
                        Positioned(right: 0, top: 0, child: GestureDetector(onTap: () => setState(() => _localMainImages.remove(file)), child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)))),
                      ],
                    )),
                    GestureDetector(
                      onTap: _pickMainImages,
                      child: Container(height: 80, width: 80, decoration: BoxDecoration(color: Colors.grey[100], border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.add_photo_alternate, color: Colors.grey)),
                    ),
                    GestureDetector(
                      onTap: () => _showImageUrlPrompt(),
                      child: Container(height: 80, width: 80, decoration: BoxDecoration(color: Colors.grey[100], border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.link, color: Colors.grey)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // DESC & KEYWORDS
                TextField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(controller: _keywordsCtrl, decoration: const InputDecoration(labelText: 'Search Keywords (comma separated)', border: OutlineInputBorder())),
                const SizedBox(height: 24),

                // VARIANTS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Enable Size/Weight Variants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Switch(value: _enableVariants, activeColor: Theme.of(context).primaryColor, onChanged: (val) => setState(() => _enableVariants = val)),
                  ],
                ),
                if (_enableVariants) ...[
                  const SizedBox(height: 8),
                  ..._variants.asMap().entries.map((entry) {
                    int idx = entry.key;
                    var v = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Variant ${idx + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _variants.removeAt(idx))),
                              ],
                            ),
                            TextField(onChanged: (val) => v['name'] = val, controller: TextEditingController(text: v['name']), decoration: const InputDecoration(labelText: 'Variant Name (e.g. 5 Kg)', filled: true, fillColor: Colors.white, border: OutlineInputBorder())),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: TextField(onChanged: (val) => v['originalPrice'] = double.tryParse(val) ?? 0.0, controller: TextEditingController(text: v['originalPrice']?.toString()), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'MRP (₹)', filled: true, fillColor: Colors.white, border: OutlineInputBorder()))),
                                const SizedBox(width: 8),
                                Expanded(child: TextField(onChanged: (val) => v['price'] = double.tryParse(val) ?? 0.0, controller: TextEditingController(text: v['price']?.toString()), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling Price (₹)', filled: true, fillColor: Colors.white, border: OutlineInputBorder()))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  TextButton.icon(onPressed: () => setState(() => _variants.add({'name': '', 'price': 0.0, 'originalPrice': 0.0, 'imageUrls': [], 'localFiles': <XFile>[]})), icon: const Icon(Icons.add), label: const Text('Add Variant')),
                ],
                const SizedBox(height: 24),

                // PLACEMENT
                if (widget.productId == null)
                  DropdownButtonFormField<String>(
                    value: _listPlacement,
                    decoration: const InputDecoration(labelText: 'List Placement', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Top of List', child: Text('Top of List (New Arrival)')),
                      DropdownMenuItem(value: 'Bottom of List', child: Text('Bottom of List (Older Stock)')),
                    ],
                    onChanged: (val) => setState(() => _listPlacement = val!),
                  ),
              ],
            ),
          )
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            onPressed: _isSaving ? null : _saveProduct,
            child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : Text(widget.productId != null ? 'UPDATE' : 'SAVE', style: const TextStyle(color: Colors.white))
        ),
      ],
    );
  }
}