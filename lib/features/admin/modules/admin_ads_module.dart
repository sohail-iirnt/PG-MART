import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class AdminAdsModule extends StatefulWidget {
  const AdminAdsModule({super.key});

  @override
  State<AdminAdsModule> createState() => _AdminAdsModuleState();
}

class _AdminAdsModuleState extends State<AdminAdsModule> {
  bool _isUploading = false;

  Future<void> _showAdDialog() async {
    final imageLinkController = TextEditingController();
    final actionLinkController = TextEditingController();
    String screenTarget = 'home'; // Default

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add Advertisement Banner'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NEW: TARGET SCREEN DROPDOWN
                  const Text('Where should this Ad display?', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: screenTarget,
                    decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), fillColor: Colors.purple[50], filled: true),
                    items: const [
                      DropdownMenuItem(value: 'home', child: Text('Main Home Screen')),
                      DropdownMenuItem(value: 'vocal_for_local', child: Text('Vocal for Local Hub')),
                    ],
                    onChanged: (val) => setDialogState(() => screenTarget = val ?? 'home'),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),

                  const Text('Option 1: Paste Image Link', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: imageLinkController,
                    decoration: InputDecoration(hintText: 'https://...', labelText: 'Banner Image URL', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 16),
                  const Center(child: Text('--- OR ---', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _uploadAdFromGallery(actionLinkController.text.trim(), screenTarget);
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload from Device Storage'),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                  const Text('Action Link (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Where should the user go if they click the ad?', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: actionLinkController,
                    decoration: InputDecoration(hintText: 'e.g., https://wa.me/...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple[800], foregroundColor: Colors.white),
                onPressed: () {
                  if (imageLinkController.text.trim().isNotEmpty) {
                    Navigator.pop(context);
                    _saveAdData(imageUrl: imageLinkController.text.trim(), actionUrl: actionLinkController.text.trim(), screenTarget: screenTarget);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an image URL or choose Upload.')));
                  }
                },
                child: const Text('SAVE IMAGE URL'),
              ),
            ],
          )
      ),
    );
  }

  Future<void> _uploadAdFromGallery(String actionUrl, String screenTarget) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final fileName = 'ad_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child('in_feed_ads/$fileName');
      final bytes = await pickedFile.readAsBytes();
      await storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await storageRef.getDownloadURL();
      await _saveAdData(imageUrl: downloadUrl, actionUrl: actionUrl, screenTarget: screenTarget);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
      setState(() => _isUploading = false);
    }
  }

  Future<void> _saveAdData({required String imageUrl, required String actionUrl, required String screenTarget}) async {
    setState(() => _isUploading = true);
    try {
      await FirebaseFirestore.instance.collection('in_feed_ads').add({
        'imageUrl': imageUrl,
        'actionUrl': actionUrl,
        'isActive': true,
        'screenTarget': screenTarget, // NEW: Saves target to DB
        'createdAt': FieldValue.serverTimestamp(),
        'clicks': 0,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad published successfully!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save ad: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _toggleAdStatus(String docId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('in_feed_ads').doc(docId).update({'isActive': !currentStatus});
  }

  Future<void> _deleteAd(String docId, String imageUrl) async {
    await FirebaseFirestore.instance.collection('in_feed_ads').doc(docId).delete();
    if (imageUrl.contains('firebasestorage.googleapis.com')) {
      try { await FirebaseStorage.instance.refFromURL(imageUrl).delete(); } catch (e) { debugPrint("Storage delete error: $e"); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('In-Feed Ads Manager'), backgroundColor: Colors.deepPurple[800], foregroundColor: Colors.white),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.deepPurple[800],
        onPressed: _isUploading ? null : _showAdDialog,
        icon: _isUploading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.add_photo_alternate, color: Colors.white),
        label: Text(_isUploading ? 'SAVING...' : 'ADD NEW AD', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('in_feed_ads').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No ads yet. Add one via link or upload.'));

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.8),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final isActive = data['isActive'] ?? false;
              final screenTarget = data['screenTarget'] ?? 'home';

              return Card(
                clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4,
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(data['imageUrl'], fit: BoxFit.cover, errorBuilder: (c,e,s) => const Center(child: Icon(Icons.broken_image, color: Colors.grey))),
                          if (!isActive) Container(color: Colors.black54, child: const Center(child: Text('PAUSED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)))),
                          if (screenTarget == 'vocal_for_local')
                            Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.purple[700], borderRadius: BorderRadius.circular(6)), child: const Text('LOCAL HUB', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))))
                        ],
                      ),
                    ),
                    Container(
                      color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Switch(value: isActive, activeColor: Colors.deepPurple, onChanged: (val) => _toggleAdStatus(doc.id, isActive)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteAd(doc.id, data['imageUrl']))
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}