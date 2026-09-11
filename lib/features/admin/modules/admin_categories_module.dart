import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// === FIXED: Removed orderBy so old categories reappear! ===
final adminCategoriesProvider = StreamProvider<QuerySnapshot>((ref) =>
    FirebaseFirestore.instance.collection('categories').snapshots()
);

class AdminCategoriesModule extends ConsumerStatefulWidget {
  final bool isDesktop;
  const AdminCategoriesModule({super.key, required this.isDesktop});

  @override
  ConsumerState<AdminCategoriesModule> createState() => _AdminCategoriesModuleState();
}

class _AdminCategoriesModuleState extends ConsumerState<AdminCategoriesModule> {
  Future<void> _toggleCategoryStatus(String categoryId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('categories').doc(categoryId).update({'isActive': !currentStatus});
  }

  Future<void> _deleteCategory(String categoryId) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete Category?'), content: const Text('Are you sure?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('DELETE'))]));
    if (confirm == true) await FirebaseFirestore.instance.collection('categories').doc(categoryId).delete();
  }

  void _showCategoryDialog({String? categoryId, Map<String, dynamic>? existingData}) {
    final isEditing = categoryId != null;
    final nameCtrl = TextEditingController(text: existingData?['name'] ?? '');
    final imageCtrl = TextEditingController(text: existingData?['imageUrl'] ?? '');
    // === NEW: Sort Order Controller (Defaults to 10 if none exists) ===
    final sortCtrl = TextEditingController(text: existingData?['sortOrder']?.toString() ?? '10');
    bool isActive = existingData?['isActive'] ?? true;
    bool isSaving = false;

    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit Category' : 'Add New Category', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(width: widget.isDesktop ? 400 : double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Category Name', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(controller: imageCtrl, decoration: const InputDecoration(labelText: 'Image URL', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                // === NEW: UI Input for Sort Order ===
                TextField(controller: sortCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Sort Order (e.g. 1 shows first)', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Active', style: TextStyle(fontWeight: FontWeight.w500)), Switch(value: isActive, activeColor: Colors.green, onChanged: (val) => setState(() => isActive = val))]))
              ])),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
                ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor), onPressed: isSaving ? null : () async {
                  setState(() => isSaving = true);
                  try {
                    // === UPDATED: Saves the sortOrder as an integer ===
                    final catData = {
                      'name': nameCtrl.text.trim(),
                      'imageUrl': imageCtrl.text.trim(),
                      'sortOrder': int.tryParse(sortCtrl.text.trim()) ?? 10,
                      'isActive': isActive,
                      'updatedAt': FieldValue.serverTimestamp()
                    };

                    if (isEditing) {
                      await FirebaseFirestore.instance.collection('categories').doc(categoryId).update(catData);
                    } else {
                      catData['createdAt'] = FieldValue.serverTimestamp();
                      await FirebaseFirestore.instance.collection('categories').add(catData);
                    }
                    if (mounted) Navigator.pop(context);
                  } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); setState(() => isSaving = false); }
                }, child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white)) : Text(isEditing ? 'UPDATE' : 'SAVE', style: const TextStyle(color: Colors.white))),
              ],
            );
          }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [if (widget.isDesktop) const Text('Manage app navigation categories', style: TextStyle(color: Colors.grey, fontSize: 16)) else const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor), icon: const Icon(Icons.add_circle, color: Colors.white, size: 18), label: Text(widget.isDesktop ? 'ADD CATEGORY' : 'ADD', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)), onPressed: () => _showCategoryDialog())]),
        const SizedBox(height: 16),
        Expanded(
          child: Consumer(builder: (context, ref, child) {
            final categoriesAsync = ref.watch(adminCategoriesProvider);
            return categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()), error: (e, stack) => Center(child: Text('Error: $e')),
              data: (snapshot) {
                if (snapshot.docs.isEmpty) return const Center(child: Text('No categories yet. Click Add above!'));
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: widget.isDesktop ? 6 : 3, childAspectRatio: 0.8, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemCount: snapshot.docs.length,
                  itemBuilder: (context, index) {
                    final catData = snapshot.docs[index].data() as Map<String, dynamic>; final categoryId = snapshot.docs[index].id; final isActive = catData['isActive'] ?? true;
                    return Card(clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isActive ? Colors.transparent : Colors.red, width: 2)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircleAvatar(radius: 30, backgroundColor: Colors.grey[100], backgroundImage: NetworkImage(catData['imageUrl'] ?? ''), onBackgroundImageError: (e, s) => {}, child: catData['imageUrl'] == null || catData['imageUrl'].isEmpty ? const Icon(Icons.category, color: Colors.grey) : null), const SizedBox(height: 8), Text(catData['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center, maxLines: 1), const SizedBox(height: 4),
                      // === FIX 7: WRAPPED IN FITTEDBOX TO PREVENT OVERFLOW ON SMALL PHONES ===
                      FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Switch(value: isActive, activeColor: Colors.green, onChanged: (val) => _toggleCategoryStatus(categoryId, isActive)),
                                IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _showCategoryDialog(categoryId: categoryId, existingData: catData)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _deleteCategory(categoryId))
                              ]
                          )
                      )
                    ]));
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