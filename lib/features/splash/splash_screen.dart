import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../auth/login_screen.dart';
import '../main/main_layout.dart';
import '../auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconScale;
  late Animation<double> _iconRotate; // === NEW: TWIST ANIMATION ===
  late Animation<double> _rippleScale;
  late Animation<double> _rippleOpacity;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

    // 1. The Main Logo pops in smoothly and twists slightly into place
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.6, curve: Curves.easeOutBack)),
    );
    _iconRotate = Tween<double>(begin: -0.15, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.1, 0.6, curve: Curves.easeOutBack)),
    );

    // 2. The Luxury Ripple (expands massively while fading to 0)
    _rippleScale = Tween<double>(begin: 0.5, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.9, curve: Curves.easeOutQuart)),
    );
    _rippleOpacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.9, curve: Curves.easeOut)),
    );

    // 3. Cinematic Text Reveal (Slowly glides up while fading in)
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic)),
    );

    // START THE ENGINE: Run animations and fetch Firebase rules simultaneously
    _initializeSafeLaunch();
  }

  Future<void> _initializeSafeLaunch() async {
    try {
      final results = await Future.wait<dynamic>([
        _controller.forward().then((_) => null),
        FirebaseFirestore.instance.collection('store_settings').doc('app_control').get(),
        PackageInfo.fromPlatform(),
      ]);

      if (!mounted) return;

      final doc = results[1] as DocumentSnapshot;
      final packageInfo = results[2] as PackageInfo;

      final int currentBuildCode = int.tryParse(packageInfo.buildNumber) ?? 1;

      bool isMaintenance = false;
      String maintenanceMsg = "We are currently upgrading PG Mart. Please check back shortly!";
      int minVersionCode = 0;
      int latestVersionCode = 0;
      String playStoreUrl = "https://play.google.com/store/apps/details?id=com.pgmart.app";

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        isMaintenance = data['is_maintenance'] ?? false;
        maintenanceMsg = data['maintenance_msg'] ?? maintenanceMsg;
        minVersionCode = data['min_version_code'] ?? 0;
        latestVersionCode = data['latest_version_code'] ?? 0;
        playStoreUrl = data['play_store_url'] ?? playStoreUrl;
      }

      if (isMaintenance) {
        _lockScreen(
          title: "UNDER MAINTENANCE",
          message: maintenanceMsg,
          icon: Icons.engineering,
          buttonText: "RETRY",
          onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SplashScreen())),
        );
        return;
      }

      if (currentBuildCode < minVersionCode) {
        _lockScreen(
          title: "UPDATE REQUIRED",
          message: "This version is no longer supported. You must update to the latest version to continue shopping securely.",
          icon: Icons.system_update_alt,
          buttonText: "UPDATE NOW",
          onTap: () => _launchURL(playStoreUrl),
        );
        return;
      }

      if (currentBuildCode < latestVersionCode) {
        _showSoftUpdatePrompt(playStoreUrl);
        return;
      }

      _proceedToApp();

    } catch (e) {
      _proceedToApp();
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _proceedToApp() {
    if (!mounted) return;
    final isLoggedIn = ref.read(authStateProvider);
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 1000),
        pageBuilder: (context, animation, secondaryAnimation) => isLoggedIn ? const MainLayout() : const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _lockScreen({required String title, required String message, required IconData icon, required String buttonText, required VoidCallback onTap}) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
          backgroundColor: Colors.white,
          body: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 100, color: Theme.of(context).primaryColor),
                const SizedBox(height: 32),
                Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Text(message, style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5), textAlign: TextAlign.center),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: onTap,
                    child: Text(buttonText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSoftUpdatePrompt(String playStoreUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.new_releases, color: Colors.orange), SizedBox(width: 8), Text('Update Available')]),
        content: const Text('A faster and better version of PG Mart is available on the Play Store. Would you like to update now?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _proceedToApp();
            },
            child: const Text('NOT NOW', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            onPressed: () => _launchURL(playStoreUrl),
            child: const Text('UPDATE NOW', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 180,
              width: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _rippleScale.value,
                        child: Opacity(
                          opacity: _rippleOpacity.value,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // === UPGRADED LOGO ANIMATION (Scale + Twist) ===
                  ScaleTransition(
                    scale: _iconScale,
                    child: RotationTransition(
                      turns: _iconRotate,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white, // Keeps the blue logo visible against blue background
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 10))
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/splash.png', // === YOUR LOGO ===
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
            FadeTransition(
              opacity: _textFade,
              child: SlideTransition(
                position: _textSlide,
                child: const Column(
                  children: [
                    Text(
                      'PG MART',
                      style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 8),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'AFFORDABLE RATE. PREMIUM MART.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70, letterSpacing: 3),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}