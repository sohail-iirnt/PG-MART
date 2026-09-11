import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_analytics/firebase_analytics.dart'; // === NEW: ANALYTICS IMPORT ===
import '../../../models/product_model.dart';

class CartItem {
  final ProductModel product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  // === Convert to JSON for physical storage ===
  Map<String, dynamic> toJson() => {
    'product': {
      'id': product.id,
      'name': product.name,
      'description': product.description,
      'price': product.price,
      'originalPrice': product.originalPrice,
      'category': product.category,
      'imageUrl': product.imageUrl,
      'isAvailable': product.isAvailable,
      'keywords': product.keywords,
      'baseVariantName': product.baseVariantName,
      'createdAt': product.createdAt?.toIso8601String(),
      'imageUrls': product.imageUrls,
      'hasVariants': product.hasVariants,
      'variants': product.variants,
    },
    'quantity': quantity,
  };

  // === Rebuild from JSON when app opens ===
  factory CartItem.fromJson(Map<String, dynamic> json) {
    final p = json['product'];
    return CartItem(
      product: ProductModel(
        id: p['id'],
        name: p['name'],
        description: p['description'] ?? '',
        price: (p['price'] ?? 0).toDouble(),
        originalPrice: (p['originalPrice'] ?? 0).toDouble(),
        category: p['category'] ?? '',
        imageUrl: p['imageUrl'] ?? '',
        isAvailable: p['isAvailable'] ?? true,
        keywords: p['keywords'] ?? '',
        baseVariantName: p['baseVariantName'] ?? 'Main Pack',
        createdAt: p['createdAt'] != null ? DateTime.tryParse(p['createdAt']) : null,
        imageUrls: List<String>.from(p['imageUrls'] ?? []),
        hasVariants: p['hasVariants'] ?? false,
        variants: List<Map<String, dynamic>>.from(p['variants'] ?? []),
      ),
      quantity: json['quantity'] ?? 1,
    );
  }
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]) {
    _loadCart(); // Automatically load saved cart on startup
  }

  // === Load from Phone Hard Drive ===
  Future<void> _loadCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartString = prefs.getString('pg_mart_cart');
    if (cartString != null) {
      final List<dynamic> decodedData = jsonDecode(cartString);
      state = decodedData.map((item) => CartItem.fromJson(item)).toList();
    }
  }

  // === Save to Phone Hard Drive ===
  Future<void> _saveCart(List<CartItem> cartState) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(cartState.map((item) => item.toJson()).toList());
    await prefs.setString('pg_mart_cart', encodedData);
  }

  // Add Item
  void addToCart(ProductModel product) {
    final existingIndex = state.indexWhere((item) => item.product.id == product.id);
    if (existingIndex >= 0) {
      final newState = [...state];
      newState[existingIndex].quantity++;
      state = newState;
    } else {
      state = [...state, CartItem(product: product)];
    }

    // === NEW: FIREBASE ANALYTICS LOGGING ===
    FirebaseAnalytics.instance.logAddToCart(
      items: [
        AnalyticsEventItem(
          itemId: product.id,
          itemName: product.name,
          price: product.price,
        )
      ],
      value: product.price,
      currency: 'INR',
    );

    _saveCart(state); // Trigger Save
  }

  // Remove or Decrease Item
  void removeSingleItem(String productId) {
    final existingIndex = state.indexWhere((item) => item.product.id == productId);
    if (existingIndex >= 0) {
      final newState = [...state];
      if (newState[existingIndex].quantity > 1) {
        newState[existingIndex].quantity--;
        state = newState;
      } else {
        // Remove completely if quantity reaches 0
        state = newState.where((item) => item.product.id != productId).toList();
      }
    }
    _saveCart(state); // Trigger Save
  }

  // Clear Entire Cart
  void clearCart() {
    state = [];
    _saveCart(state); // Trigger Save
  }

  // Calculate Total Quantity
  int get totalItems {
    return state.fold(0, (sum, item) => sum + item.quantity);
  }

  int getItemQuantity(String productId) {
    final itemIndex = state.indexWhere((item) => item.product.id == productId);
    return itemIndex >= 0 ? state[itemIndex].quantity : 0;
  }

  // Calculate Total Bill
  double get totalPrice {
    return state.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});