import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../home/widgets/product_card.dart';
import '../home/widgets/product_skeleton.dart';
import '../../../models/product_model.dart';

// ROUTING IMPORTS
import '../categories/category_products_screen.dart';
import '../search/search_screen.dart';
import '../product_details/product_details_screen.dart';
import '../home/providers/products_provider.dart';

// === NEW: DEEP LINKING IMPORTS ===
import '../main/main_layout.dart';
import '../cart/cart_screen.dart';
import '../orders/orders_screen.dart';
import '../support/support_screen.dart';
import '../offers/offers_tab_screen.dart';

// === LIVE PROVIDERS ===
final localBannersProvider = StreamProvider<QuerySnapshot>((ref) =>
    FirebaseFirestore.instance.collection('banners')
        .where('isActive', isEqualTo: true)
        .where('screenTarget', isEqualTo: 'vocal_for_local')
        .snapshots()
);

final featuredMakersProvider = StreamProvider<QuerySnapshot>((ref) =>
    FirebaseFirestore.instance.collection('local_sellers')
        .where('status', isEqualTo: 'approved')
        .where('isFeatured', isEqualTo: true)
        .snapshots()
);

final localInFeedAdsProvider = StreamProvider<QuerySnapshot>((ref) =>
    FirebaseFirestore.instance.collection('in_feed_ads')
        .where('isActive', isEqualTo: true)
        .where('screenTarget', isEqualTo: 'vocal_for_local')
        .snapshots()
);

final localProductsProvider = StreamProvider<List<ProductModel>>((ref) {
  return FirebaseFirestore.instance.collection('products')
      .where('visibilityScope', whereIn: ['local', 'both'])
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList());
});

class VocalForLocalScreen extends ConsumerStatefulWidget {
  const VocalForLocalScreen({super.key});

  @override
  ConsumerState<VocalForLocalScreen> createState() => _VocalForLocalScreenState();
}

