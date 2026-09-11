import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'otp_screen.dart';
import '../main/main_layout.dart';
import 'providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      if (userCredential.user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();
        if (!userDoc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
            'name': userCredential.user!.displayName ?? 'PG Mart Partner',
            'phone': userCredential.user!.phoneNumber ?? '',
            'email': userCredential.user!.email ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      ref.read(authStateProvider.notifier).state = true;
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainLayout()));
      }
    } catch (e) {
      setState(() => _isGoogleLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google Sign-In Failed: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: size.height),
          child: IntrinsicHeight(
            child: Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset('assets/images/logo.png', height: 60, width: 60, fit: BoxFit.contain),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text('PG MART', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1, letterSpacing: 1.5)),
                        const SizedBox(height: 12),
                        Text('Bhiwandi\'s Trending Online \nGrocery, Dry Fruits & Accessories Market.', style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8), height: 1.4)),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
                    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40))),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Welcome, Partner', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(height: 8),
                              const Text('Enter your mobile number to login or register your wholesale shop.', style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.4)),
                              const SizedBox(height: 32),

                              Container(
                                decoration: BoxDecoration(color: Colors.grey[50], border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(16)),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!))),
                                      child: Row(
                                        children: [
                                          const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                                          const SizedBox(width: 8),
                                          const Text('+91', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          const SizedBox(width: 4),
                                          Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey[600]),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.phone,
                                        maxLength: 10,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                                        decoration: const InputDecoration(hintText: '00000 00000', hintStyle: TextStyle(color: Colors.grey, fontWeight: FontWeight.normal, letterSpacing: 1), border: InputBorder.none, counterText: '', contentPadding: EdgeInsets.symmetric(horizontal: 16)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                  onPressed: () async {
                                    final phone = _phoneController.text.trim();

                                    if (phone.length == 10) {
                                      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)));

                                      final phoneNumber = '+91$phone';

                                      await FirebaseAuth.instance.verifyPhoneNumber(
                                        phoneNumber: phoneNumber,
                                        // === 🚨 THE FIX IS HERE 🚨 ===
                                        verificationCompleted: (PhoneAuthCredential credential) async {
                                          try {
                                            final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

                                            // Create user if they don't exist
                                            if (userCredential.user != null) {
                                              final userRef = FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid);
                                              final userDoc = await userRef.get();
                                              if (!userDoc.exists) {
                                                await userRef.set({
                                                  'name': 'PG Mart Partner',
                                                  'phone': userCredential.user!.phoneNumber ?? phoneNumber,
                                                  'email': '',
                                                  'createdAt': FieldValue.serverTimestamp(),
                                                });
                                              }
                                            }

                                            ref.read(authStateProvider.notifier).state = true;

                                            if (mounted) {
                                              // INSTANTLY clear the stack and push to MainLayout to prevent looping back!
                                              Navigator.pushAndRemoveUntil(
                                                context,
                                                MaterialPageRoute(builder: (context) => const MainLayout()),
                                                    (route) => false,
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              Navigator.pop(context); // Remove loading dialog if error
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification Error: $e')));
                                            }
                                          }
                                        },
                                        // === END FIX ===
                                        verificationFailed: (FirebaseAuthException e) {
                                          if (mounted) Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Verification Failed'), backgroundColor: Colors.red));
                                        },
                                        codeSent: (String verificationId, int? resendToken) {
                                          ref.read(verificationIdProvider.notifier).state = verificationId;
                                          if (mounted) Navigator.pop(context); // Remove Loading Dialog
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => OtpScreen(phone: phone)));
                                        },
                                        codeAutoRetrievalTimeout: (String verificationId) {},
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid 10-digit number'), backgroundColor: Colors.red));
                                    }
                                  },
                                  child: const Text('GET OTP', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                ),
                              ),

                              const SizedBox(height: 24),

                              Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                                  Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('OR', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.bold))),
                                  Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                                ],
                              ),

                              const SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                  onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                                  child: _isGoogleLoading
                                      ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Theme.of(context).primaryColor, strokeWidth: 2))
                                      : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.network('https://www.freepnglogos.com/uploads/google-logo-png/google-logo-icon-png-transparent-background-osteopathy-16.png', height: 24),
                                      const SizedBox(width: 12),
                                      const Text('Continue with Google', style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          Column(
                            children: [
                              const SizedBox(height: 16),
                              Center(
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: const TextSpan(
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                    children: [
                                      TextSpan(text: 'By continuing, you agree to our '),
                                      TextSpan(text: 'Terms of Service', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                      TextSpan(text: '\nand '),
                                      TextSpan(text: 'Privacy Policy', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}