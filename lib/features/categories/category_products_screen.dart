import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../home/providers/products_provider.dart'; // THE LIVE FIREBASE PROVIDER
import '../home/widgets/product_card.dart';
import '../home/widgets/product_skeleton.dart';

class CategoryProductsScreen extends ConsumerStatefulWidget {
  final String categoryName;

  const CategoryProductsScreen({super.key, required this.categoryName});

  @override
  ConsumerState<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends ConsumerState<CategoryProductsScreen> {
  // Kept your ScrollController for smooth UI scrolling
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // === THE FIX: We watch the DEDICATED category stream instead of the global 20-item paginated state ===
    final categoryAsync = ref.watch(categoryProductsStreamProvider(widget.categoryName));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: categoryAsync.when(
        // 1. YOUR EXACT LOADING SKELETON UI
        loading: () => GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 16, mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) => const ProductSkeleton(),
        ),

        // 2. ERROR STATE
        error: (error, stack) => Center(child: Text('Error loading category: $error')),

        // 3. SUCCESS DATA STATE
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No items in ${widget.categoryName} currently loaded.', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  // Because it's a direct query, if it's empty, it truly means the Admin hasn't added items yet.
                  const Text('Check back soon as we add more stock!', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // 4. YOUR EXACT GRID UI
          return Column(
            children: [
              Expanded(
                child: GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 16, mainAxisSpacing: 16,
                  ),
                  itemBuilder: (context, index) {
                    return ProductCard(product: products[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}