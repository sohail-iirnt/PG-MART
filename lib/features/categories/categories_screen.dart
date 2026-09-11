import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'category_products_screen.dart';

// === THE LIVE CATEGORIES ENGINE (USER APP) ===
// === FIXED: Removed orderBy to prevent Firebase Index Crash ===
final liveCategoriesProvider = StreamProvider<QuerySnapshot>((ref) {
  return FirebaseFirestore.instance
      .collection('categories')
      .where('isActive', isEqualTo: true)
      .snapshots();
});

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the live stream
    final categoriesAsync = ref.watch(liveCategoriesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F5F9), // Very light cool grey
      appBar: AppBar(
        title: Text(
          'Categories',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          // If you haven't added 'sortOrder' to Firebase yet, it might throw an index error.
          // This fallback gracefully shows a message while you update the Admin side.
          return Center(child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text('Updating Category Engine...\n(If this persists, check Firebase Indexes or save a category in Admin)', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
          ));
        },
        data: (snapshot) {
          // === NEW: Sort the categories directly in Dart! ===
          final categories = snapshot.docs.toList();
          categories.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            // If it doesn't have a sortOrder, push it to the back (99)
            final aSort = aData['sortOrder'] ?? 99;
            final bSort = bData['sortOrder'] ?? 99;
            return aSort.compareTo(bSort);
          });

          if (categories.isEmpty) {
            return const Center(child: Text('No categories available yet.'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85, // Perfect ratio for 75% image / 25% text
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemBuilder: (context, index) {
              final catData = categories[index].data() as Map<String, dynamic>;
              final String name = catData['name'] ?? 'Unknown';
              final String imageUrl = catData['imageUrl'] ?? '';

              return GestureDetector(
                onTap: () {
                  final cleanName = name.replaceAll('\n', ' ');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryProductsScreen(categoryName: cleanName),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Part: The Premium Image Box (75%)
                      Expanded(
                        flex: 3,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: Colors.grey[100]),
                            errorWidget: (context, url, error) => Container(
                                color: Colors.grey[50],
                                child: const Icon(Icons.category, color: Colors.grey, size: 30)
                            ),
                          ),
                        ),
                      ),

                      // Bottom Part: Solid White Title Bar (25%)
                      Expanded(
                        flex: 1,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            name.toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.black87, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ],
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