import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/providers/auth_provider.dart';

// === LIVE NOTIFICATIONS STREAM FOR LOGGED IN USER ===
final liveNotificationsProvider = StreamProvider<QuerySnapshot?>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);

      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .snapshots();
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  String _timeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final duration = DateTime.now().difference(timestamp.toDate());
    if (duration.inDays > 0) return '${duration.inDays} days ago';
    if (duration.inHours > 0) return '${duration.inHours} hours ago';
    if (duration.inMinutes > 0) return '${duration.inMinutes} mins ago';
    return 'Just now';
  }

  // === UPDATES NOTIFICATION AS 'READ' ===
  Future<void> _markAsRead(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(docId)
          .update({'isRead': true});
    }
  }

  // === DELETES NOTIFICATION FROM USER FOLDER ===
  Future<void> _deleteUserNotification(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(docId)
          .delete();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(liveNotificationsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error loading notifications: $error')),
        data: (snapshot) {
          if (snapshot == null || snapshot.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('No new notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text('We will notify you about offers and updates.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: snapshot.docs.length,
            separatorBuilder: (context, index) => Divider(color: Colors.grey[200], height: 1),
            itemBuilder: (context, index) {
              final data = snapshot.docs[index].data() as Map<String, dynamic>;
              final docId = snapshot.docs[index].id;

              final title = data['title'] ?? 'Update';
              final subtitle = data['body'] ?? '';
              final type = data['type'] ?? 'Alert';
              final timeString = _timeAgo(data['createdAt'] as Timestamp?);

              // === NEW: READ/UNREAD LOGIC ===
              // Check if it's explicitly read. If 'isRead' doesn't exist (old notification), fall back to checking if it's less than 24h old.
              final isExplicitlyRead = data['isRead'] ?? false;
              final isUnder24Hours = data['createdAt'] != null && DateTime.now().difference((data['createdAt'] as Timestamp).toDate()).inHours < 24;
              final isUnread = !isExplicitlyRead && isUnder24Hours;

              Color iconColor = Theme.of(context).primaryColor;
              IconData icon = Icons.notifications;

              if (type == 'Offer') { iconColor = Colors.orange; icon = Icons.discount; }
              if (type == 'Update') { iconColor = Colors.purple; icon = Icons.system_update; }

              // === NEW: SWIPE TO DELETE (DISMISSIBLE) ===
              return Dismissible(
                key: Key(docId),
                direction: DismissDirection.endToStart, // Swipe right-to-left
                onDismissed: (direction) {
                  _deleteUserNotification(docId);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification cleared'), duration: Duration(seconds: 1)));
                },
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: GestureDetector(
                  onTap: () {
                    if (isUnread) _markAsRead(docId);
                  },
                  child: Container(
                    color: isUnread ? Colors.blue[50]!.withOpacity(0.3) : Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: iconColor.withOpacity(0.1),
                        child: Icon(icon, color: iconColor),
                      ),
                      title: Text(title, style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.w500)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(subtitle, style: const TextStyle(height: 1.4)),
                            const SizedBox(height: 8),
                            Text(timeString, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}