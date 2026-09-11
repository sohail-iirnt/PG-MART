import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

import '../cart/cart_screen.dart';
import 'widgets/product_skeleton.dart';
import '../cart/providers/cart_provider.dart';
import 'widgets/product_card.dart';
import '../search/search_screen.dart';
import '../categories/category_products_screen.dart';
import '../notifications/notifications_screen.dart';
import 'providers/products_provider.dart';
import '../offers/offer_products_screen.dart';
import '../orders/bulk_order_screen.dart';
import '../product_details/product_details_screen.dart';

// === ROUTING IMPORTS ===
import '../main/main_layout.dart';
import '../orders/orders_screen.dart';
import '../support/support_screen.dart';
import '../offers/offers_tab_screen.dart';
import '../vocal_for_local/vocal_for_local_screen.dart';

final homeCategoriesProvider = StreamProvider<QuerySnapshot>((ref) {
  return FirebaseFirestore.instance.collection('categories').where('isActive', isEqualTo: true).snapshots();
});

final homeBannersProvider = StreamProvider<QuerySnapshot>((ref) {
  return FirebaseFirestore.instance.collection('banners').where('isActive', isEqualTo: true).orderBy('createdAt', descending: true).snapshots();
});

final unreadNotificationsProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance.collection('notifications').orderBy('createdAt', descending: true).snapshots().map((snapshot) {
    int count = 0;
    final now = DateTime.now();
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['createdAt'] != null) {
        final createdAt = (data['createdAt'] as Timestamp).toDate();
        if (now.difference(createdAt).inHours < 24) count++;
      }
    }
    return count;
  });
});

final flashSaleProvider = StreamProvider<DocumentSnapshot>((ref) {
  return FirebaseFirestore.instance.collection('store_settings').doc('flash_sale').snapshots();
});

final activeInFeedAdsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance.collection('in_feed_ads').where('isActive', isEqualTo: true).snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final PageController _bannerController = PageController();
  final ScrollController _scrollController = ScrollController();
  Timer? _bannerTimer;
  int _bannerCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(paginatedProductsProvider.notifier).fetchMoreProducts();
      }
    });
    _startBannerTimer();
  }

  void _startBannerTimer() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_bannerCount > 0 && _bannerController.hasClients) {
        int nextPage = _bannerController.page!.round() + 1;
        if (nextPage >= _bannerCount) nextPage = 0;
        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 700),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  // === IN-APP SCREEN & SECTION ROUTING ===
  Future<void> _handleBannerClick(Map<String, dynamic> bannerData, WidgetRef ref) async {
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
            Navigator.push(context, MaterialPageRoute(builder: (_) => const VocalForLocalScreen()));
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

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveCategoriesAsync = ref.watch(homeCategoriesProvider);
    final liveBannersAsync = ref.watch(homeBannersProvider);
    final unreadCountAsync = ref.watch(unreadNotificationsProvider);
    final unreadCount = unreadCountAsync.value ?? 0;
    final paginatedState = ref.watch(paginatedProductsProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final int gridCrossAxisCount = screenWidth > 800 ? 4 : (screenWidth > 600 ? 3 : 2);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Very soft off-white background
      body: Column(
        children: [
          // === THEME 2: DEEP GRADIENT CURVED HEADER ===
          Container(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).primaryColor, const Color(0xFF1E3A8A)], // Deep primary to navy
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset('assets/images/logo.png', height: 34, width: 34, fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('PG MART', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.white)),
                          Text('Premium Choice, Less Rate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.8))),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Badge(
                        label: Text(unreadCount.toString()), isLabelVisible: unreadCount > 0, backgroundColor: Colors.orangeAccent,
                        child: const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 28),
                      ),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
                    ),
                    IconButton(
                      icon: Badge(
                        label: Text(ref.watch(cartProvider.notifier).totalItems.toString()), isLabelVisible: ref.watch(cartProvider).isNotEmpty, backgroundColor: Colors.orangeAccent,
                        child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 28),
                      ),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // === THEME 2: INTEGRATED SEARCH BAR ===
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen())),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Icon(Icons.search_rounded, color: Colors.grey[400], size: 24),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Search groceries & dry fruits...', style: TextStyle(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.w500))),
                        Container(
                          margin: const EdgeInsets.all(6), width: 40,
                          decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.mic_none_rounded, color: Theme.of(context).primaryColor, size: 20),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  const FlashSaleTimerBanner(),

                  // === TOP BANNERS ===
                  liveBannersAsync.when(
                    loading: () => Container(
                      height: 160, margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(16)),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, stack) => const SizedBox(height: 160, child: Center(child: Text('Error loading banners'))),
                    data: (snapshot) {
                      if (snapshot.docs.isEmpty) return const SizedBox.shrink();
                      final allBanners = snapshot.docs.map((d) => d.data() as Map<String, dynamic>).toList();
                      final topBanners = allBanners.where((b) => (b['positionIndex'] ?? 0) == 0 && (b['screenTarget'] ?? 'home') == 'home').toList();
                      if (topBanners.isEmpty) return const SizedBox.shrink();
                      _bannerCount = topBanners.length;
                      return SizedBox(
                        height: 180, width: double.infinity,
                        child: PageView.builder(
                          controller: _bannerController,
                          itemCount: topBanners.length,
                          itemBuilder: (context, index) {
                            final banner = topBanners[index];
                            return GestureDetector(
                              onTap: () => _handleBannerClick(banner, ref),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                                  image: DecorationImage(image: CachedNetworkImageProvider(banner['imageUrl'] ?? ''), fit: BoxFit.cover),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),

                  // === WHATSAPP-STYLE STORIES ===
                  if (liveBannersAsync.value != null) ...[
                    Builder(builder: (context) {
                      final storyBanners = liveBannersAsync.value!.docs.map((d) => d.data() as Map<String, dynamic>).where((b) => (b['positionIndex'] ?? 0) == 1 && (b['screenTarget'] ?? 'home') == 'home').toList();
                      if (storyBanners.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Text('Trending Now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
                          ),
                          SizedBox(
                            height: 115,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: storyBanners.length,
                              itemBuilder: (context, index) {
                                final story = storyBanners[index];
                                return GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MultiStoryViewer(stories: storyBanners, initialIndex: index, onAction: (banner) => _handleBannerClick(banner, ref)))),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(colors: [Color(0xFFE11D48), Color(0xFFF59E0B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                            child: CircleAvatar(
                                              radius: 34, backgroundColor: Colors.grey[100],
                                              backgroundImage: CachedNetworkImageProvider(story['imageUrl'] ?? ''),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: 76,
                                          child: Text(story['title'] ?? 'Promo', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
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

                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('Shop by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
                  ),

                  // === THEME 2: SQUIRCLE CATEGORIES ===
                  SizedBox(
                    height: 125,
                    child: liveCategoriesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => const Center(child: Text('Error loading categories')),
                      data: (snapshot) {
                        final categories = snapshot.docs.toList();
                        categories.sort((a, b) {
                          final aData = a.data() as Map<String, dynamic>;
                          final bData = b.data() as Map<String, dynamic>;
                          return (aData['sortOrder'] ?? 99).compareTo(bData['sortOrder'] ?? 99);
                        });
                        if (categories.isEmpty) return const Center(child: Text('No categories found.'));
                        final List<MaterialColor> themeColors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red];
                        return ListView.builder(
                          scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 8), itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final catData = categories[index].data() as Map<String, dynamic>;
                            return CategoryLiveSquircle( // <--- Replaced Widget
                              title: catData['name'] ?? 'Unknown',
                              imageUrl: catData['imageUrl'] ?? '',
                              color: themeColors[index % themeColors.length],
                            );
                          },
                        );
                      },
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 12.0),
                    child: Row(
                      children: [
                        const Text('Saver Zones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
                        const SizedBox(width: 8),
                        Icon(Icons.discount_rounded, color: Colors.red[600], size: 22),
                      ],
                    ),
                  ),

                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 10),
                      children: const [
                        OfferCardPlaceholder(tier: 70, color1: Color(0xFFD32F2F), color2: Color(0xFFEF5350)),
                        OfferCardPlaceholder(tier: 50, color1: Color(0xFFE64A19), color2: Color(0xFFFF7043)),
                        OfferCardPlaceholder(tier: 25, color1: Color(0xFF7B1FA2), color2: Color(0xFFAB47BC)),
                        OfferCardPlaceholder(tier: 10, color1: Color(0xFF1976D2), color2: Color(0xFF42A5F5)),
                        BulkOrderCard(),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 28, 16, 16),
                    child: Text('Wholesale Market Feed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)),
                  ),

                  if (paginatedState.isLoadingInitial)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: GridView.builder(
                          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: gridCrossAxisCount * 2,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: gridCrossAxisCount, childAspectRatio: 0.65, crossAxisSpacing: 16, mainAxisSpacing: 16),
                          itemBuilder: (context, index) => const ProductSkeleton()
                      ),
                    )
                  else if (paginatedState.error != null && paginatedState.products.isEmpty)
                    const Center(child: Text('Could not load products. Please check connection.'))
                  else if (paginatedState.products.isEmpty)
                      const Padding(padding: EdgeInsets.all(30.0), child: Center(child: Text('No products available right now.', style: TextStyle(color: Colors.grey))))
                    else
                      Builder(
                          builder: (context) {
                            final rawProducts = paginatedState.products.toList();
                            final liveProducts = rawProducts.where((p) => p.visibilityScope != 'local').toList();
                            liveProducts.sort((a, b) {
                              final aTime = a.createdAt ?? DateTime.now();
                              final bTime = b.createdAt ?? DateTime.now();
                              int timeCompare = bTime.compareTo(aTime);
                              if (timeCompare == 0) return b.id.compareTo(a.id);
                              return timeCompare;
                            });

                            final allBanners = liveBannersAsync.value?.docs.map((d) => d.data() as Map<String, dynamic>).toList() ?? [];
                            final lowerBanners = allBanners.where((b) => b['positionIndex'] == 2 && (b['screenTarget'] ?? 'home') == 'home').toList();

                            final adsAsync = ref.watch(activeInFeedAdsProvider);
                            final allAds = adsAsync.valueOrNull ?? [];
                            final sponsorAds = allAds.where((ad) => (ad['screenTarget'] ?? 'home') == 'home').toList();

                            List<Widget> feedItems = [];
                            int lowerBannerIndex = 0;
                            int sponsorAdIndex = 0;

                            for (int i = 0; i < liveProducts.length; i += gridCrossAxisCount) {
                              List<Widget> rowChildren = [];
                              for (int j = 0; j < gridCrossAxisCount; j++) {
                                if (i + j < liveProducts.length) {
                                  // === THEME 2: FLAT BORDER PRODUCT CARDS ===
                                  rowChildren.add(
                                      Expanded(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: Colors.grey[200]!, width: 1.5),
                                            ),
                                            child: AspectRatio(aspectRatio: 0.65, child: ProductCard(product: liveProducts[i + j])),
                                          )
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
                                    onTap: () => _handleBannerClick(banner, ref),
                                    child: Container(
                                      height: 140, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        image: DecorationImage(image: CachedNetworkImageProvider(banner['imageUrl'] ?? ''), fit: BoxFit.cover),
                                      ),
                                    ),
                                  ),
                                );
                                lowerBannerIndex++;
                              }

                              if ((i + gridCrossAxisCount) % (gridCrossAxisCount * 3) == 0 && sponsorAds.isNotEmpty) {
                                final ad = sponsorAds[sponsorAdIndex % sponsorAds.length];
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
                                      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                      width: double.infinity, clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
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
                                                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                                                child: const Text('AD', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
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

                            if (paginatedState.isFetchingMore) {
                              feedItems.add(const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator())));
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
    );
  }
}

// === THEME 2: RE-STYLED SAVER ZONES ===
class OfferCardPlaceholder extends StatelessWidget {
  final int tier;
  final Color color1;
  final Color color2;
  const OfferCardPlaceholder({super.key, required this.tier, required this.color1, required this.color2});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OfferProductsScreen(discountTier: tier))),
      child: Container(
        width: 120, margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color1, color2]),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(right: -15, bottom: -20, child: Icon(Icons.flash_on, size: 80, color: Colors.white.withOpacity(0.2))),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('SAVE UP TO', style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('$tier% OFF', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.1)),
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

class BulkOrderCard extends StatelessWidget {
  const BulkOrderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BulkOrderScreen())),
      child: Container(
        width: 120, margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue[900]!, Colors.indigo[800]!]),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(right: -15, bottom: -15, child: Icon(Icons.business_center, size: 70, color: Colors.white.withOpacity(0.15))),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(6)),
                    child: const Text('B2B VIP', style: TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                  const Spacer(),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('BULK\nORDERS', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, height: 1.1)),
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

