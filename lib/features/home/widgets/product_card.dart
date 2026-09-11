import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product_model.dart';
import '../../cart/providers/cart_provider.dart';
import '../../product_details/product_details_screen.dart';
import '../../wishlist/providers/wishlist_provider.dart';

class ProductCard extends ConsumerWidget {
  final ProductModel product;

  const ProductCard({super.key, required this.product});

  void _showPriceComparison(BuildContext context) {
    final mrp = product.originalPrice > product.price ? product.originalPrice : product.price * 1.2;
    final localMarketPrice = mrp;
    final otherAppsPrice = mrp + 35;
    final pgMartPrice = product.price;
    final maxSavings = otherAppsPrice - pgMartPrice;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24, right: 24, top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Price Match Guarantee', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildCompareRow('Local Supermarket (MRP)', localMarketPrice, isPgMart: false),
                const Divider(height: 30),
                _buildCompareRow('Other Delivery Apps', otherAppsPrice, isPgMart: false),
                const Divider(height: 30),
                _buildCompareRow('PG MART (Wholesale)', pgMartPrice, isPgMart: true),
                const SizedBox(height: 30),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '🔥 You save ₹${maxSavings.toStringAsFixed(0)} with us!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompareRow(String name, double price, {required bool isPgMart}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isPgMart ? FontWeight.bold : FontWeight.normal,
            color: isPgMart ? Colors.black : Colors.grey[700],
          ),
        ),
        Text(
          '₹${price.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: isPgMart ? FontWeight.w900 : FontWeight.w500,
            color: isPgMart ? Colors.green : Colors.grey[500],
            decoration: isPgMart ? TextDecoration.none : TextDecoration.lineThrough,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(cartProvider);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProductDetailsScreen(product: product)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === 🚨 FIXED: REDUCED IMAGE FLEX TO GIVE TEXT ROOM 🚨 ===
            Expanded(
              flex: 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: CachedNetworkImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[300])),
                        errorWidget: (context, url, error) => Icon(Icons.image_not_supported, color: Colors.grey[400]),
                      ),
                    ),
                  ),

                  if (product.originalPrice > product.price)
                    Positioned(
                      top: 0, left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1A237E),
                          borderRadius: BorderRadius.only(topLeft: Radius.circular(10), bottomRight: Radius.circular(8)),
                        ),
                        child: Text(
                          '${((product.originalPrice - product.price) / product.originalPrice * 100).toInt()}% OFF',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ),
                    ),

                  Positioned(
                    top: 4, right: 4,
                    child: Consumer(
                      builder: (context, ref, child) {
                        final isLiked = ref.watch(wishlistProvider.notifier).isInWishlist(product.id);
                        return GestureDetector(
                          onTap: () => ref.read(wishlistProvider.notifier).toggleWishlist(product),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                            ),
                            child: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.grey[400], size: 16),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // === 🚨 FIXED: INCREASED CONTENT FLEX TO PREVENT OVERLAP 🚨 ===
            Expanded(
              flex: 13,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, height: 1.2, color: Colors.black87, letterSpacing: -0.2),
                          ),
                          if (product.sellerName != null && product.sellerName!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                'By ${product.sellerName!}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                              ),
                            ),

                          const Spacer(), // Forces the price & button safely to the bottom of the content area

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (product.originalPrice > product.price)
                                    Text('MRP ₹${product.originalPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 9, color: Colors.grey, decoration: TextDecoration.lineThrough, fontWeight: FontWeight.w700)),

                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2.0, right: 1.0),
                                        child: Text('₹', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black87)),
                                      ),
                                      Text(
                                          product.price.toStringAsFixed(0),
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -0.5, height: 1.1)
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              Builder(builder: (context) {
                                final quantity = ref.read(cartProvider.notifier).getItemQuantity(product.id);
                                final cartNotifier = ref.read(cartProvider.notifier);

                                return quantity > 0
                                    ? Container(
                                  height: 30, // Safely reduced height
                                  decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 26), icon: const Icon(Icons.remove, size: 16, color: Colors.white), onPressed: () => cartNotifier.removeSingleItem(product.id)),
                                      Text('$quantity', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                      IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 26), icon: const Icon(Icons.add, size: 16, color: Colors.white), onPressed: () => cartNotifier.addToCart(product)),
                                    ],
                                  ),
                                )
                                    : SizedBox(
                                  height: 30, // Safely reduced height
                                  width: 65,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.08),
                                      foregroundColor: Theme.of(context).primaryColor,
                                      elevation: 0,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.3), width: 1)
                                      ),
                                    ),
                                    onPressed: () => cartNotifier.addToCart(product),
                                    child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  GestureDetector(
                    onTap: () => _showPriceComparison(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(11), bottomRight: Radius.circular(11)),
                          border: Border(top: BorderSide(color: Colors.grey[200]!))
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.compare_arrows_rounded, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('COMPARE PRICE', style: TextStyle(fontSize: 9, color: Colors.grey[700], fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}