class _VocalForLocalScreenState extends ConsumerState<VocalForLocalScreen> {
  final PageController _bannerController = PageController();
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  // === UPDATED: IN-APP SCREEN & SECTION ROUTING ===
  Future<void> _handleBannerClick(Map<String, dynamic> bannerData) async {
    final bool isActionable = bannerData['isActionable'] ?? false;
    if (!isActionable) return;

    final String actionType = bannerData['actionType'] ?? 'none';
    final String actionTarget = bannerData['actionTarget'] ?? '';

    if (actionTarget.isEmpty) return;

    switch (actionType) {
      case 'category':
        Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryProductsScreen(categoryName: actionTarget)));
        break;
      case 'product':
        final productsState = ref.read(paginatedProductsProvider).products;
        try {
          final targetProduct = productsState.firstWhere((p) => p.id == actionTarget);
          Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: targetProduct)));
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This promotional product is currently unavailable.')));
        }
        break;
      case 'tag':
        Navigator.push(context, MaterialPageRoute(builder: (_) => SearchScreen(initialQuery: actionTarget)));
        break;
      case 'link':
        final uri = Uri.parse(actionTarget);
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
        break;
      case 'screen':
      // Pop any open dialogs, bottom sheets, or full-screen stories first
        Navigator.popUntil(context, (route) => route.isFirst);

        switch (actionTarget) {
          case 'home_tab':
            ref.read(bottomNavProvider.notifier).state = 0;
            break;
          case 'categories_tab':
            ref.read(bottomNavProvider.notifier).state = 1;
            break;
          case 'offers_tab':
            ref.read(bottomNavProvider.notifier).state = 2;
            break;
          case 'local_hub':
          // If already on Local Hub, optionally do nothing or push to refresh
            break;
          case 'cart':
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
            break;
          case 'orders':
            Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
            break;
          case 'support':
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()));
            break;
          default:
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Screen currently unavailable.')));
        }
        break;
    }
  }

  void _showMakerBio(BuildContext context, Map<String, dynamic> makerData) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, -10))]
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 50, height: 6, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.purple.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                        const BoxShadow(color: Colors.white, blurRadius: 10, offset: Offset(-5, -5)),
                      ]
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.purple, size: 36),
                ),
                const SizedBox(height: 24),
                Text(makerData['brandName'] ?? 'Bazaar Artisan', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text('${makerData['creatorName']} • ${makerData['area']}', style: TextStyle(color: Colors.purple[800], fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey[200]!, width: 1.5),
                  ),
                  child: Text(makerData['bio'] ?? 'A passionate local artisan.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, height: 1.6, fontSize: 15, fontStyle: FontStyle.italic)),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(localBannersProvider);
    final makersAsync = ref.watch(featuredMakersProvider);
    final productsAsync = ref.watch(localProductsProvider);
    final adsAsync = ref.watch(localInFeedAdsProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final int gridCrossAxisCount = screenWidth > 800 ? 4 : (screenWidth > 600 ? 3 : 2);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFFF6F8FE), Color(0xFFF9F5FF), Color(0xFFFFF5F5)]
            )
        ),
        child: SafeArea(
          child: Column(
            children: [
              // === CUSTOM 3D FLOATING TOP BAR ===
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.purple.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10)),
                    ]
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.storefront, color: Colors.purple, size: 24),
                        SizedBox(width: 10),
                        Text('Bhiwandi Entrepreneurs', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, letterSpacing: -0.5, fontSize: 18)),
                      ],
                    ),
                    Icon(Icons.verified, color: Colors.purple[200], size: 20),
                  ],
                ),
              ),

              // === MAIN CONTENT ===
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      if (bannersAsync.value != null) ...[
                        Builder(builder: (context) {
                          final topBanners = bannersAsync.value!.docs.map((d) => d.data() as Map<String, dynamic>).where((b) => (b['positionIndex'] ?? 0) == 0).toList();
                          if (topBanners.isEmpty) return const SizedBox.shrink();

                          return SizedBox(
                            height: 180,
                            child: PageView.builder(
                              controller: _bannerController, itemCount: topBanners.length,
                              itemBuilder: (context, index) {
                                final banner = topBanners[index];
                                return GestureDetector(
                                  onTap: () => _handleBannerClick(banner),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 10))],
                                      image: DecorationImage(image: CachedNetworkImageProvider(banner['imageUrl'] ?? ''), fit: BoxFit.cover),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        }),
                      ],

                      if (bannersAsync.value != null) ...[
                        Builder(builder: (context) {
                          final storyBanners = bannersAsync.value!.docs.map((d) => d.data() as Map<String, dynamic>).where((b) => (b['positionIndex'] ?? 0) == 1).toList();
                          if (storyBanners.isEmpty) return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 110,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  itemCount: storyBanners.length,
                                  itemBuilder: (context, index) {
                                    final story = storyBanners[index];
                                    return GestureDetector(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MultiStoryViewer(stories: storyBanners, initialIndex: index, onAction: _handleBannerClick))),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                        child: Column(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  gradient: const LinearGradient(colors: [Color(0xFFE94057), Color(0xFFF27121)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                                                  boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(3),
                                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                                child: CircleAvatar(
                                                  radius: 32,
                                                  backgroundColor: Colors.grey[200],
                                                  backgroundImage: CachedNetworkImageProvider(story['imageUrl'] ?? ''),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: 76,
                                              child: Text(story['title'] ?? 'Promo', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87)),
                                            )
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        }),
                      ],

                      makersAsync.when(
                          loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                          error: (e, s) => const SizedBox.shrink(),
                          data: (snapshot) {
                            if (snapshot.docs.isEmpty) return const SizedBox.shrink();

                            final makerOfTheWeek = snapshot.docs.first.data() as Map<String, dynamic>;
                            final motwImage = (makerOfTheWeek['sampleImages'] != null && (makerOfTheWeek['sampleImages'] as List).isNotEmpty) ? makerOfTheWeek['sampleImages'][0] : '';
                            final otherMakers = snapshot.docs.skip(1).toList();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(20, 16, 16, 12),
                                  child: Text('Maker of the Week', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5)),
                                ),
                                GestureDetector(
                                  onTap: () => _showMakerBio(context, makerOfTheWeek),
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 16),
                                    height: 200,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
                                      image: DecorationImage(
                                          image: CachedNetworkImageProvider(motwImage),
                                          fit: BoxFit.cover,
                                          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken)
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          top: 16, left: 16,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.star, color: Colors.amber, size: 14),
                                                SizedBox(width: 4),
                                                Text('SPOTLIGHT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 20, left: 20, right: 20,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(makerOfTheWeek['brandName'] ?? 'Brand', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                                              const SizedBox(height: 4),
                                              Text('By ${makerOfTheWeek['creatorName']}', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                                            ],
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),

                                if (otherMakers.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  Container(
                                    height: 120,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: otherMakers.length,
                                      itemBuilder: (context, index) {
                                        final maker = otherMakers[index].data() as Map<String, dynamic>;
                                        final sampleImage = (maker['sampleImages'] != null && (maker['sampleImages'] as List).isNotEmpty) ? maker['sampleImages'][0] : '';

                                        return GestureDetector(
                                          onTap: () => _showMakerBio(context, maker),
                                          child: Container(
                                            width: 200, margin: const EdgeInsets.only(right: 16, bottom: 12, top: 4),
                                            decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(20),
                                                color: Colors.white,
                                                boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 8))]
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 80,
                                                  decoration: BoxDecoration(
                                                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                                                      image: sampleImage.isNotEmpty ? DecorationImage(image: CachedNetworkImageProvider(sampleImage), fit: BoxFit.cover) : null,
                                                      color: Colors.grey[200]
                                                  ),
                                                  child: sampleImage.isEmpty ? Icon(Icons.storefront, color: Colors.purple[200]) : null,
                                                ),
                                                Expanded(
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(12),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(maker['brandName'] ?? 'Maker', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87)),
                                                        const SizedBox(height: 4),
                                                        Text(maker['category'] ?? 'Artisan', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ]
                              ],
                            );
                          }
                      ),

                      productsAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (products) {
                            final categories = ['All', ...products.map((p) => p.category).toSet().toList()];

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.fromLTRB(20, 16, 16, 8),
                                  child: Text('Curated Collection', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: -0.5)),
                                ),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: categories.map((cat) {
                                      final isSelected = _selectedCategory == cat;
                                      return GestureDetector(
                                        onTap: () => setState(() => _selectedCategory = cat),
                                        child: Container(
                                          margin: const EdgeInsets.only(right: 12, bottom: 12),
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isSelected ? Colors.purple : Colors.white,
                                            borderRadius: BorderRadius.circular(30),
                                            border: Border.all(color: isSelected ? Colors.purple : Colors.grey[200]!, width: 1.5),
                                            boxShadow: isSelected ? [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
                                          ),
                                          child: Text(cat, style: TextStyle(fontWeight: FontWeight.w800, color: isSelected ? Colors.white : Colors.black54, fontSize: 13, letterSpacing: 0.5)),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            );
                          }
                      ),

                      productsAsync.when(
                          loading: () => GridView.builder(
                            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: 4, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: gridCrossAxisCount, childAspectRatio: 0.65, crossAxisSpacing: 16, mainAxisSpacing: 16),
                            itemBuilder: (context, index) => const ProductSkeleton(),
                          ),
                          error: (e, s) => Center(child: Text('Error: $e')),
                          data: (allProducts) {
                            final products = _selectedCategory == 'All'
                                ? allProducts
                                : allProducts.where((p) => p.category == _selectedCategory).toList();

                            if (products.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(40.0),
                                  child: Column(
                                    children: [
                                      Icon(Icons.style_outlined, size: 60, color: Colors.purple[200]),
                                      const SizedBox(height: 16),
                                      const Text('No products match this filter.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final allBanners = bannersAsync.value?.docs.map((d) => d.data() as Map<String, dynamic>).toList() ?? [];
                            final lowerBanners = allBanners.where((b) => (b['positionIndex'] ?? 0) == 2).toList();
                            final allAds = adsAsync.value?.docs.map((d) => d.data() as Map<String, dynamic>).toList() ?? [];

                            List<Widget> feedItems = [];
                            int lowerBannerIndex = 0;
                            int sponsorAdIndex = 0;

                            for (int i = 0; i < products.length; i += gridCrossAxisCount) {
                              List<Widget> rowChildren = [];
                              for (int j = 0; j < gridCrossAxisCount; j++) {
                                if (i + j < products.length) {
                                  rowChildren.add(
                                      Expanded(
                                        child: Container(
                                          decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 10)),
                                              ]
                                          ),
                                          child: AspectRatio(aspectRatio: 0.65, child: ProductCard(product: products[i + j])),
                                        ),
                                      )
                                  );
                                } else {
                                  rowChildren.add(const Expanded(child: SizedBox()));
                                }
                                if (j < gridCrossAxisCount - 1) rowChildren.add(const SizedBox(width: 16));
                              }

                              feedItems.add(
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: rowChildren),
                                ),
                              );

                              if (i > 0 && i % (gridCrossAxisCount * 2) == 0 && lowerBanners.isNotEmpty) {
                                final banner = lowerBanners[lowerBannerIndex % lowerBanners.length];
                                feedItems.add(
                                  GestureDetector(
                                    onTap: () => _handleBannerClick(banner),
                                    child: Container(
                                      height: 140, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))],
                                        image: DecorationImage(image: CachedNetworkImageProvider(banner['imageUrl'] ?? ''), fit: BoxFit.cover),
                                      ),
                                    ),
                                  ),
                                );
                                lowerBannerIndex++;
                              }

                              if ((i + gridCrossAxisCount) % (gridCrossAxisCount * 3) == 0 && allAds.isNotEmpty) {
                                final ad = allAds[sponsorAdIndex % allAds.length];
                                feedItems.add(
                                  GestureDetector(
                                    onTap: () async {
                                      final url = ad['actionUrl'];
                                      if (url != null && url.toString().trim().isNotEmpty) {
                                        final uri = Uri.parse(url);
                                        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                      width: double.infinity, clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 10))],
                                      ),
                                      child: AspectRatio(
                                        aspectRatio: 1 / 1,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.network(ad['imageUrl'] ?? '', fit: BoxFit.cover),
                                            Positioned(
                                              top: 12, right: 12,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white)),
                                                child: const Text('Sponsored', style: TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                                sponsorAdIndex++;
                              }
                            }
                            return Column(children: feedItems);
                          }
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MultiStoryViewer extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int initialIndex;
  final Function(Map<String, dynamic>) onAction;

  const MultiStoryViewer({super.key, required this.stories, required this.initialIndex, required this.onAction});

  @override
  State<MultiStoryViewer> createState() => _MultiStoryViewerState();
}

