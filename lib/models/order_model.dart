import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String userId;
  final String userPhone;
  final String? riderId;
  final List<Map<String, dynamic>> items;
  final double itemTotal;
  final double deliveryFee;
  final double handlingFee;
  final double taxAmount;
  final double discountApplied;
  final double grandTotal;
  final String status;
  final String deliveryAddress;
  final String paymentMethod;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.userId,
    required this.userPhone,
    this.riderId,
    required this.items,
    required this.itemTotal,
    required this.deliveryFee,
    required this.handlingFee,
    required this.taxAmount,
    required this.discountApplied,
    required this.grandTotal,
    required this.status,
    required this.deliveryAddress,
    required this.paymentMethod,
    required this.createdAt,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String documentId) {
    return OrderModel(
      id: documentId,
      userId: map['userId'] ?? '',
      userPhone: map['userPhone'] ?? '',
      riderId: map['riderId'],
      items: List<Map<String, dynamic>>.from(map['items'] ?? []),
      itemTotal: (map['itemTotal'] ?? 0.0).toDouble(),
      deliveryFee: (map['deliveryFee'] ?? 0.0).toDouble(),
      handlingFee: (map['handlingFee'] ?? 0.0).toDouble(),
      taxAmount: (map['taxAmount'] ?? 0.0).toDouble(),
      discountApplied: (map['discountApplied'] ?? 0.0).toDouble(),
      grandTotal: (map['grandTotal'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'Placed',
      deliveryAddress: map['deliveryAddress'] ?? '',
      paymentMethod: map['paymentMethod'] ?? 'COD',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userPhone': userPhone,
      'riderId': riderId,
      'items': items,
      'itemTotal': itemTotal,
      'deliveryFee': deliveryFee,
      'handlingFee': handlingFee,
      'taxAmount': taxAmount,
      'discountApplied': discountApplied,
      'grandTotal': grandTotal,
      'status': status,
      'deliveryAddress': deliveryAddress,
      'paymentMethod': paymentMethod,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}