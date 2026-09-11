import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/providers/auth_provider.dart'; // Add this line!

class AddressModel {
  final String id;
  final String title;
  final String fullAddress;
  final String phone;

  AddressModel({required this.id, required this.title, required this.fullAddress, required this.phone});

  // Helper to convert Firebase data into our Flutter Model
  factory AddressModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AddressModel(
      id: doc.id,
      title: data['title'] ?? '',
      fullAddress: data['fullAddress'] ?? '',
      phone: data['phone'] ?? '',
    );
  }
}

// 1. LIVE FIREBASE STREAM FOR ADDRESSES
final addressStreamProvider = StreamProvider<List<AddressModel>>((ref) {
  // Watch the live Auth State!
  final authState = ref.watch(authStateChangesProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value([]); // Wipes data if logged out

      // Connects directly to the active user's folder
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => AddressModel.fromFirestore(doc)).toList());
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// 2. Holds the ID of the currently selected address for checkout
final selectedAddressProvider = StateProvider<String?>((ref) => null);