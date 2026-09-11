import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String phone;
  final String? name;
  final List<Map<String, dynamic>> savedAddresses;
  final String fcmToken;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.phone,
    this.name,
    this.savedAddresses = const [],
    required this.fcmToken,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      phone: map['phone'] ?? '',
      name: map['name'],
      savedAddresses: List<Map<String, dynamic>>.from(map['savedAddresses'] ?? []),
      fcmToken: map['fcmToken'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'name': name,
      'savedAddresses': savedAddresses,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}