// === THEME 2: SQUIRCLE (Rounded Square) CATEGORIES ===
class CategoryLiveSquircle extends StatelessWidget {
  final String title;
  final String imageUrl;
  final Color color;
  const CategoryLiveSquircle({super.key, required this.title, required this.imageUrl, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryProductsScreen(categoryName: title))),
      child: Container(
        width: 85, margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20), // Highly rounded square
                border: Border.all(color: color.withOpacity(0.3), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 60, height: 60, color: Colors.white,
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
                      : Icon(Icons.category_rounded, color: color, size: 28),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black87), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// === THEME 2: DARK & SLEEK FLASH SALE ===
class FlashSaleTimerBanner extends ConsumerStatefulWidget {
  const FlashSaleTimerBanner({super.key});

  @override
  ConsumerState<FlashSaleTimerBanner> createState() => _FlashSaleTimerBannerState();
}

class _FlashSaleTimerBannerState extends ConsumerState<FlashSaleTimerBanner> {
  Timer? _timer;
  Duration _timeLeft = const Duration();
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _deadline != null) {
        setState(() {
          final now = DateTime.now();
          if (_deadline!.isAfter(now)) {
            _timeLeft = _deadline!.difference(now);
          } else {
            _timeLeft = const Duration();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildTimeBox(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(6)),
      child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final flashSaleAsync = ref.watch(flashSaleProvider);

    return flashSaleAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (snapshot) {
          if (!snapshot.exists || snapshot.data() == null) return const SizedBox.shrink();
          final data = snapshot.data() as Map<String, dynamic>;
          final isActive = data['isActive'] ?? false;
          final title = data['title'] ?? 'FLASH DROP';

          if (!isActive || data['deadline'] == null) return const SizedBox.shrink();
          _deadline = (data['deadline'] as Timestamp).toDate();

          final now = DateTime.now();
          if (now.isAfter(_deadline!)) return const SizedBox.shrink();

          _timeLeft = _deadline!.difference(now);
          String hours = _timeLeft.inHours.toString().padLeft(2, '0');
          String minutes = (_timeLeft.inMinutes % 60).toString().padLeft(2, '0');
          String seconds = (_timeLeft.inSeconds % 60).toString().padLeft(2, '0');

          return Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E), // Dark sleek background
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 6),
                          Flexible(child: Text(title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('Prices drop ends in:', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    _buildTimeBox(hours),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text(':', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16))),
                    _buildTimeBox(minutes),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text(':', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16))),
                    _buildTimeBox(seconds),
                  ],
                )
              ],
            ),
          );
        }
    );
  }
}

// === MULTI-STORY VIEWER MODULE ===
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
                    imageUrl: story['imageUrl'] ?? '', fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                    errorWidget: (context, url, error) => const Center(child: Icon(Icons.error, color: Colors.white)),
                  ),
                ),
                if (story['isActionable'] == true)
                  Positioned(bottom: 0, left: 0, right: 0, height: 200, child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.9), Colors.transparent])))),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                        child: Row(
                          children: List.generate(widget.stories.length, (i) {
                            return Expanded(
                              child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), height: 3, decoration: BoxDecoration(color: i <= _currentIndex ? Colors.white : Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                            );
                          }),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(padding: const EdgeInsets.only(left: 16.0), child: Text(story['title'] ?? 'Highlight', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]))),
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
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.95), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), elevation: 10),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onAction(story);
                      },
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('VIEW OFFER', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1)), SizedBox(width: 8), Icon(Icons.keyboard_arrow_up, size: 18)]),
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