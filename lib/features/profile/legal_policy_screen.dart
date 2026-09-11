import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalPolicyScreen extends StatelessWidget {
  final String pageType; // 'Privacy', 'Terms', 'Refund', or 'DeleteAccount'
  const LegalPolicyScreen({super.key, required this.pageType});

  Future<void> _launchURL(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = '';
    String summary = '';
    String hostedUrl = 'https://sohail-iirnt.github.io/pg-mart-legal/';

    if (pageType == 'Privacy') {
      title = 'Privacy Policy';
      summary = 'We value your privacy. We collect basic details (Phone, Address) strictly to fulfill your orders in Bhiwandi. We never sell your data.';
      hostedUrl = 'https://sohail-iirnt.github.io/pg-mart-legal/privacy.html';
    } else if (pageType == 'Terms') {
      title = 'Terms & Conditions';
      summary = 'By using PG Mart, you agree to our platform rules. We cater specifically to bulk wholesale orders and reserve the right to verify business requirements.';
      hostedUrl = 'https://sohail-iirnt.github.io/pg-mart-legal/terms.html';
    } else if (pageType == 'Refund') {
      title = 'Refund & Cancellation';
      summary = 'Returns are accepted under specific conditions for dry goods. Please review our full policy for eligibility and timeline details.';
      // Pointing to Terms as a fallback since a dedicated refund page wasn't generated
      hostedUrl = 'https://sohail-iirnt.github.io/pg-mart-legal/terms.html';
    } else if (pageType == 'DeleteAccount') {
      title = 'Account Deletion';
      summary = 'You can request to permanently delete your PG Mart account and all associated personal data.';
      hostedUrl = 'https://sohail-iirnt.github.io/pg-mart-legal/delete-account.html';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(child: Text(summary, style: TextStyle(color: Colors.blue[900], height: 1.4))),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.open_in_browser, color: Colors.white),
                label: const Text('READ FULL POLICY ONLINE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () => _launchURL(context, hostedUrl),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}