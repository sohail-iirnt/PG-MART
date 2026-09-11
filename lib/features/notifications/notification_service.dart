import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../main.dart'; // To access navigatorKey
import '../../../models/product_model.dart';
import '../product_details/product_details_screen.dart';

class NotificationService {

  static Future<void> initialize() async {
    // 1. App in Background (User taps notification in status bar)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final String linkType = message.data['linkType'] ?? 'None';
      final String linkTarget = message.data['linkTarget'] ?? '';

      if (linkType != 'None' && linkTarget.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          handleDeepLink(linkType, linkTarget);
        });
      }
    });

    // 2. App Terminated (App was completely closed, user taps notification)
    final RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      final String linkType = initialMessage.data['linkType'] ?? 'None';
      final String linkTarget = initialMessage.data['linkTarget'] ?? '';

      if (linkType != 'None' && linkTarget.isNotEmpty) {
        // === WAIT 3 SECONDS FOR SPLASH SCREEN TO FINISH ===
        Future.delayed(const Duration(milliseconds: 3000), () {
          handleDeepLink(linkType, linkTarget);
        });
      }
    }
  }

  // === GENERIC DEEP LINK ROUTER ===
  static Future<void> handleDeepLink(String? linkType, String? linkTarget) async {
    if (linkType == null || linkType == 'None' || linkTarget == null || linkTarget.isEmpty) {
      return;
    }

    try {
      // 1. Wait for Navigator to mount (Smart Navigator)
      int retries = 0;
      while (navigatorKey.currentState == null && retries < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        retries++;
      }

      if (navigatorKey.currentState == null) {
        debugPrint("Failed to route: Navigator key is null.");
        return;
      }

      // 2. Route based on Link Type
      switch (linkType) {
        case 'Product':
          final doc = await FirebaseFirestore.instance.collection('products').doc(linkTarget).get();
          if (doc.exists && doc.data() != null) {
            final product = ProductModel.fromFirestore(doc);
            navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product)));
          }
          break;

        case 'Category':
        // Replace with your actual Category Screen route
        // navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => CategoryScreen(categoryId: linkTarget)));
          debugPrint("Routing to Category: $linkTarget");
          break;

        case 'Section':
        // Replace with your actual Section Screen route
          debugPrint("Routing to Section: $linkTarget");
          break;

        case 'Page':
        // Replace with your actual Page Screen route
          debugPrint("Routing to Page: $linkTarget");
          break;

        default:
          debugPrint("Unknown Link Type: $linkType");
      }
    } catch (e) {
      debugPrint("Deep link navigation error: $e");
    }
  }
}