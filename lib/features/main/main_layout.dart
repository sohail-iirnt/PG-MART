import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../home/home_screen.dart';
import '../categories/categories_screen.dart';
import '../profile/profile_screen.dart';
import '../offers/offers_tab_screen.dart';
import '../vocal_for_local/vocal_for_local_screen.dart';

// === NEW CART IMPORTS FOR STICKY FAB ===
import '../cart/providers/cart_provider.dart';
import '../cart/cart_screen.dart';

final bottomNavProvider = StateProvider<int>((ref) => 0);

final whatsappStreamProvider = StreamProvider<String>((ref) {
  return FirebaseFirestore.instance.collection('store_settings').doc('general').snapshots().map((doc) {
    if (doc.exists && doc.data() != null) {
      return doc.data()!['whatsappNumber'] ?? '';
    }
    return '';
  });
});

final vocalForLocalToggleProvider = StreamProvider<bool>((ref) {
  return FirebaseFirestore.instance
      .collection('store_settings')
      .doc('app_control')
      .snapshots()
      .map((doc) {
    if (doc.exists && doc.data() != null) {
      return doc.data()!['vocal_for_local_active'] ?? false;
    }
    return false;
  });
});

class MainLayout extends ConsumerWidget {
  const MainLayout({super.key});

  Future<void> _launchWhatsApp(BuildContext context, String phone) async {
    if (phone.isEmpty) {
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support line is currently offline.')));
      return;
    }
    final cleanedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final webUri = Uri.parse("https://wa.me/$cleanedPhone");
    try {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavProvider);
    final whatsappAsync = ref.watch(whatsappStreamProvider);
    final isLocalActive = ref.watch(vocalForLocalToggleProvider).value ?? false;

    // === FIX: WATCH THE CART STATE DIRECTLY FOR LIVE UPDATES ===
    // This ensures the button instantly appears/disappears when items are added/removed
    final cartItems = ref.watch(cartProvider);
    final hasItems = cartItems.isNotEmpty;

    List<Widget> screens = [
      const HomeScreen(),
      const CategoriesScreen(),
      const OffersTabScreen(),
    ];

    List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
      const BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined), activeIcon: Icon(Icons.grid_view), label: 'Categories'),
      const BottomNavigationBarItem(icon: Icon(Icons.local_offer_outlined), activeIcon: Icon(Icons.local_offer), label: 'Offers'),
    ];

    if (isLocalActive) {
      screens.add(const VocalForLocalScreen());
      navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.storefront_outlined), activeIcon: Icon(Icons.storefront), label: 'Local Hub'));
    }

    screens.add(const ProfileScreen());
    navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'));

    int safeIndex = currentIndex;
    if (safeIndex >= screens.length) {
      safeIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(bottomNavProvider.notifier).state = 0;
      });
    }

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: screens,
      ),

      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // === FIX: REDESIGNED TO BE A SMALL CIRCULAR BUTTON ===
          if (hasItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: FloatingActionButton(
                heroTag: 'sticky_cart_btn',
                backgroundColor: Theme.of(context).primaryColor,
                elevation: 6,
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())),
                child: const Icon(Icons.shopping_cart_checkout, color: Colors.white),
              ),
            ),

          // THE WHATSAPP SUPPORT ICON
          whatsappAsync.when(
            data: (whatsappNumber) {
              if (whatsappNumber.isEmpty) return const SizedBox.shrink();
              return FloatingActionButton(
                heroTag: 'whatsapp_support_btn',
                backgroundColor: Colors.green,
                elevation: 4,
                onPressed: () => _launchWhatsApp(context, whatsappNumber),
                child: const Icon(Icons.chat, color: Colors.white),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: BottomNavigationBar(
          currentIndex: safeIndex,
          onTap: (index) => ref.read(bottomNavProvider.notifier).state = index,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          elevation: 0,
          items: navItems,
        ),
      ),
    );
  }
}