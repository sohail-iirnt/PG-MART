import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

// === STREAM THE LIVE CONTACT SETTINGS FROM FIREBASE ===
final supportSettingsProvider = StreamProvider<DocumentSnapshot>((ref) =>
    FirebaseFirestore.instance.collection('store_settings').doc('general').snapshots());

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  // Action Helpers
  Future<void> _launchWhatsApp(BuildContext context, String phone) async {
    if (phone.isEmpty) return;
    final cleanedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse("https://wa.me/$cleanedPhone");

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')));
    }
  }

  Future<void> _launchPhone(BuildContext context, String phone) async {
    if (phone.isEmpty) return;
    final cleanedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse("tel:$cleanedPhone");

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Phone Dialer.')));
    }
  }

  Future<void> _launchEmail(BuildContext context, String email) async {
    if (email.isEmpty) return;
    final uri = Uri.parse("mailto:$email");

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Email App.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(supportSettingsProvider);

    return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Customer Support', style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black)),
          elevation: 0,
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: settingsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, stack) =>
                Center(child: Text('Error loading contact details.',
                    style: TextStyle(color: Colors.red[300]))),
            data: (snapshot) {
              String storeName = "PG MART";
              String phone = "";
              String whatsapp = "";
              String email = "";

              if (snapshot.exists && snapshot.data() != null) {
                final data = snapshot.data() as Map<String, dynamic>;
                storeName = data['storeName'] ?? "PG MART";
                phone = data['supportPhone'] ?? "";
                whatsapp = data['whatsappNumber'] ?? "";
                email = data['supportEmail'] ?? "";
              }

              return SingleChildScrollView(
                child: Column(
                  children: [
                    // Header Banner
                    Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 40, horizontal: 20),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(color: Theme
                                .of(context)
                                .primaryColor
                                .withOpacity(0.1), shape: BoxShape.circle),
                            child: Icon(
                                Icons.support_agent, size: 60, color: Theme
                                .of(context)
                                .primaryColor),
                          ),
                          const SizedBox(height: 20),
                          const Text('How can we help you?', style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('The $storeName team is here to assist you.',
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Contact Cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          if (whatsapp.isNotEmpty)
                            _buildContactCard(
                              context,
                              icon: Icons.chat,
                              color: Colors.green,
                              title: 'Chat on WhatsApp',
                              subtitle: whatsapp,
                              btnText: 'MESSAGE',
                              onTap: () => _launchWhatsApp(context, whatsapp),
                            ),

                          if (phone.isNotEmpty)
                            _buildContactCard(
                              context,
                              icon: Icons.phone_in_talk,
                              color: Colors.blue,
                              title: 'Call Us',
                              subtitle: phone,
                              btnText: 'CALL',
                              onTap: () => _launchPhone(context, phone),
                            ),

                          if (email.isNotEmpty)
                            _buildContactCard(
                              context,
                              icon: Icons.email,
                              color: Colors.orange,
                              title: 'Send an Email',
                              subtitle: email,
                              btnText: 'EMAIL',
                              onTap: () => _launchEmail(context, email),
                            ),

                          if (whatsapp.isEmpty && phone.isEmpty &&
                              email.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text(
                                  'Support contact details will be updated soon.',
                                  textAlign: TextAlign.center, style: TextStyle(
                                  color: Colors.grey)),
                            )
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            }
        )
    );
  }

  Widget _buildContactCard(BuildContext context,
      {required IconData icon, required Color color, required String title, required String subtitle, required String btnText, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: onTap, // <--- FIXED: Changed from onTap to onPressed
              child: Text(btnText, style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
            )
          ],
        ),
      ),
    );
  }
}