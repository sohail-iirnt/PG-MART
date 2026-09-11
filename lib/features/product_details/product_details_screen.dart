import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/product_model.dart';
import '../cart/providers/cart_provider.dart';
import '../cart/cart_screen.dart';
import '../search/search_screen.dart';
import 'image_full_screen_screen.dart';
import 'widgets/product_reviews_section.dart';
// === NEW: IMPORTS FOR SUGGESTED PRODUCTS ===
import '../home/providers/products_provider.dart';
import '../home/widgets/product_card.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  final ProductModel product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  ConsumerState<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  int _currentImageIndex = 0;
  int _selectedTabIndex = 0; // 0 = Description, 1 = Disclaimer, 2 = More Info
  int _selectedVariantIndex = 0; // TRACKS ACTIVE VARIANT

  @override
  void initState() {
    super.initState();
    // === AUTO-SELECT THE TAPPED VARIANT ON FIRST BOOT ===
    if (widget.product.id.contains('_v_')) {
      final parts = widget.product.id.split('_v_');
      if (parts.length > 1) {
        _selectedVariantIndex = int.tryParse(parts[1]) ?? 0;
      }
    } else {
      _selectedVariantIndex = 0; // Default to the injected "Main Pack" at index 0
    }
  }

  @override
  Widget build(BuildContext context) {
    // === DYNAMIC VARIANT LOGIC ===
    ProductModel currentProduct = widget.product;
    String baseName = widget.product.name;
    String baseId = widget.product.id;

    if (widget.product.hasVariants && widget.product.variants.isNotEmpty) {

      // Clean up the ID and Name if it came from an unpacked provider card
      if (baseId.contains('_v_')) {
        baseId = baseId.split('_v_')[0];
      }

      for (var v in widget.product.variants) {
        final vName = v['name'] ?? '';
        // Skip modifying the base name if we are looking at the base item itself
        if (vName.isNotEmpty && v['isBase'] != true && baseName.endsWith(' - $vName')) {
          baseName = baseName.substring(0, baseName.length - (' - $vName').length);
          break;
        }
      }

      final activeVariant = widget.product.variants[_selectedVariantIndex];

      // Grab specific images for this variant (fall back to base images if none)
      List<String> activeImages = [];
      if (activeVariant['imageUrls'] != null && (activeVariant['imageUrls'] as List).isNotEmpty) {
        activeImages = List<String>.from(activeVariant['imageUrls']);
      } else if (activeVariant['imageUrl'] != null) {
        activeImages = [activeVariant['imageUrl']];
      } else {
        activeImages = widget.product.imageUrls;
      }

      // Determine dynamic name (Hide the Base Variant Name from the actual title)
      String dynamicName = baseName;
      if (activeVariant['isBase'] != true) {
        dynamicName = '$baseName - ${activeVariant['name']}';
      }

      // Create a temporary version of the product with the variant's details
      currentProduct = ProductModel(
        id: activeVariant['isBase'] == true ? baseId : '${baseId}_v_$_selectedVariantIndex',
        name: dynamicName,
        category: widget.product.category,
        originalPrice: (activeVariant['originalPrice'] ?? 0).toDouble(),
        price: (activeVariant['price'] ?? 0).toDouble(),
        imageUrl: activeImages.isNotEmpty ? activeImages.first : widget.product.imageUrl,
        description: widget.product.description,
        keywords: widget.product.keywords,
        isAvailable: widget.product.isAvailable,
        createdAt: widget.product.createdAt,
        baseVariantName: widget.product.baseVariantName,
        imageUrls: activeImages,
        hasVariants: widget.product.hasVariants,
        variants: widget.product.variants,
      );
    }

    // Calculate discounts based on the currently selected variant
    final double discountAmount = currentProduct.originalPrice - currentProduct.price;
    final bool hasDiscount = discountAmount > 0;

    // === MULTI-IMAGE GALLERY SUPPORT ===
    final List<String> galleryImages = currentProduct.imageUrls.isNotEmpty
        ? currentProduct.imageUrls
        : [currentProduct.imageUrl];

    // === NEW: SUGGESTED PRODUCTS LOGIC ===
    final productsState = ref.watch(paginatedProductsProvider);
    final similarProducts = productsState.products
        .where((p) => p.category == currentProduct.category && p.id != widget.product.id)
        .take(6) // Show up to 6 similar items
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.blue),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen())),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: IconButton(
              icon: Badge(
                label: Text(ref.watch(cartProvider.notifier).totalItems.toString()),
                isLabelVisible: ref.watch(cartProvider).isNotEmpty,
                child: const Icon(Icons.shopping_cart_outlined, color: Colors.blue, size: 28),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. BRAND / CATEGORY
              Text(
                currentProduct.category.toUpperCase(),
                style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 13, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
              ),
              const SizedBox(height: 8),

              // 2. PRODUCT TITLE
              Text(
                currentProduct.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.3),
              ),
              const SizedBox(height: 16),

              // 3. IMAGE CAROUSEL SQUARE
              Container(
                height: 320,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, spreadRadius: 1)],
                ),
                child: Stack(
                  children: [
                    // The Swipeable Images
                    PageView.builder(
                      itemCount: galleryImages.length,
                      onPageChanged: (index) {
                        setState(() => _currentImageIndex = index);
                      },
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ImageFullScreenScreen(imageUrl: galleryImages[index])),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Hero(
                              tag: 'product_image_${currentProduct.id}',
                              child: CachedNetworkImage(
                                imageUrl: galleryImages[index],
                                fit: BoxFit.contain, // Prevents cropping!
                                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Top Left: Discount Tag
                    if (hasDiscount)
                      Positioned(
                        top: 16,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
                          ),
                          child: Text(
                            '₹${discountAmount.toStringAsFixed(0)} OFF',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),

                    // Bottom Center: Slide Indicators
                    if (galleryImages.length > 1)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(galleryImages.length, (index) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: _currentImageIndex == index ? 16 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _currentImageIndex == index ? Colors.greenAccent : Colors.white54,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. PRICE ROW
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${currentProduct.price.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(width: 8),
                  if (hasDiscount)
                    Text(
                      '₹${currentProduct.originalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 18, color: Colors.grey, decoration: TextDecoration.lineThrough, fontWeight: FontWeight.w500),
                    ),
                  const SizedBox(width: 8),
                  const Text(
                    '(MRP inclusive of all taxes)',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 5. PACK SIZE / WEIGHT SELECTOR
              const Text('Unit / Pack Size:', style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // === SHOW DYNAMIC VARIANTS IF THEY EXIST ===
              if (widget.product.hasVariants && widget.product.variants.isNotEmpty)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(widget.product.variants.length, (index) {
                    final variant = widget.product.variants[index];
                    final isSelected = _selectedVariantIndex == index;

                    final String displayName = variant['isBase'] == true ? widget.product.baseVariantName : (variant['name'] ?? '');

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedVariantIndex = index;
                          _currentImageIndex = 0; // Reset image slider when changing variants
                        });
                      },
                      child: Container(
                        width: 120,
                        decoration: BoxDecoration(
                          border: Border.all(color: isSelected ? Theme.of(context).primaryColor : Colors.grey[300]!, width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Theme.of(context).primaryColor : Colors.grey[100],
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                              ),
                              child: Center(child: Text(displayName, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                '₹${(variant['price'] ?? 0).toStringAsFixed(0)}',
                                style: TextStyle(color: isSelected ? Colors.green[800] : Colors.black54, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                )
              else
              // === SHOW STATIC SELECTOR IF NO VARIANTS ===
                Container(
                  width: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).primaryColor, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                        ),
                        // === FIX: Shows the custom Base Unit Name instead of "1 Pack" ===
                        child: Center(child: Text(widget.product.baseVariantName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          hasDiscount ? '₹${discountAmount.toStringAsFixed(0)} OFF' : 'Standard Rate',
                          style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 30),

              // 6. TABS (Description, Disclaimer, More Info)
              Row(
                children: [
                  _buildTab('Description', 0),
                  const SizedBox(width: 16),
                  _buildTab('Disclaimer', 1),
                  const SizedBox(width: 16),
                  _buildTab('More Info', 2),
                ],
              ),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 16),

              // TAB CONTENT
              _buildTabContent(),

              const SizedBox(height: 32),
              const Divider(height: 1, thickness: 1),
              const SizedBox(height: 24),

              // === REVIEWS SECTION INJECTED HERE ===
              ProductReviewsSection(productId: widget.product.id),

              // === NEW: SUGGESTED PRODUCTS SECTION ===
              if (similarProducts.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 24),
                const Text('You Might Also Like', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 290, // Sufficient height for the ProductCard
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    // Using clipBehavior to let the shadow breathe a bit
                    clipBehavior: Clip.none,
                    itemCount: similarProducts.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 165,
                        margin: const EdgeInsets.only(right: 12, bottom: 8),
                        child: ProductCard(product: similarProducts[index]),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 80), // Padding for the bottom bar
            ],
          ),
        ),
      ),

      // 7. BOTTOM NAVIGATION BAR (ADD TO CART)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: SafeArea(
          child: Builder(builder: (context) {
            final quantity = ref.watch(cartProvider.notifier).getItemQuantity(currentProduct.id);
            final cartNotifier = ref.read(cartProvider.notifier);

            return quantity > 0
            // === FIX: SPLIT BUTTONS WHEN ITEM IS IN CART ===
                ? Row(
              children: [
                // Button 1: GO TO CART
                Expanded(
                  flex: 1,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    icon: Icon(Icons.shopping_cart_checkout, color: Theme.of(context).primaryColor, size: 18),
                    label: Text('GO TO CART', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())),
                  ),
                ),
                const SizedBox(width: 12),
                // Button 2: COUNTER (+ / -)
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(color: Theme.of(context).primaryColor, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(icon: const Icon(Icons.remove, color: Colors.white, size: 20), onPressed: () => cartNotifier.removeSingleItem(currentProduct.id)),
                        Text('$quantity', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.add, color: Colors.white, size: 20), onPressed: () => cartNotifier.addToCart(currentProduct)),
                      ],
                    ),
                  ),
                ),
              ],
            )
                : SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
                label: const Text('ADD TO CART', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                onPressed: () => cartNotifier.addToCart(currentProduct),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 3,
            width: 40,
            color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
          )
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    if (_selectedTabIndex == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Product Highlights:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Text(widget.product.description, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5)),
        ],
      );
    } else if (_selectedTabIndex == 1) {
      return const Text('Disclaimer: Every effort is made to maintain accuracy of all information. However, actual product packaging and materials may contain more and/or different information. It is recommended not to solely rely on the information presented.', style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5));
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFeatureRow(Icons.verified_outlined, 'Premium Wholesale Quality Guaranteed'),
          _buildFeatureRow(Icons.local_shipping_outlined, 'Fast Delivery inside Bhiwandi'),
          _buildFeatureRow(Icons.currency_rupee, 'Price Match Guarantee Applied'),
        ],
      );
    }
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[800], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}