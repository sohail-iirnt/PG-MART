import 'package:cloud_firestore/cloud_firestore.dart';

class LocalSellerModel {
  final String id;
  final String userId;
  final String creatorName;
  final String brandName;
  final String phone;
  final String area;
  final String category;
  final String? fssaiNumber;
  final String? instagramId; // === NEW: Optional Instagram ID ===
  final String bio;
  final String status; // 'pending', 'approved', 'rejected'
  final List<String> sampleImages;
  final bool isFeatured;
  final DateTime? createdAt;

  LocalSellerModel({
    required this.id,
    required this.userId,
    required this.creatorName,
    required this.brandName,
    required this.phone,
    required this.area,
    required this.category,
    this.fssaiNumber,
    this.instagramId,
    required this.bio,
    this.status = 'pending',
    this.sampleImages = const [],
    this.isFeatured = false,
    this.createdAt,
  });

  factory LocalSellerModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LocalSellerModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      brandName: data['brandName'] ?? '',
      phone: data['phone'] ?? '',
      area: data['area'] ?? '',
      category: data['category'] ?? 'General',
      fssaiNumber: data['fssaiNumber'],
      instagramId: data['instagramId'],
      bio: data['bio'] ?? '',
      status: data['status'] ?? 'pending',
      sampleImages: List<String>.from(data['sampleImages'] ?? []),
      isFeatured: data['isFeatured'] ?? false,
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'creatorName': creatorName,
      'brandName': brandName,
      'phone': phone,
      'area': area,
      'category': category,
      'fssaiNumber': fssaiNumber,
      'instagramId': instagramId,
      'bio': bio,
      'status': status,
      'sampleImages': sampleImages,
      'isFeatured': isFeatured,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}