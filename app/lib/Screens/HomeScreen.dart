import 'package:app/Screens/AddShipmentForm.dart';
import 'package:app/Screens/Driverspage.dart';
import 'package:flutter/material.dart';

import '../API/DriverLocationReporter.dart';
import '../API/PushNotificationSetup.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/NavItem.dart';


import 'AdminDashboardScreen.dart';
import 'AdminDrawer.dart';
import 'CelebrateBottomNav.dart';
import 'Companiespage.dart';
import 'CompanyOffersPage.dart';
import 'CompnayShipments.dart';
import 'DriverOffersPage.dart';
import 'PlaceholderPage.dart';
import 'Profile.dart';
import 'ReportsHomePage.dart';
import 'ShipmentOffersAdminPage.dart';
import 'ShipmentPageAdmin.dart';
import 'UserHomePage.dart';



class HomeScreen extends StatefulWidget {
  final AppUser user;

  const HomeScreen({
    super.key,
    required this.user,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _isAdmin =>
      widget.user.role == 'admin' || widget.user.role == 'super_admin' || widget.user.role == 'sub_admin';

  @override
  void initState() {
    super.initState();
    // Registers this device's FCM token (and requests notification
    // permission) once per authenticated session — HomeScreen is the one
    // screen every login/auto-login path always passes through.
    PushNotificationSetup.initialize();

    // Drivers request location access and share it periodically while the
    // app is open, so companies/admins can see them on the live tracking
    // map (ShipmentTrackingPage). Foreground-only — stopped in dispose()
    // below, never runs for company/admin accounts.
    if (widget.user.role == 'driver') {
      DriverLocationReporter.start();
    }
  }

  @override
  void dispose() {
    if (widget.user.role == 'driver') {
      DriverLocationReporter.stop();
    }
    super.dispose();
  }

  // NAV ITEMS
  List<NavItem> get _navItems {
    switch (widget.user.role) {
      case "driver":
        return [
          NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
          ),

          NavItem(
            icon: Icons.handshake_outlined,
            activeIcon: Icons.handshake_rounded,
            label: 'Offers',
          ),

          NavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person_rounded,
            label: 'Profile',
          ),
        ];

      case "company":
        return [
          NavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            label: 'Dashboard',
          ),

          NavItem(
            icon: Icons.handshake_outlined,
            activeIcon: Icons.handshake_rounded,
            label: 'Offers',
          ),

          NavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person_rounded,
            label: 'Profile',
          ),
        ];

      // Legacy seeded admin accounts use the literal 'admin' type; accounts
      // created via Phase 2's admin-management UI use 'super_admin' or
      // 'sub_admin' — all three get the same admin navigation.
      case "admin":
      case "super_admin":
      case "sub_admin":
        return [

          NavItem(
            icon: Icons.people_outline,
            activeIcon: Icons.people_rounded,
            label: 'Drivers',
          ),

          NavItem(
            icon: Icons.flag_outlined,
            activeIcon: Icons.flag_rounded,
            label: 'Companies',
          ),
          NavItem(
            icon: Icons.local_shipping_outlined,
            activeIcon: Icons.local_shipping_rounded,
            label: 'Shipments',
          ),
          NavItem(
            icon: Icons.handshake_outlined,
            activeIcon: Icons.handshake_rounded,
            label: 'Offers',
          ),
          NavItem(
            icon: Icons.bar_chart_outlined,
            activeIcon: Icons.bar_chart_rounded,
            label: 'Reports',
          ),
        ];

      default:
        return [
          NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
          ),
        ];
    }
  }

  // PAGES
  List<Widget> get _pages {
    switch (widget.user.role) {
      case "driver":
        return [
          UserHomePage(user: widget.user),

          const DriverOffersPage(),

          Profile(user: widget.user),
        ];

      case "company":
        return [
          Compnayshipments(user: widget.user),
          CompanyOffersPage(user: widget.user),
          Profile(user: widget.user),
        ];
//
//
      case "admin":
      case "super_admin":
      case "sub_admin":
        return [
          AdminDashboardScreen(
            user: widget.user,
            onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          Driverspage(user: widget.user),
          Companiespage(user: widget.user),
          Shipmentpageadmin(user: widget.user),
          const ShipmentOffersAdminPage(),
          ReportsHomePage(user: widget.user),
        ];

      default:
        return [
          UserHomePage(user: widget.user),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;

    // SAFE INDEX
    final safeIndex = _selectedIndex.clamp(
      0,
      pages.length - 1,
    );

    // Admins navigate via a slide-out Drawer (Phase 1 of the admin
    // dashboard redesign) instead of the bottom nav — the mockup's fixed
    // desktop sidebar, adapted to mobile.
    if (_isAdmin) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: LightColors.bg,
        drawer: AdminDrawer(
          user: widget.user,
          currentTabIndex: safeIndex,
          onSelectTab: (i) {
            if (i < pages.length) {
              setState(() {
                _selectedIndex = i;
              });
            }
          },
        ),
        body: IndexedStack(
          index: safeIndex,
          children: pages,
        ),
      );
    }

    final items = _navItems;

    return Scaffold(
      backgroundColor: AppColors.bg,

      body: IndexedStack(
        index: safeIndex,
        children: pages,
      ),

      bottomNavigationBar: CelebrateBottomNav(
        items: items,
        selectedIndex: safeIndex,
        onTap: (i) {
          if (i < pages.length) {
            setState(() {
              _selectedIndex = i;
            });
          }
        },
      ),
    );
  }
}