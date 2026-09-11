import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final String category;
  final double originalPrice;
  final double price;
  final String imageUrl;
  final String description;
  final String keywords;
  final bool isAvailable;
  final DateTime? createdAt;
  final String baseVariantName;
  final List<String> imageUrls;
  final bool hasVariants;
  final List<Map<String, dynamic>> variants;

  // === VOCAL FOR LOCAL MARKETPLACE FIELDS ===
  final String visibilityScope; // 'main', 'local', or 'both'
  final String? sellerId;
  final String? sellerName; // e.g. "Homemade by Shabana"

  ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.originalPrice,
    required this.price,
    required this.imageUrl,
    required this.description,
    required this.keywords,
    required this.isAvailable,
    this.createdAt,
    this.baseVariantName = 'Main Pack',
    this.imageUrls = const [],
    this.hasVariants = false,
    this.variants = const [],
    this.visibilityScope = 'both',
    this.sellerId,
    this.sellerName,
  });

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    List<String> parsedImageUrls = [];
    if (data['imageUrls'] != null) {
      parsedImageUrls = List<String>.from(data['imageUrls']);
    } else if (data['imageUrl'] != null) {
      parsedImageUrls = [data['imageUrl']];
    }
    List<Map<String, dynamic>> parsedVariants = [];
    if (data['variants'] != null) {
      parsedVariants = List<Map<String, dynamic>>.from(data['variants']);
    }
    return ProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      originalPrice: (data['originalPrice'] ?? 0).toDouble(),
      price: (data['price'] ?? 0).toDouble(),
      imageUrl: parsedImageUrls.isNotEmpty ? parsedImageUrls.first : '',
      description: data['description'] ?? '',
      keywords: data['keywords'] ?? '',
      isAvailable: data['isAvailable'] ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      baseVariantName: data['baseVariantName'] ?? 'Main Pack',
      imageUrls: parsedImageUrls,
      hasVariants: data['hasVariants'] ?? false,
      variants: parsedVariants,
      visibilityScope: data['visibilityScope'] ?? 'both',
      sellerId: data['sellerId'],
      sellerName: data['sellerName'],
    );
  }
}