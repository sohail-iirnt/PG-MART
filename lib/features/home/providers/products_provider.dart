import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/product_model.dart';

// ============================================================================
// === PAGINATED STATE MODEL ===
// ============================================================================
class PaginatedProductsState {
  final List<ProductModel> products;
  final bool isLoadingInitial;
  final bool isFetchingMore;
  final bool hasMore;
  final String? error;

  PaginatedProductsState({
    this.products = const [],
    this.isLoadingInitial = true,
    this.isFetchingMore = false,
    this.hasMore = true,
    this.error,
  });

  PaginatedProductsState copyWith({
    List<ProductModel>? products,
    bool? isLoadingInitial,
    bool? isFetchingMore,
    bool? hasMore,
    String? error,
  }) {
    return PaginatedProductsState(
      products: products ?? this.products,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isFetchingMore: isFetchingMore ?? this.isFetchingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
    );
  }
}

// ============================================================================
// === REAL-TIME INFINITE SCROLL NOTIFIER ===
// ============================================================================
class PaginatedProductsNotifier extends StateNotifier<PaginatedProductsState> {
  PaginatedProductsNotifier() : super(PaginatedProductsState()) {
    _initStream();
  }

  int _currentLimit = 20;
  StreamSubscription<QuerySnapshot>? _subscription;

  // === THE FIX: DYNAMIC LIVE STREAM ===
  void _initStream() {
    _subscription?.cancel(); // Cancel old listener when expanding window

    _subscription = FirebaseFirestore.instance
        .collection('products')
        .orderBy('createdAt', descending: true)
        .limit(_currentLimit)
        .snapshots() // Listens live to Firebase!
        .listen((snapshot) {

      final unpackedProducts = _unpackProducts(snapshot.docs);

      if (mounted) {
        state = state.copyWith(
          products: unpackedProducts,
          isLoadingInitial: false,
          isFetchingMore: false,
          // If the snapshot returns exactly the limit, there might be more items
          hasMore: snapshot.docs.length == _currentLimit,
        );
      }
    }, onError: (e) {
      if (mounted) {
        state = state.copyWith(isLoadingInitial: false, isFetchingMore: false, error: e.toString());
      }
    });
  }

  Future<void> fetchMoreProducts() async {
    if (state.isFetchingMore || !state.hasMore) return;

    state = state.copyWith(isFetchingMore: true, error: null);
    _currentLimit += 20; // Expand the window by 20
    _initStream(); // Restart the stream with the larger window
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // === YOUR EXACT CUSTOM VARIANT UNPACKING LOGIC ===
  List<ProductModel> _unpackProducts(List<QueryDocumentSnapshot> docs) {
    List<ProductModel> unpackedProducts = [];

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      List<String> baseImageUrls = [];
      if (data['imageUrls'] != null) {
        baseImageUrls = List<String>.from(data['imageUrls']);
      } else if (data['imageUrl'] != null) {
        baseImageUrls = [data['imageUrl']];
      }

      final String primaryBaseImage = baseImageUrls.isNotEmpty ? baseImageUrls.first : 'https://via.placeholder.com/150';

      List<Map<String, dynamic>> parsedVariants = [];
      if (data['variants'] != null) {
        parsedVariants = List<Map<String, dynamic>>.from(data['variants']);
      }

      final bool hasVariants = data['hasVariants'] ?? false;
      final String customBaseName = data['baseVariantName'] ?? 'Main Pack';

      List<Map<String, dynamic>> combinedOptionsForUI = [];
      if (hasVariants) {
        combinedOptionsForUI.add({
          'name': customBaseName,
          'price': data['price'],
          'originalPrice': data['originalPrice'],
          'imageUrls': baseImageUrls,
          'isBase': true,
        });
        combinedOptionsForUI.addAll(parsedVariants);
      }

      final baseProduct = ProductModel(
        id: doc.id,
        name: data['name'] ?? 'Unknown Item',
        category: data['category'] ?? 'Uncategorized',
        imageUrl: primaryBaseImage,
        price: (data['price'] ?? 0).toDouble(),
        originalPrice: (data['originalPrice'] ?? 0).toDouble(),
        isAvailable: data['isAvailable'] ?? true,
        keywords: data['keywords'] ?? '',
        description: data['description'] ?? 'Premium wholesale quality from PG MART.',
        createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
        baseVariantName: customBaseName,
        imageUrls: baseImageUrls,
        hasVariants: hasVariants,
        variants: combinedOptionsForUI,
        // === FIX: Inject Visibility Scope & Seller Name ===
        visibilityScope: data['visibilityScope'] ?? 'both',
        sellerName: data['sellerName'],
      );

      unpackedProducts.add(baseProduct);

      if (hasVariants && parsedVariants.isNotEmpty) {
        for (int i = 0; i < parsedVariants.length; i++) {
          final variant = parsedVariants[i];
          final int uiIndex = i + 1;

          List<String> variantImages = [];
          if (variant['imageUrls'] != null && (variant['imageUrls'] as List).isNotEmpty) {
            variantImages = List<String>.from(variant['imageUrls']);
          } else if (variant['imageUrl'] != null) {
            variantImages = [variant['imageUrl']];
          } else {
            variantImages = baseImageUrls;
          }

          final unpackedVariantProduct = ProductModel(
            id: '${doc.id}_v_$uiIndex',
            name: '${data['name']} - ${variant['name']}',
            category: data['category'] ?? 'Uncategorized',
            imageUrl: variantImages.isNotEmpty ? variantImages.first : primaryBaseImage,
            price: (variant['price'] ?? 0).toDouble(),
            originalPrice: (variant['originalPrice'] ?? 0).toDouble(),
            isAvailable: data['isAvailable'] ?? true,
            keywords: '${data['keywords'] ?? ''}, ${variant['name']}',
            description: data['description'] ?? 'Premium wholesale quality from PG MART.',
            createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
            baseVariantName: customBaseName,
            imageUrls: variantImages,
            hasVariants: true,
            variants: combinedOptionsForUI,
            // === FIX: Inject Visibility Scope & Seller Name ===
            visibilityScope: data['visibilityScope'] ?? 'both',
            sellerName: data['sellerName'],
          );

          unpackedProducts.add(unpackedVariantProduct);
        }
      }
    }
    return unpackedProducts;
  }
}

// === EXPORT THE NEW PAGINATED PROVIDER ===
final paginatedProductsProvider = StateNotifierProvider<PaginatedProductsNotifier, PaginatedProductsState>((ref) {
  return PaginatedProductsNotifier();
});

// === OLD STREAM PROVIDER (KEPT TEMPORARILY FOR APP STABILITY) ===
final productsStreamProvider = StreamProvider<List<ProductModel>>((ref) {
  return FirebaseFirestore.instance.collection('products').snapshots().map((snapshot) {
    return PaginatedProductsNotifier()._unpackProducts(snapshot.docs);
  });
});

// === NEW: DEDICATED DIRECT FIRESTORE CATEGORY QUERY ===
final categoryProductsStreamProvider = StreamProvider.family<List<ProductModel>, String>((ref, categoryName) {
  return FirebaseFirestore.instance
      .collection('products')
      .where('category', isEqualTo: categoryName)
      .snapshots()
      .map((snapshot) {
    return PaginatedProductsNotifier()._unpackProducts(snapshot.docs);
  });
});