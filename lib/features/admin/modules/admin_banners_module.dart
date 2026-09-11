import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

// === THE LIVE BANNERS ENGINE ===
final adminBannersProvider = StreamProvider<QuerySnapshot>((ref) => FirebaseFirestore.instance.collection('banners').orderBy('createdAt', descending: true).snapshots());

class AdminBannersModule extends ConsumerStatefulWidget {
  final bool isDesktop;
  const AdminBannersModule({super.key, required this.isDesktop});

  @override
  ConsumerState<AdminBannersModule> createState() => _AdminBannersModuleState();
}

class _AdminBannersModuleState extends ConsumerState<AdminBannersModule> {
  Future<void> _toggleBannerStatus(String bannerId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('banners').doc(bannerId).update({'isActive': !currentStatus});
  }

  Future<void> _deleteBanner(String bannerId) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text('Delete Banner?'),
            content: const Text('Are you sure? This will remove the promotion from the user app instantly.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: Colors.white)))
            ]
        )
    );
    if (confirm == true) await FirebaseFirestore.instance.collection('banners').doc(bannerId).delete();
  }

  void _showBannerDialog({String? bannerId, Map<String, dynamic>? existingData}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BannerEditorDialog(
        bannerId: bannerId,
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
              if (widget.isDesktop) const Text('Manage Home Screen promotional carousels & banners', style: TextStyle(color: Colors.grey, fontSize: 16)) else const Text('Banners', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                  icon: const Icon(Icons.add_photo_alternate, color: Colors.white, size: 18),
                  label: Text(widget.isDesktop ? 'ADD NEW BANNER' : 'ADD', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _showBannerDialog()
              )
            ]
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Consumer(builder: (context, ref, child) {
            final bannersAsync = ref.watch(adminBannersProvider);
            return bannersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, stack) => Center(child: Text('Error: $e')),
              data: (snapshot) {
                if (snapshot.docs.isEmpty) return const Center(child: Text('No banners active. Add a promotion to boost sales!'));
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: widget.isDesktop ? 3 : 1,
                      childAspectRatio: widget.isDesktop ? 1.6 : 2.0,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16
                  ),
                  itemCount: snapshot.docs.length,
                  itemBuilder: (context, index) {
                    final bannerData = snapshot.docs[index].data() as Map<String, dynamic>;
                    final bannerId = snapshot.docs[index].id;
                    final isActive = bannerData['isActive'] ?? true;
                    final position = bannerData['positionIndex'] ?? 0;
                    final screenTarget = bannerData['screenTarget'] ?? 'home';

                    String positionLabel = 'TOP CAROUSEL';
                    if (position == 1) positionLabel = 'MIDDLE FEED';
                    if (position == 2) positionLabel = 'LOWER FEED';

                    String targetLabel = screenTarget == 'vocal_for_local' ? 'LOCAL HUB' : 'MAIN HOME';

                    return Card(
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isActive ? Colors.transparent : Colors.red, width: 2)),
                        child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.network(
                                    bannerData['imageUrl'] ?? '',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey, size: 40))
                                ),
                              ),
                              Positioned(
                                  bottom: 0, left: 0, right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.9), Colors.transparent])
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(bannerData['title'] ?? 'Untitled Promo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              Text('Screen: $targetLabel | Pos: $positionLabel', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
                                            ],
                                          ),
                                        ),
                                        Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Switch(value: isActive, activeColor: Colors.green, onChanged: (val) => _toggleBannerStatus(bannerId, isActive)),
                                              IconButton(icon: const Icon(Icons.edit, color: Colors.white, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _showBannerDialog(bannerId: bannerId, existingData: bannerData)),
                                              const SizedBox(width: 12),
                                              IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _deleteBanner(bannerId))
                                            ]
                                        )
                                      ],
                                    ),
                                  )
                              ),
                              Positioned(
                                  top: 8, left: 8,
                                  child: Row(
                                    children: [
                                      Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: isActive ? Colors.green : Colors.red, borderRadius: BorderRadius.circular(6)),
                                          child: Text(isActive ? 'LIVE' : 'HIDDEN', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
                                      ),
                                      if (screenTarget == 'vocal_for_local') ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.purple[700], borderRadius: BorderRadius.circular(6)),
                                          child: const Icon(Icons.storefront, color: Colors.white, size: 12),
                                        ),
                                      ]
                                    ],
                                  )
                              )
                            ]
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

class _BannerEditorDialog extends StatefulWidget {
  final String? bannerId;
  final Map<String, dynamic>? existingData;
  final bool isDesktop;

  const _BannerEditorDialog({this.bannerId, this.existingData, required this.isDesktop});

  @override
  State<_BannerEditorDialog> createState() => _BannerEditorDialogState();
}

