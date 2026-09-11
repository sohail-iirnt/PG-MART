import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// IMPORT YOUR MODULES HERE
import 'modules/admin_analytics_module.dart';
import 'modules/admin_orders_module.dart';
import 'modules/admin_inventory_module.dart';
import 'modules/admin_categories_module.dart';
import 'modules/admin_banners_module.dart';
import 'modules/admin_coupons_module.dart';
import 'modules/admin_fees_module.dart';
import 'modules/admin_settings_module.dart';
import 'modules/admin_users_module.dart';
import 'modules/admin_notifications_module.dart';
import 'modules/admin_bulk_orders_module.dart';
import 'modules/admin_flash_sale_module.dart';
import 'modules/admin_ads_module.dart';
import 'modules/admin_local_sellers_module.dart'; // === NEW: B1D ENTREPRENEURS MODULE ===

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedIndex = 1; // Defaults to Live Orders

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: isDesktop ? null : AppBar(
        title: const Text('Command Center', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: Colors.indigo[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: isDesktop ? null : Drawer(child: _buildSidebar(isMobile: true)),
      body: isDesktop
          ? Row(
        children: [
          _buildSidebar(isMobile: false),
          Expanded(child: _buildMainContent(isDesktop)),
        ],
      )
          : _buildMainContent(isDesktop),
    );
  }

  Widget _buildSidebar({required bool isMobile}) {
    return Container(
      width: 250,
      color: Colors.indigo[900],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 40, 24, 20),
            child: Text('PG MART\nWorkspace', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.2)),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSidebarItem(0, Icons.dashboard, 'Dashboard Overview', isMobile),
                _buildSidebarItem(1, Icons.list_alt, 'Live Orders', isMobile),
                _buildSidebarItem(10, Icons.handshake, 'Bulk Leads', isMobile),
                _buildSidebarItem(13, Icons.storefront, 'B1D Entrepreneurs', isMobile), // === NEW: SIDEBAR ITEM ===
                _buildSidebarItem(2, Icons.inventory_2, 'Inventory', isMobile),
                _buildSidebarItem(3, Icons.category, 'Categories Setup', isMobile),
                _buildSidebarItem(4, Icons.view_carousel, 'Banners & Offers', isMobile),
                _buildSidebarItem(12, Icons.ad_units, 'In-Feed Ads', isMobile),
                _buildSidebarItem(5, Icons.local_activity, 'Promo Coupons', isMobile),
                _buildSidebarItem(11, Icons.flash_on, 'Flash Sale Manager', isMobile),
                _buildSidebarItem(6, Icons.account_balance_wallet, 'Fees & Taxes', isMobile),
                _buildSidebarItem(7, Icons.people, 'User Management', isMobile),
                _buildSidebarItem(8, Icons.notifications_active, 'Push Notifications', isMobile),
                _buildSidebarItem(9, Icons.settings, 'Store Settings', isMobile),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            title: const Text('Exit Admin', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title, bool isMobile) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Icon(icon, color: isSelected ? Colors.white : Colors.white54, size: 22),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
      tileColor: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
      onTap: () {
        setState(() => _selectedIndex = index);
        if (isMobile) Navigator.pop(context);
      },
    );
  }

  Widget _buildMainContent(bool isDesktop) {
    return Padding(
      padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop) ...[
            Text(_getAppbarTitle(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
          ],
          // === THE ROUTER SWITCH ===
          Expanded(
            child: _getModuleWidget(isDesktop),
          ),
        ],
      ),
    );
  }

  Widget _getModuleWidget(bool isDesktop) {
    switch (_selectedIndex) {
      case 0: return AdminAnalyticsModule(isDesktop: isDesktop);
      case 1: return AdminOrdersModule(isDesktop: isDesktop);
      case 2: return AdminInventoryModule(isDesktop: isDesktop);
      case 3: return AdminCategoriesModule(isDesktop: isDesktop);
      case 4: return AdminBannersModule(isDesktop: isDesktop);
      case 5: return AdminCouponsModule(isDesktop: isDesktop);
      case 6: return AdminFeesModule(isDesktop: isDesktop);
      case 7: return AdminUsersModule(isDesktop: isDesktop);
      case 8: return AdminNotificationsModule(isDesktop: isDesktop);
      case 9: return AdminSettingsModule(isDesktop: isDesktop);
      case 10: return const AdminBulkOrdersModule();
      case 11: return const AdminFlashSaleModule();
      case 12: return const AdminAdsModule();
      case 13: return const AdminLocalSellersModule(); // === NEW: ROUTER SWITCH ===
      default: return _buildUnderConstruction();
    }
  }

  Widget _buildUnderConstruction() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('${_getAppbarTitle()} Module', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(height: 8),
          const Text('Select this module from the menu to build next.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  String _getAppbarTitle() {
    switch (_selectedIndex) {
      case 0: return 'Dashboard Overview';
      case 1: return 'Live Orders Module';
      case 2: return 'Inventory Management';
      case 3: return 'Categories Setup';
      case 4: return 'Banners & Offers';
      case 5: return 'Promo Coupons';
      case 6: return 'Platform Fees & Taxes';
      case 7: return 'User Management';
      case 8: return 'Push Notifications';
      case 9: return 'Store Settings';
      case 10: return 'Bulk & Event Leads';
      case 11: return 'Flash Sale Manager';
      case 12: return 'In-Feed Ads Manager';
      case 13: return 'B1D Entrepreneurs Applications'; // === NEW: APPBAR TITLE ===
      default: return 'Admin Panel';
    }
  }
}