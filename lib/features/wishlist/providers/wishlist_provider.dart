import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/product_model.dart';

class WishlistNotifier extends StateNotifier<List<ProductModel>> {
  WishlistNotifier() : super([]) {
    _loadWishlist(); // Load on startup
  }

  // === Convert Product to JSON for saving ===
  Map<String, dynamic> _productToJson(ProductModel product) => {
    'id': product.id,
    'name': product.name,
    'description': product.description,
    'price': product.price,
    'originalPrice': product.originalPrice,
    'category': product.category,
    'imageUrl': product.imageUrl,
    'isAvailable': product.isAvailable,
    'keywords': product.keywords,
    // === THE FIX: Saving the missing fields ===
    'baseVariantName': product.baseVariantName,
    'createdAt': product.createdAt?.toIso8601String(),
    'imageUrls': product.imageUrls,
    'hasVariants': product.hasVariants,
    'variants': product.variants,
  };

  // === Create Product from JSON ===
  ProductModel _productFromJson(Map<String, dynamic> p) {
    return ProductModel(
      id: p['id'],
      name: p['name'],
      description: p['description'] ?? '',
      price: (p['price'] ?? 0).toDouble(),
      originalPrice: (p['originalPrice'] ?? 0).toDouble(),
      category: p['category'] ?? '',
      imageUrl: p['imageUrl'] ?? '',
      isAvailable: p['isAvailable'] ?? true,
      keywords: p['keywords'] ?? '',
      // === THE FIX: Safely loading the missing fields ===
      baseVariantName: p['baseVariantName'] ?? 'Main Pack',
      createdAt: p['createdAt'] != null ? DateTime.tryParse(p['createdAt']) : null,
      imageUrls: List<String>.from(p['imageUrls'] ?? []),
      hasVariants: p['hasVariants'] ?? false,
      variants: List<Map<String, dynamic>>.from(p['variants'] ?? []),
    );
  }

  // === Storage Functions ===
  Future<void> _loadWishlist() async {
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString('pg_mart_wishlist');
    if (dataString != null) {
      final List<dynamic> decodedData = jsonDecode(dataString);
      state = decodedData.map((item) => _productFromJson(item)).toList();
    }
  }

  Future<void> _saveWishlist(List<ProductModel> currentWishlist) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(currentWishlist.map((p) => _productToJson(p)).toList());
    await prefs.setString('pg_mart_wishlist', encodedData);
  }

  // Toggle Logic
  void toggleWishlist(ProductModel product) {
    if (state.any((p) => p.id == product.id)) {
      // Remove if it already exists
      state = state.where((p) => p.id != product.id).toList();
    } else {
      // Add to wishlist
      state = [...state, product];
    }
    _saveWishlist(state); // Trigger Save
  }

  bool isInWishlist(String productId) {
    return state.any((p) => p.id == productId);
  }
}

final wishlistProvider = StateNotifierProvider<WishlistNotifier, List<ProductModel>>((ref) {
  return WishlistNotifier();
});