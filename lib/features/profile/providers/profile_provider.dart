import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfile {
  final String name;
  final String phone;
  final String? dob;

  UserProfile({required this.name, required this.phone, this.dob});

  // Helper to convert Firebase data into our Flutter Model
  factory UserProfile.fromFirestore(Map<String, dynamic> data, String fallbackPhone) {
    return UserProfile(
      name: data['name'] ?? 'PG Mart Customer',
      phone: data['phone'] ?? fallbackPhone,
      dob: data['dob'],
    );
  }
}

// === NEW: Listen directly to Firebase Auth State ===
// This forces Riverpod to refresh the moment a user logs in or out
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// === UPDATED: Live Firebase Stream for User Profile ===
final profileStreamProvider = StreamProvider<UserProfile>((ref) {
  // 1. Watch the Auth State continuously
  final authState = ref.watch(authStateChangesProvider);

  // 2. React to changes instantly
  return authState.when(
    data: (user) {
      if (user == null) {
        // If no user is logged in, show Guest
        return Stream.value(UserProfile(name: 'Guest', phone: ''));
      }

      // If user IS logged in, fetch their specific permanent profile from Firestore
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data() as Map<String, dynamic>;
          return UserProfile.fromFirestore(data, user.phoneNumber ?? '');
        } else {
          // Fallback if they just registered and data hasn't synced yet
          return UserProfile(name: 'Complete Profile', phone: user.phoneNumber ?? '');
        }
      });
    },
    loading: () => Stream.value(UserProfile(name: 'Loading...', phone: '')),
    error: (_, __) => Stream.value(UserProfile(name: 'Error', phone: '')),
  );
});