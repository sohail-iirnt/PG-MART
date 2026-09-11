import 'dart:convert';
import 'package:flutter/foundation.dart'; // This lets us check if we are on the Web
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:pg_mart/features/splash/splash_screen.dart';
import 'package:flutter/services.dart';
import 'features/notifications/notification_service.dart';

// === IMPORTS FOR TELEMETRY & NETWORK GUARD ===
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

// === 1. TOP-LEVEL BACKGROUND HANDLER ===
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Firebase already initialized natively; safe to ignore
  }
  debugPrint("Handling a background message: ${message.messageId}");
}

late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
late AndroidNotificationChannel channel;

// === NEW: THE GLOBAL NAVIGATOR KEY ===
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // === SAFE FIREBASE INITIALIZATION (PREVENTS DUPLICATE APP BLACK SCREEN CRASH) ===
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // === FIX: Calls the correct initialize method ===
    await NotificationService.initialize();
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      debugPrint('Firebase already initialized natively.');
    } else {
      rethrow;
    }
  }

  // === FIREBASE CRASHLYTICS INITIALIZATION (TELEMETRY) ===
  if (!kIsWeb) {
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // === 2. ACTIVATE APP CHECK (PLAY INTEGRITY) ===
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
    );
  }

  // === 3. SETUP PUSH NOTIFICATIONS ===
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  channel = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important order updates.',
    importance: Importance.high,
  );

  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // === FOREGROUND NOTIFICATION TAP HANDLER ===
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);

  // === PERFECTED FOR v22.0.1: Strictly using 'settings:' ===
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload != null) {
        final data = jsonDecode(response.payload!);
        NotificationService.handleDeepLink(data['linkType'], data['linkTarget']);
      }
    },
  );

  await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

  // === 4. SILENT FCM TOKEN CAPTURE ===
  FirebaseAuth.instance.authStateChanges().listen((User? user) async {
    if (user != null) {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
      }
    }
  });

  // === 5. LISTEN FOR FOREGROUND MESSAGES ===
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      // Create string payload to pass to tap handler
      final payload = jsonEncode({
        'linkType': message.data['linkType'] ?? 'None',
        'linkTarget': message.data['linkTarget'] ?? '',
      });

      // === PERFECTED FOR v22.0.1: Using Named Parameters for show() ===
      flutterLocalNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: payload,
      );
    }
  });

  runApp(
    const ProviderScope(
      child: PgMartApp(),
    ),
  );
}

// === PGMART APP ROOT WITH NETWORK GUARD ===
class PgMartApp extends StatefulWidget {
  const PgMartApp({super.key});

  @override
  State<PgMartApp> createState() => _PgMartAppState();
}

class _PgMartAppState extends State<PgMartApp> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _setupNetworkGuard();
  }

  void _setupNetworkGuard() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      if (_hasInternet != isConnected) {
        setState(() {
          _hasInternet = isConnected;
        });
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // <--- ATTACHED GLOBALLY
      title: 'PG MART',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2874F0),
        scaffoldBackgroundColor: Colors.grey[100],
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2874F0),
          secondary: const Color(0xFFFFE11B),
        ),
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2874F0),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            if (!_hasInternet)
              Positioned.fill(
                child: Container(
                  color: Colors.white,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 24),
                      const Text(
                        'You are offline',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          decoration: TextDecoration.none,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Please check your internet connection. PG Mart will automatically reconnect when your network returns.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            decoration: TextDecoration.none,
                            fontFamily: 'Inter',
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      const CircularProgressIndicator(strokeWidth: 3),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      home: const SplashScreen(),
    );
  }
}