class _BannerEditorDialogState extends State<_BannerEditorDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _imageCtrl;
  late TextEditingController _actionTargetCtrl;
  bool _isActive = true;
  bool _isActionable = false;
  int _positionIndex = 0;
  String _actionType = 'category';
  String _screenTarget = 'home';
  bool _isSaving = false;
  XFile? _localImage;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existingData?['title'] ?? '');
    _imageCtrl = TextEditingController(text: widget.existingData?['imageUrl'] ?? '');
    _actionTargetCtrl = TextEditingController(text: widget.existingData?['actionTarget'] ?? '');
    _isActive = widget.existingData?['isActive'] ?? true;
    _isActionable = widget.existingData?['isActionable'] ?? false;
    _positionIndex = widget.existingData?['positionIndex'] ?? 0;

    // SAFETY CATCH ON INIT (Added 'screen' for in-app routing)
    String savedAction = widget.existingData?['actionType'] ?? 'category';
    if (!['category', 'tag', 'product', 'link', 'screen'].contains(savedAction)) {
      savedAction = 'category';
    }
    _actionType = savedAction;
    _screenTarget = widget.existingData?['screenTarget'] ?? 'home';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _imageCtrl.dispose();
    _actionTargetCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _localImage = pickedFile;
        _imageCtrl.clear();
      });
    }
  }

  Widget _buildImagePreview() {
    if (_localImage != null) {
      return Container(
        height: 120, width: double.infinity,
        decoration: BoxDecoration(border: Border.all(color: Colors.blue[300]!, width: 2), borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            kIsWeb ? Image.network(_localImage!.path, fit: BoxFit.cover) : Image.file(File(_localImage!.path), fit: BoxFit.cover),
            Positioned(top: 4, right: 4, child: GestureDetector(onTap: () => setState(() => _localImage = null), child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, color: Colors.white, size: 14))))
          ],
        ),
      );
    } else if (_imageCtrl.text.isNotEmpty) {
      return Container(
        height: 120, width: double.infinity,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: Image.network(_imageCtrl.text, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Center(child: Text('Invalid Image URL'))),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _saveBanner() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a Banner Title')));
      return;
    }
    if (_imageCtrl.text.trim().isEmpty && _localImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide an Image URL or Upload a file')));
      return;
    }
    if (_isActionable && _actionTargetCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action target cannot be empty if banner is actionable!')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      String finalUrl = _imageCtrl.text.trim();
      if (_localImage != null) {
        final fileName = 'banner_${DateTime.now().millisecondsSinceEpoch}_${_localImage!.name}';
        final ref = FirebaseStorage.instance.ref().child('banners/$fileName');
        String mimeType = 'image/jpeg';
        if (fileName.toLowerCase().endsWith('.gif')) mimeType = 'image/gif';
        else if (fileName.toLowerCase().endsWith('.png')) mimeType = 'image/png';
        await ref.putData(await _localImage!.readAsBytes(), SettableMetadata(contentType: mimeType));
        finalUrl = await ref.getDownloadURL();
      }

      final bannerData = {
        'title': _titleCtrl.text.trim(),
        'imageUrl': finalUrl,
        'isActive': _isActive,
        'positionIndex': _positionIndex,
        'screenTarget': _screenTarget,
        'isActionable': _isActionable,
        'actionType': _isActionable ? _actionType : 'none',
        'actionTarget': _isActionable ? _actionTargetCtrl.text.trim() : '',
        'updatedAt': FieldValue.serverTimestamp()
      };

      if (widget.bannerId != null) {
        await FirebaseFirestore.instance.collection('banners').doc(widget.bannerId).update(bannerData);
      } else {
        bannerData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('banners').add(bannerData);
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
      title: Text(widget.bannerId != null ? 'Edit Promotional Banner' : 'Add New Banner', style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Container(
        // FIX: Added safe constraints to prevent layout overflow on smaller devices
          constraints: BoxConstraints(maxWidth: widget.isDesktop ? 500 : MediaQuery.of(context).size.width * 0.9),
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Banner Title (e.g. Diwali Sale 50% Off)', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  _buildImagePreview(),
                  if (_localImage != null || _imageCtrl.text.isNotEmpty) const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.upload_file), label: const Text('Upload Photo / GIF'))),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: Text('OR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)))),
                  TextField(controller: _imageCtrl, onChanged: (val) => setState((){}), decoration: const InputDecoration(labelText: 'Paste Image/GIF URL directly', border: OutlineInputBorder())),
                  const Divider(height: 32),
                  const Text('Banner Layout Rules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    isExpanded: true, // FIX: Prevents internal text overflow
                    value: _screenTarget,
                    decoration: const InputDecoration(labelText: 'Target Screen', border: OutlineInputBorder(), fillColor: Color(0xFFF3E5F5), filled: true),
                    items: const [
                      DropdownMenuItem(value: 'home', child: Text('Main Home Screen')),
                      DropdownMenuItem(value: 'vocal_for_local', child: Text('Vocal for Local Hub')),
                    ],
                    onChanged: (val) => setState(() => _screenTarget = val ?? 'home'),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<int>(
                    isExpanded: true, // FIX: Prevents internal text overflow
                    value: _positionIndex,
                    decoration: const InputDecoration(labelText: 'Where should this banner show?', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('0: Top Carousel (Sliding Header)')),
                      DropdownMenuItem(value: 1, child: Text('1: Middle Feed (Below Categories)')),
                      DropdownMenuItem(value: 2, child: Text('2: Lower Feed (Deep in products)')),
                    ],
                    onChanged: (val) => setState(() => _positionIndex = val ?? 0),
                  ),
                  const SizedBox(height: 16),

                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // FIX: Wrapped text in Expanded to prevent pushing the switch off-screen
                                const Expanded(child: Text('Clickable Action Banner', style: TextStyle(fontWeight: FontWeight.w500))),
                                Switch(
                                    value: _isActionable,
                                    activeColor: Theme.of(context).primaryColor,
                                    onChanged: (val) {
                                      setState(() {
                                        _isActionable = val;
                                        // Update safety catch to include 'screen'
                                        if (val && !['category', 'tag', 'product', 'link', 'screen'].contains(_actionType)) {
                                          _actionType = 'category';
                                        }
                                      });
                                    }
                                )
                              ]
                          ),
                          if (_isActionable) ...[
                            const Divider(),
                            DropdownButtonFormField<String>(
                              isExpanded: true, // FIX: Prevents internal text overflow
                              value: _actionType,
                              decoration: const InputDecoration(labelText: 'When clicked, open:', border: InputBorder.none),
                              items: const [
                                DropdownMenuItem(value: 'category', child: Text('Full Category (e.g. Dry Fruits)')),
                                DropdownMenuItem(value: 'tag', child: Text('Custom Search Tag (e.g. bachat_bazar)')),
                                DropdownMenuItem(value: 'product', child: Text('Specific Product ID')),
                                DropdownMenuItem(value: 'link', child: Text('External Website URL')),
                                // === NEW: IN-APP SCREEN ROUTING ===
                                DropdownMenuItem(value: 'screen', child: Text('In-App Screen (e.g. Local Hub, Cart)')),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _actionType = val ?? 'category';
                                  if (_actionType == 'screen') {
                                    _actionTargetCtrl.text = 'local_hub';
                                  } else {
                                    _actionTargetCtrl.text = '';
                                  }
                                });
                              },
                            ),

                            // === UPDATED: ADDED HOME AND APP SECTIONS ===
                            if (_actionType == 'screen')
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                value: ['home_tab', 'categories_tab', 'offers_tab', 'local_hub', 'cart', 'orders', 'support'].contains(_actionTargetCtrl.text) ? _actionTargetCtrl.text : 'home_tab',
                                decoration: InputDecoration(labelText: 'Select Target Screen/Section', border: const OutlineInputBorder(), filled: true, fillColor: Colors.blue[50]),
                                items: const [
                                  DropdownMenuItem(value: 'home_tab', child: Text('Section: Main Home Feed')),
                                  DropdownMenuItem(value: 'categories_tab', child: Text('Section: Categories Tab')),
                                  DropdownMenuItem(value: 'offers_tab', child: Text('Section: Offers & Promos Tab')),
                                  DropdownMenuItem(value: 'local_hub', child: Text('Screen: B1D Entrepreneurs Hub')),
                                  DropdownMenuItem(value: 'cart', child: Text('Screen: Shopping Cart')),
                                  DropdownMenuItem(value: 'orders', child: Text('Screen: My Orders')),
                                  DropdownMenuItem(value: 'support', child: Text('Screen: Customer Support')),
                                ],
                                onChanged: (val) => setState(() => _actionTargetCtrl.text = val ?? 'home_tab'),
                              )
                            else
                              TextField(
                                  controller: _actionTargetCtrl,
                                  decoration: InputDecoration(
                                      labelText: _actionType == 'category' ? 'Category Name' : (_actionType == 'product' ? 'Product Document ID' : 'Target URL / Tag string'),
                                      border: const OutlineInputBorder(),
                                      filled: true, fillColor: Colors.blue[50]
                                  )
                              )
                          ]
                        ],
                      )
                  ),
                  const SizedBox(height: 16),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // FIX: Wrapped text in Expanded to prevent pushing the switch off-screen
                            const Expanded(child: Text('Active (Visible on Home Screen)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                            Switch(value: _isActive, activeColor: Colors.green, onChanged: (val) => setState(() => _isActive = val))
                          ]
                      )
                  )
                ]
            ),
          )
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            onPressed: _isSaving ? null : _saveBanner,
            child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : Text(widget.bannerId != null ? 'UPDATE' : 'PUBLISH', style: const TextStyle(color: Colors.white))
        ),
      ],
    );
  }
}