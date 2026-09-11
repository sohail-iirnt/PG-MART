import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminLocalSellersModule extends StatefulWidget {
  const AdminLocalSellersModule({super.key});

  @override
  State<AdminLocalSellersModule> createState() => _AdminLocalSellersModuleState();
}

class _AdminLocalSellersModuleState extends State<AdminLocalSellersModule> {
  String _currentFilter = 'pending';

  Future<void> _updateStatus(String docId, String status) async {
    await FirebaseFirestore.instance.collection('local_sellers').doc(docId).update({'status': status});
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Seller marked as $status'), backgroundColor: status == 'approved' ? Colors.green : Colors.black));
  }

  Future<void> _toggleFeatured(String docId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('local_sellers').doc(docId).update({'isFeatured': !currentStatus});
  }

  Future<void> _launchPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse("tel:$cleanPhone");
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchInstagram(String instaId) async {
    String cleanId = instaId.trim();
    if (cleanId.startsWith('@')) cleanId = cleanId.substring(1);

    final Uri appUri = Uri.parse("instagram://user?username=$cleanId");
    final Uri webUri = Uri.parse("https://instagram.com/$cleanId");

    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
    } else if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Instagram')));
    }
  }

  // === NEW: FULL-SCREEN IMAGE VIEWER ===
  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('B1D Entrepreneurs', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        const Text('Review home creators, cakes bakers, and local artisans.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),

        StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('store_settings').doc('app_control').snapshots(),
            builder: (context, snapshot) {
              bool isVocalActive = false;
              if (snapshot.hasData && snapshot.data!.exists && snapshot.data!.data() != null) {
                isVocalActive = (snapshot.data!.data() as Map<String, dynamic>)['vocal_for_local_active'] ?? false;
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: isVocalActive ? Colors.purple[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isVocalActive ? Colors.purple[200]! : Colors.grey[300]!, width: 2)
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(isVocalActive ? Icons.power : Icons.power_off, color: isVocalActive ? Colors.purple[800] : Colors.grey[600], size: 20),
                              const SizedBox(width: 8),
                              Text('Master Kill-Switch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isVocalActive ? Colors.purple[900] : Colors.grey[800])),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                              isVocalActive ? 'The B1D Hub is currently LIVE in the user app.' : 'Feature is completely HIDDEN from users.',
                              style: TextStyle(color: isVocalActive ? Colors.purple[700] : Colors.grey, fontSize: 13)
                          ),
                        ],
                      ),
                    ),
                    Switch(
                        value: isVocalActive,
                        activeColor: Colors.purple,
                        onChanged: (val) {
                          FirebaseFirestore.instance.collection('store_settings').doc('app_control').set({
                            'vocal_for_local_active': val
                          }, SetOptions(merge: true));
                        }
                    )
                  ],
                ),
              );
            }
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              _buildTab('Pending', 'pending', Icons.hourglass_empty),
              _buildTab('Approved', 'approved', Icons.verified),
              _buildTab('Rejected', 'rejected', Icons.cancel),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('local_sellers')
                .where('status', isEqualTo: _currentFilter)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.storefront_outlined, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No $_currentFilter applications.', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final isFeatured = data['isFeatured'] ?? false;
                  final images = List<String>.from(data['sampleImages'] ?? []);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                        border: Border.all(color: Colors.grey[100]!)
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: Colors.purple[50],
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.purple[100]!)
                                ),
                                child: Icon(Icons.store, color: Colors.purple[700], size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text(data['brandName'] ?? 'Unknown Brand', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5))),
                                        if (_currentFilter == 'approved')
                                          GestureDetector(
                                            onTap: () => _toggleFeatured(doc.id, isFeatured),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(color: isFeatured ? Colors.amber[100] : Colors.grey[100], borderRadius: BorderRadius.circular(20), border: Border.all(color: isFeatured ? Colors.amber : Colors.transparent)),
                                              child: Row(
                                                children: [
                                                  Icon(isFeatured ? Icons.star : Icons.star_border, color: isFeatured ? Colors.amber[800] : Colors.grey, size: 14),
                                                  const SizedBox(width: 4),
                                                  Text(isFeatured ? 'Featured Maker' : 'Feature', style: TextStyle(color: isFeatured ? Colors.amber[800] : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          )
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('By ${data['creatorName']} • ${data['category']}', style: TextStyle(color: Colors.grey[700], fontSize: 14, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Expanded(child: Text('${data['area']}', style: TextStyle(color: Colors.grey[500], fontSize: 12))),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(),
                          ),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                            child: Text(data['bio'] ?? '', style: const TextStyle(height: 1.5, fontSize: 14, color: Colors.black87, fontStyle: FontStyle.italic)),
                          ),
                          const SizedBox(height: 16),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (data['fssaiNumber'] != null && data['fssaiNumber'].toString().isNotEmpty)
                                Chip(
                                    avatar: const Icon(Icons.verified_user, size: 16, color: Colors.green),
                                    label: Text('FSSAI: ${data['fssaiNumber']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    backgroundColor: Colors.green[50],
                                    side: BorderSide.none
                                ),
                              if (data['instagramId'] != null && data['instagramId'].toString().isNotEmpty)
                                ActionChip(
                                  avatar: const Icon(Icons.camera_alt, size: 16, color: Colors.pink),
                                  label: Text(data['instagramId'], style: const TextStyle(fontSize: 12, color: Colors.pink, fontWeight: FontWeight.bold)),
                                  backgroundColor: Colors.pink[50],
                                  side: BorderSide.none,
                                  onPressed: () => _launchInstagram(data['instagramId']),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          if (images.isNotEmpty) ...[
                            const Text('Uploaded Samples (Tap to Enlarge)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 90,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: images.length,
                                itemBuilder: (context, imgIndex) => GestureDetector(
                                  onTap: () => _showFullScreenImage(images[imgIndex]), // ZOOM FIX HERE
                                  child: Container(
                                    width: 90,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.purple[100]!),
                                        image: DecorationImage(image: NetworkImage(images[imgIndex]), fit: BoxFit.cover),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      side: BorderSide(color: Colors.purple[700]!)
                                  ),
                                  onPressed: () => _launchPhone(data['phone'] ?? ''),
                                  icon: Icon(Icons.call, size: 18, color: Colors.purple[700]),
                                  label: Text('CALL SELLER', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple[700])),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (_currentFilter == 'pending') ...[
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                    onPressed: () => _updateStatus(doc.id, 'rejected'),
                                    child: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                    onPressed: () => _updateStatus(doc.id, 'approved'),
                                    child: const Text('APPROVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                              if (_currentFilter == 'approved' || _currentFilter == 'rejected')
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200], foregroundColor: Colors.black87, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                    onPressed: () => _updateStatus(doc.id, 'pending'),
                                    child: const Text('MOVE TO PENDING', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
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
        ),
      ],
    );
  }

  Widget _buildTab(String title, String filterValue, IconData icon) {
    final isSelected = _currentFilter == filterValue;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentFilter = filterValue),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600]),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}