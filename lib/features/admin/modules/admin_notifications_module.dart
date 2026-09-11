import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../home/providers/products_provider.dart';

final adminNotificationsProvider = StreamProvider<QuerySnapshot>((ref) =>
    FirebaseFirestore.instance.collection('notifications').orderBy('createdAt', descending: true).snapshots());

class AdminNotificationsModule extends ConsumerStatefulWidget {
  final bool isDesktop;
  const AdminNotificationsModule({super.key, required this.isDesktop});

  @override
  ConsumerState<AdminNotificationsModule> createState() => _AdminNotificationsModuleState();
}

class _AdminNotificationsModuleState extends ConsumerState<AdminNotificationsModule> {
  // Service Account configuration
  final Map<String, dynamic> _serviceAccountJson = {
    /*Hidden*/
  };

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} at ${date.hour > 12 ? date.hour - 12 : date.hour}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  // === CORE DISPATCH ENGINE ===
  Future<void> _executeBroadcast({
    required String title,
    required String body,
    required String type,
    required String linkType,
    required String linkTarget,
    String? imageUrl,
  }) async {
    // 1. Save to Admin Global History
    final adminDoc = await FirebaseFirestore.instance.collection('notifications').add({
      'title': title,
      'body': body,
      'type': type,
      'imageUrl': imageUrl,
      'linkType': linkType,
      'linkTarget': linkTarget,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final broadcastId = adminDoc.id;
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();

    // 2. Setup Authenticated FCM Client
    final scopes = ["https://www.googleapis.com/auth/firebase.messaging"];
    final client = await clientViaServiceAccount(ServiceAccountCredentials.fromJson(_serviceAccountJson), scopes);
    final String projectId = _serviceAccountJson['project_id']!;
    final Uri url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

    // 3. Fast Parallel Dispatch to EVERY Token
    final List<Future> sendTasks = [];

    for (var doc in usersSnapshot.docs) {
      // In-app bell record
      sendTasks.add(
        doc.reference.collection('notifications').add({
          'title': title,
          'body': body,
          'type': type,
          'imageUrl': imageUrl,
          'linkType': linkType,
          'linkTarget': linkTarget,
          'createdAt': FieldValue.serverTimestamp(),
          'broadcastId': broadcastId,
          'isRead': false,
        }).catchError((e) => null),
      );

      // Hardware FCM Push
      final fcmToken = doc.data()['fcmToken'];
      if (fcmToken != null && fcmToken.toString().isNotEmpty) {
        final payload = {
          'message': {
            'token': fcmToken,
            'notification': {
              'title': title,
              'body': body,
              if (imageUrl != null && imageUrl.isNotEmpty) 'image': imageUrl,
            },
            'android': {
              'priority': 'high',
              'notification': {
                'channel_id': 'high_importance_channel',
                'sound': 'default',
                if (imageUrl != null && imageUrl.isNotEmpty) 'image': imageUrl,
              }
            },
            'data': {
              'linkType': linkType,
              'linkTarget': linkTarget,
            }
          }
        };

        sendTasks.add(
          client.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          ).catchError((e) => http.Response('error', 500)),
        );
      }
    }

    await Future.wait(sendTasks);
    client.close();
  }

  // === RESEND FUNCTIONALITY ===
  Future<void> _resendNotification(Map<String, dynamic> data) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Broadcasting notification again...')));

    try {
      await _executeBroadcast(
        title: data['title'] ?? '',
        body: data['body'] ?? '',
        type: data['type'] ?? 'Alert',
        linkType: data['linkType'] ?? 'None',
        linkTarget: data['linkTarget'] ?? '',
        imageUrl: data['imageUrl'],
      );
      messenger.showSnackBar(const SnackBar(content: Text('Resent successfully!'), backgroundColor: Colors.green));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // === DELETE EVERYWHERE ===
  Future<void> _deleteNotification(String notifId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Everywhere?'),
        content: const Text('This removes the notification from admin history and all user inboxes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );

    if (confirm == true) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(const SnackBar(content: Text('Deleting from all devices...')));

      await FirebaseFirestore.instance.collection('notifications').doc(notifId).delete();
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      for (var userDoc in usersSnapshot.docs) {
        final userNotifs = await userDoc.reference.collection('notifications').where('broadcastId', isEqualTo: notifId).get();
        for (var doc in userNotifs.docs) {
          await doc.reference.delete();
        }
      }
      messenger.showSnackBar(const SnackBar(content: Text('Deleted successfully!'), backgroundColor: Colors.green));
    }
  }

  // === SEND / EDIT DIALOG ===
  void _openNotificationDialog({Map<String, dynamic>? initialData}) {
    final titleCtrl = TextEditingController(text: initialData?['title'] ?? '');
    final messageCtrl = TextEditingController(text: initialData?['body'] ?? '');
    String selectedType = initialData?['type'] ?? 'Offer';

    // Default to 'None'
    String selectedLinkType = initialData?['linkType'] ?? 'None';
    String selectedLinkTarget = initialData?['linkTarget'] ?? '';
    final linkTargetCtrl = TextEditingController(text: selectedLinkTarget);

    String? existingImageUrl = initialData?['imageUrl'];
    File? newImageFile;

    // 0 = Normal Notification, 1 = Rich Notification
    int selectedMode = (existingImageUrl != null && existingImageUrl.isNotEmpty) || (selectedLinkType != 'None') ? 1 : 0;
    bool isSaving = false;

    final productsState = ref.read(paginatedProductsProvider);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              initialData != null ? 'Edit & Resend Notification' : 'Create Notification',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: widget.isDesktop ? 520 : double.maxFinite,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mode Selector (Normal vs Rich)
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Normal (Text Only)')),
                            selected: selectedMode == 0,
                            onSelected: (val) => setDialogState(() => selectedMode = 0),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Rich (Image + Link)')),
                            selected: selectedMode == 1,
                            onSelected: (val) => setDialogState(() => selectedMode = 1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Notification Title', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Message Body', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Category Type'),
                      items: ['Offer', 'Update', 'Alert'].map((String type) {
                        return DropdownMenuItem<String>(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (val) => setDialogState(() => selectedType = val!),
                    ),

                    // Rich options shown only when Rich mode is selected
                    if (selectedMode == 1) ...[
                      const SizedBox(height: 16),
                      const Text('Routing Action (Deep Link)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),

                      // 1. SELECT LINK TYPE
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Link To...'),
                        value: selectedLinkType,
                        items: ['None', 'Product', 'Category', 'Section', 'Page'].map((String val) {
                          return DropdownMenuItem(value: val, child: Text(val));
                        }).toList(),
                        onChanged: (val) => setDialogState(() {
                          selectedLinkType = val!;
                          selectedLinkTarget = ''; // Reset target when type changes
                          linkTargetCtrl.clear();
                        }),
                      ),

                      const SizedBox(height: 12),

                      // 2. SELECT LINK TARGET BASED ON TYPE
                      if (selectedLinkType == 'Product')
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Select Specific Product'),
                          hint: const Text('Select a product'),
                          value: selectedLinkTarget.isEmpty ? null : selectedLinkTarget,
                          items: productsState.products.map((p) {
                            return DropdownMenuItem(value: p.id, child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (val) => setDialogState(() => selectedLinkTarget = val ?? ''),
                        )
                      else if (selectedLinkType != 'None')
                      // For Category, Section, Page, use a TextField so you can enter the specific ID
                        TextField(
                          controller: linkTargetCtrl,
                          decoration: InputDecoration(labelText: 'Enter $selectedLinkType ID', border: const OutlineInputBorder()),
                          onChanged: (val) => selectedLinkTarget = val,
                        ),

                      const SizedBox(height: 16),
                      const Text('Banner Image', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final XFile? img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                          if (img != null) {
                            setDialogState(() {
                              newImageFile = File(img.path);
                              existingImageUrl = null;
                            });
                          }
                        },
                        child: Container(
                          height: 130,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue[200]!),
                            image: newImageFile != null
                                ? DecorationImage(image: FileImage(newImageFile!), fit: BoxFit.cover)
                                : (existingImageUrl != null && existingImageUrl!.isNotEmpty)
                                ? DecorationImage(image: NetworkImage(existingImageUrl!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: (newImageFile == null && (existingImageUrl == null || existingImageUrl!.isEmpty))
                              ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 36, color: Colors.blue[400]),
                              const SizedBox(height: 6),
                              Text('Tap to select banner', style: TextStyle(color: Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          )
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                onPressed: isSaving
                    ? null
                    : () async {
                  if (titleCtrl.text.trim().isEmpty || messageCtrl.text.trim().isEmpty) return;
                  setDialogState(() => isSaving = true);

                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(dialogContext);

                  try {
                    String? finalImageUrl = existingImageUrl;
                    if (selectedMode == 1 && newImageFile != null) {
                      final fileName = 'push_campaigns/${DateTime.now().millisecondsSinceEpoch}.jpg';
                      final storageRef = FirebaseStorage.instance.ref().child(fileName);
                      await storageRef.putFile(newImageFile!);
                      finalImageUrl = await storageRef.getDownloadURL();
                    } else if (selectedMode == 0) {
                      finalImageUrl = null;
                      selectedLinkType = 'None';
                      selectedLinkTarget = '';
                    }

                    await _executeBroadcast(
                      title: titleCtrl.text.trim(),
                      body: messageCtrl.text.trim(),
                      type: selectedType,
                      imageUrl: finalImageUrl,
                      linkType: selectedLinkType,
                      linkTarget: selectedLinkTarget,
                    );

                    navigator.pop();
                    messenger.showSnackBar(const SnackBar(content: Text('Broadcast Sent to All Users!'), backgroundColor: Colors.green));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    setDialogState(() => isSaving = false);
                  }
                },
                child: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('SEND BROADCAST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Broadcast notifications to all registered customers.',
                style: TextStyle(color: Colors.grey, fontSize: widget.isDesktop ? 16 : 14),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: EdgeInsets.symmetric(horizontal: widget.isDesktop ? 18 : 12, vertical: widget.isDesktop ? 16 : 10),
              ),
              icon: Icon(Icons.add, color: Colors.white, size: widget.isDesktop ? 20 : 16),
              label: Text(widget.isDesktop ? 'NEW NOTIFICATION' : 'NEW', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => _openNotificationDialog(),
            )
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Consumer(builder: (context, ref, child) {
            final notificationsAsync = ref.watch(adminNotificationsProvider);

            return notificationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (snapshot) {
                if (snapshot.docs.isEmpty) return const Center(child: Text('No broadcast history. Send your first message!'));

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: ListView.separated(
                    itemCount: snapshot.docs.length,
                    separatorBuilder: (_, __) => Divider(color: Colors.grey[200], height: 1),
                    itemBuilder: (context, index) {
                      final data = snapshot.docs[index].data() as Map<String, dynamic>;
                      final docId = snapshot.docs[index].id;

                      final title = data['title'] ?? 'No Title';
                      final body = data['body'] ?? '';
                      final type = data['type'] ?? 'Alert';
                      final hasImage = data['imageUrl'] != null && (data['imageUrl'] as String).isNotEmpty;
                      final sentDate = _formatDate(data['createdAt'] as Timestamp?);

                      Color iconColor = Colors.blue;
                      IconData icon = Icons.notifications;
                      if (type == 'Offer') { iconColor = Colors.orange; icon = Icons.discount; }
                      if (type == 'Update') { iconColor = Colors.purple; icon = Icons.system_update; }

                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: widget.isDesktop ? 20 : 12, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: iconColor.withOpacity(0.1),
                          child: Icon(icon, color: iconColor),
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
                            if (hasImage)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)),
                                child: const Text('RICH', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(body, style: const TextStyle(color: Colors.black87)),
                            const SizedBox(height: 4),
                            Text('Sent: $sentDate', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.replay, color: Colors.green, size: 22),
                              tooltip: 'Resend Now',
                              onPressed: () => _resendNotification(data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_note, color: Colors.blue, size: 22),
                              tooltip: 'Edit & Resend',
                              onPressed: () => _openNotificationDialog(initialData: data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                              tooltip: 'Delete',
                              onPressed: () => _deleteNotification(docId),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}
