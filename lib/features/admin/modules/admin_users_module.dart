import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// === THE LIVE USERS ENGINE ===
// FIXED: Now perfectly matches your app's database by sorting by 'updatedAt'!
final adminUsersProvider = StreamProvider<QuerySnapshot>((ref) =>
    FirebaseFirestore.instance.collection('users').orderBy('updatedAt', descending: true).snapshots());

class AdminUsersModule extends ConsumerStatefulWidget {
  final bool isDesktop;
  const AdminUsersModule({super.key, required this.isDesktop});

  @override
  ConsumerState<AdminUsersModule> createState() => _AdminUsersModuleState();
}

class _AdminUsersModuleState extends ConsumerState<AdminUsersModule> {

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown Date';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _toggleUserStatus(String userId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isBlocked': !currentStatus,
      });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(currentStatus ? 'User Blocked' : 'User Activated'), backgroundColor: currentStatus ? Colors.red : Colors.green));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text('Manage registered customers and block bad actors.', style: TextStyle(color: Colors.grey, fontSize: widget.isDesktop ? 16 : 14))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.people, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Text('Customer Database', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          ],
        ),
        const SizedBox(height: 16),

        Expanded(
          child: Consumer(builder: (context, ref, child) {
            final usersAsync = ref.watch(adminUsersProvider);

            return usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, stack) => Center(child: Text('Error: $e')),
              data: (snapshot) {
                if (snapshot.docs.isEmpty) return const Center(child: Text('No users registered yet.'));

                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: ListView.separated(
                    itemCount: snapshot.docs.length,
                    separatorBuilder: (context, index) => Divider(color: Colors.grey[200], height: 1),
                    itemBuilder: (context, index) {
                      final userData = snapshot.docs[index].data() as Map<String, dynamic>;
                      final userId = snapshot.docs[index].id;

                      final name = userData['name'] ?? 'No Name Set';
                      final phone = userData['phone'] ?? 'Unknown Phone';
                      final isBlocked = userData['isBlocked'] ?? false;

                      // FIXED: Safely checks for BOTH createdAt and updatedAt so it never breaks!
                      final activeDate = _formatDate((userData['updatedAt'] ?? userData['createdAt']) as Timestamp?);

                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: widget.isDesktop ? 24 : 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: isBlocked ? Colors.red[100] : Theme.of(context).primaryColor.withOpacity(0.1),
                          child: Icon(isBlocked ? Icons.block : Icons.person, color: isBlocked ? Colors.red : Theme.of(context).primaryColor),
                        ),
                        title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, decoration: isBlocked ? TextDecoration.lineThrough : null, color: isBlocked ? Colors.grey : Colors.black)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Phone: $phone', style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text('Last Active: $activeDate', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: isBlocked ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isBlocked ? Colors.red : Colors.green)
                              ),
                              child: Text(isBlocked ? 'BLOCKED' : 'ACTIVE', style: TextStyle(color: isBlocked ? Colors.red : Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            Switch(
                              value: !isBlocked,
                              activeColor: Colors.green,
                              inactiveThumbColor: Colors.red,
                              onChanged: (val) {
                                _toggleUserStatus(userId, isBlocked);
                              },
                            )
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