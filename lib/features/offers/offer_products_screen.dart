import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../home/providers/products_provider.dart';
import '../home/widgets/product_card.dart';
import '../home/widgets/product_skeleton.dart';

class OfferProductsScreen extends ConsumerWidget {
  final int discountTier; // e.g., 70, 50, 25, 10

  const OfferProductsScreen({super.key, required this.discountTier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We listen to the exact same LIVE Firebase stream!
    final productsAsyncValue = ref.watch(productsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Min $discountTier% OFF',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.black, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: productsAsyncValue.when(
        loading: () => GridView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 6,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 16, mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) => const ProductSkeleton(),
        ),
        error: (error, stack) => Center(child: Text('Error loading offers: $error')),
        data: (products) {
          // AUTOMATIC MATH FILTERING
          final offerProducts = products.where((product) {
            if (product.originalPrice <= product.price) return false;
            // Calculate the actual discount percentage of this specific product
            final actualDiscount = ((product.originalPrice - product.price) / product.originalPrice) * 100;
            // Only show products that meet or exceed this tier!
            return actualDiscount >= discountTier;
          }).toList();

          if (offerProducts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_offer_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('No offers in this zone right now.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text('Check back later for mega deals!', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: offerProducts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 0.75, crossAxisSpacing: 16, mainAxisSpacing: 16,
            ),
            itemBuilder: (context, index) {
              return ProductCard(product: offerProducts[index]);
            },
          );
        },
      ),
    );
  }
}