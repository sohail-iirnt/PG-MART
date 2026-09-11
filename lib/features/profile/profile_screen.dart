import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'providers/profile_provider.dart';
import 'edit_profile_screen.dart';
import '../address/address_screen.dart';
import '../orders/orders_screen.dart';
import '../support/support_screen.dart';
import '../auth/providers/auth_provider.dart';
import '../auth/login_screen.dart';
import '../wishlist/wishlist_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../cart/providers/cart_provider.dart';
import '../main/main_layout.dart';

import 'legal_policy_screen.dart';
import 'about_developer_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../vocal_for_local/seller_registration_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  // === IN-APP ACCOUNT DELETION PROTOCOL ===
  Future<void> _showDeleteAccountDialog(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Delete Account?')]),
        content: const Text('This action is permanent and cannot be undone. All your personal data, order history, and saved addresses will be permanently removed from our servers.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE PERMANENTLY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!context.mounted) return;
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)));

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // 1. Delete user data from Firestore
          await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
          // 2. Terminate Auth Identity
          await user.delete();
        }

        // 3. Clear Local Caches
        ref.invalidate(profileStreamProvider);
        ref.read(cartProvider.notifier).clearCart();
        ref.invalidate(bottomNavProvider);
        ref.read(authStateProvider.notifier).state = false;

        if (context.mounted) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
        }
      } on FirebaseAuthException catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
          if (e.code == 'requires-recent-login') {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Security Check: Please log out and log back in before deleting your account.'), backgroundColor: Colors.orange, duration: Duration(seconds: 4)));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Failed to delete account'), backgroundColor: Colors.red));
          }
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('System Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsyncValue = ref.watch(profileStreamProvider);
    final user = userAsyncValue.value ?? UserProfile(name: 'Loading...', phone: '');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('My Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Icon(Icons.person, size: 35, color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(user.phone, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        if (user.dob != null && user.dob!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('🎂 ${user.dob}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                        ]
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: Theme.of(context).primaryColor),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
                    },
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),

            _buildMenuSection(context, 'Shopping & Orders', [
              _buildMenuItem(context, Icons.local_shipping_outlined, 'My Orders', 'Track, return, or buy again', onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const OrdersScreen()));
              }),
              _buildMenuItem(context, Icons.location_on_outlined, 'Delivery Addresses', 'Manage Bhiwandi locations', onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AddressScreen()));
              }),
              _buildMenuItem(context, Icons.favorite_border, 'My Wishlist', 'Your saved items', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WishlistScreen()))),
            ]),

            const SizedBox(height: 16),

            // === B1D ENTREPRENEURS BANNER ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SellerRegistrationScreen())),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF8E24AA), Color(0xFFD81B60)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.storefront, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('B1D Entrepreneurs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5)),
                            SizedBox(height: 4),
                            Text('Sell your homemade products on PG Mart.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (user.phone.replaceAll(RegExp(r'[^0-9]'), '').contains('9112050119')) ...[
              _buildMenuSection(context, 'Admin Privileges', [
                _buildMenuItem(context, Icons.admin_panel_settings, 'Command Center', 'Manage orders & inventory', isDestructive: false, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
                }),
              ]),
              const SizedBox(height: 16),
            ],

            _buildMenuSection(context, 'About & Legal', [
              _buildMenuItem(context, Icons.policy_outlined, 'Privacy Policy', 'How we protect your data', onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const LegalPolicyScreen(pageType: 'Privacy')));
              }),
              _buildMenuItem(context, Icons.description_outlined, 'Terms & Conditions', 'App usage terms', onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const LegalPolicyScreen(pageType: 'Terms')));
              }),
              _buildMenuItem(context, Icons.currency_exchange_outlined, 'Refund & Cancellation', 'Our return policies', onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const LegalPolicyScreen(pageType: 'Refund')));
              }),
              _buildMenuItem(context, Icons.code, 'About the Developer', 'App development & IT Services', onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutDeveloperScreen()));
              }),
            ]),
            const SizedBox(height: 16),

            _buildMenuSection(context, 'Settings', [
              _buildMenuItem(context, Icons.support_agent, 'Customer Support', 'Help with your orders', onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportScreen()));
              }),

              // === ACCOUNT DELETION TRIGGER ===
              _buildMenuItem(context, Icons.delete_forever, 'Delete Account', 'Permanently remove your data', isDestructive: true, onTap: () => _showDeleteAccountDialog(context, ref)),

              _buildMenuItem(context, Icons.logout, 'Log Out', '', isDestructive: true, onTap: () async {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                );

                await FirebaseAuth.instance.signOut();
                ref.invalidate(profileStreamProvider);
                ref.read(cartProvider.notifier).clearCart();
                ref.invalidate(bottomNavProvider);
                ref.read(authStateProvider.notifier).state = false;

                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                  );
                }
              }),
            ]),
            const SizedBox(height: 10),
            // === APP VERSION DISPLAY ===
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'PG Mart v${snapshot.data!.version} (Build ${snapshot.data!.buildNumber})',
                        style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  // === 🚨 THE FIX IS HERE 🚨 ===
  // Changed "Container" to "Material" so ListTile ripple animations are not blocked!
  Widget _buildMenuSection(BuildContext context, String title, List<Widget> items) {
    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          ...items,
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, String subtitle, {bool isDestructive = false, required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red[50] : Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isDestructive ? Colors.red : Colors.black54),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDestructive ? Colors.red : Colors.black87)),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }
}