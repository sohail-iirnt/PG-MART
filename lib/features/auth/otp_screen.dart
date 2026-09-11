import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main/main_layout.dart';
import 'providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeArea(
                  bottom: false,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_back, color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 40),
                        // === FIXED: WHITE BACKGROUND FOR BLUE PG MART LOGO ===
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset('assets/images/logo.png', height: 40, width: 40, fit: BoxFit.contain),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Secure\nVerification',
                          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Enter the 6-digit code sent to\n+91 ${widget.phone}',
                          style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: TextField(
                                  controller: _otpController,
                                  autofocus: true,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 28, letterSpacing: 24, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(
                                    hintText: '------',
                                    hintStyle: TextStyle(color: Colors.grey, letterSpacing: 24),
                                    counterText: '',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 24),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Didn't receive the code? ", style: TextStyle(color: Colors.grey)),
                                  TextButton(
                                    onPressed: () {}, // Add your resend logic here if needed
                                    child: Text('RESEND', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          Column(
                            children: [
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: () async {
                                    final code = _otpController.text.trim();

                                    if (code.length == 6) {
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                                      );

                                      try {
                                        final verificationId = ref.read(verificationIdProvider);

                                        PhoneAuthCredential credential = PhoneAuthProvider.credential(
                                          verificationId: verificationId!,
                                          smsCode: code,
                                        );

                                        final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

                                        if (userCredential.user != null) {
                                          final userRef = FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid);
                                          final userDoc = await userRef.get();

                                          if (!userDoc.exists) {
                                            await userRef.set({
                                              'name': 'PG Mart Customer',
                                              'phone': userCredential.user!.phoneNumber ?? '+91${widget.phone}',
                                              'email': '',
                                              'createdAt': FieldValue.serverTimestamp(),
                                            });
                                          }
                                        }

                                        ref.read(authStateProvider.notifier).state = true;
                                        if (mounted) {
                                          Navigator.pushAndRemoveUntil(
                                              context,
                                              MaterialPageRoute(builder: (context) => const MainLayout()),
                                                  (route) => false
                                          );
                                        }
                                        // === 🚨 FIXED: CATCHING THE SESSION-EXPIRED ERROR 🚨 ===
                                      } on FirebaseAuthException catch (e) {
                                        if (mounted) Navigator.pop(context);

                                        String errorMessage = 'Verification failed. Please try again.';
                                        if (e.code == 'session-expired') {
                                          errorMessage = 'The OTP has expired. Please go back and request a new one.';
                                        } else if (e.code == 'invalid-verification-code') {
                                          errorMessage = 'Invalid OTP. Please check the code and try again.';
                                        }

                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
                                        }
                                      } catch (e) {
                                        if (mounted) Navigator.pop(context);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                                        }
                                      }
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the 6-digit OTP'), backgroundColor: Colors.red));
                                    }
                                  },
                                  child: const Text('VERIFY & LOGIN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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