class _MultiStoryViewerState extends State<MultiStoryViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleTap(TapUpDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;

    if (dx < screenWidth / 3) {
      if (_currentIndex > 0) {
        _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      } else {
        Navigator.pop(context);
      }
    } else {
      if (_currentIndex < widget.stories.length - 1) {
        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: _handleTap,
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemCount: widget.stories.length,
          itemBuilder: (context, index) {
            final story = widget.stories[index];
            return Stack(
              fit: StackFit.expand,
              children: [
                InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: story['imageUrl'] ?? '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                    errorWidget: (context, url, error) => const Center(child: Icon(Icons.error, color: Colors.white)),
                  ),
                ),

                if (story['isActionable'] == true)
                  Positioned(
                    bottom: 0, left: 0, right: 0, height: 200,
                    child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.9), Colors.transparent]))),
                  ),

                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                        child: Row(
                          children: List.generate(widget.stories.length, (i) {
                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                height: 3,
                                decoration: BoxDecoration(
                                    color: i <= _currentIndex ? Colors.white : Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(2)
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: Text(story['title'] ?? 'Highlight', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
                          ),
                          IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 28), onPressed: () => Navigator.pop(context)),
                        ],
                      ),
                    ],
                  ),
                ),

                if (story['isActionable'] == true)
                  Positioned(
                    bottom: 40, left: 24, right: 24,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.95),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 10,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onAction(story);
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('VIEW OFFER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)),
                          SizedBox(width: 8),
                          Icon(Icons.keyboard_arrow_up, size: 18),
                        ],
                      ),
                    ),
                  )
              ],
            );
          },
        ),
      ),
    );
  }
}