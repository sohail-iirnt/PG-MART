import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 1. Check real Firebase Auth State
final authStateProvider = StateProvider<bool>((ref) {
  return FirebaseAuth.instance.currentUser != null;
});

// 2. Temporarily holds the ID sent by Firebase via SMS
final verificationIdProvider = StateProvider<String?>((ref) => null);

// === 3. NEW: The Live Auth Stream for the entire app ===
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});