import 'package:app/Screens/AddShipmentForm.dart';
import 'package:flutter/material.dart';

import '../API/DriverLocationReporter.dart';
import '../API/PushNotificationSetup.dart';
import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/NavItem.dart';


import 'AddShipmentOfferPage.dart';
import 'AdminBottomNav.dart';
import 'AdminDashboardScreen.dart';
import 'AdminDrawer.dart';
import 'AdminFinancePage.dart';
import 'CelebrateBottomNav.dart';
import 'CompanyBalancePage.dart';
import 'CompanyBottomNav.dart';
import 'CompanyDashboardScreen.dart';
import 'CompanyProfileScreen.dart';
import 'CompnayShipments.dart';
import 'DriverBalancePage.dart';
import 'DriverBottomNav.dart';
import 'DriverDashboardScreen.dart';
import 'DriverOffersPage.dart';
import 'PlaceholderPage.dart';
import 'Profile.dart';
import 'ApprovalsPage.dart';
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

  // Approvals tab (admin index 1, formerly "Registration Requests" /
  // RegistrationRequestsScreen — see ApprovalsPage's docblock for the
  // Unified Approvals redesign). _requestsSection picks which of the 3
  // Approvals tabs (registrations/renewals/changes) opens by default;
  // changing it swaps the ValueKey on ApprovalsPage below, forcing it to
  // rebuild on that section instead of keeping whatever section the admin
  // had open before.
  ApprovalSection _requestsSection = ApprovalSection.registrations;

  bool get _isAdmin =>
      widget.user.role == 'admin' || widget.user.role == 'super_admin' || widget.user.role == 'sub_admin';

  bool get _isCompany => widget.user.role == 'company';

  bool get _isDriver => widget.user.role == 'driver';

  void _goToRequests({ApprovalSection section = ApprovalSection.registrations}) {
    setState(() {
      _requestsSection = section;
      _selectedIndex = 1;
    });
  }

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
      // Driver redesign Phase 1 (2026-08-17 mockup): Home/Shipments/Wallet/
      // Profile — Wallet promoted to a top-level tab instead of being
      // buried two taps deep under Profile. "Shipments" keeps pointing at
      // DriverOffersPage (browse/accept available offers, same screen the
      // old "Offers" tab used) — Phase 2 restyles it with search/filters/
      // tabs per the mockup, not a new screen. Profile is unchanged until
      // Phase 5.
      case "driver":
        return [
          DriverDashboardScreen(user: widget.user, onOpenWallet: () => setState(() => _selectedIndex = 2)),

          const DriverOffersPage(),

          const DriverBalancePage(),

          Profile(user: widget.user),
        ];

      case "company":
        return [
          CompanyDashboardScreen(user: widget.user, onOpenShipments: () => setState(() => _selectedIndex = 1)),
          Compnayshipments(user: widget.user),
          const CompanyBalancePage(),
          CompanyProfileScreen(user: widget.user),
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
            onOpenApprovals: (section) => _goToRequests(section: section),
          ),
          ApprovalsPage(
            key: ValueKey('approvals-$_requestsSection'),
            user: widget.user,
            onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
            initialSection: _requestsSection,
          ),
          Shipmentpageadmin(user: widget.user),
          const AdminFinancePage(),
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

    // Admins navigate via a bottom nav (Dashboard/Requests/Shipments/
    // Finance/Menu) + a slide-out Drawer opened from "Menu" or the
    // dashboard's hamburger. The center "+" FAB shortcut into
    // SelectRequestTypeScreen was removed 2026-08-20 (redundant with the
    // Requests tab's own type/status filters) and replaced with a plain
    // Finance tab — promoted out of the drawer since managing payments is
    // as core a daily task as Requests/Shipments.
    if (_isAdmin) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: LightColors.bg,
        drawer: AdminDrawer(
          user: widget.user,
          currentTabIndex: safeIndex,
          onSelectTab: (i) {
            if (i == 1) {
              _goToRequests();
            } else if (i < pages.length) {
              setState(() => _selectedIndex = i);
            }
          },
        ),
        body: IndexedStack(
          index: safeIndex,
          children: pages,
        ),
        bottomNavigationBar: AdminBottomNav(
          selectedTab: switch (safeIndex) {
            1 => AdminNavTab.requests,
            2 => AdminNavTab.shipments,
            3 => AdminNavTab.finance,
            _ => AdminNavTab.dashboard,
          },
          onSelectTab: (tab) {
            switch (tab) {
              case AdminNavTab.dashboard:
                setState(() => _selectedIndex = 0);
                break;
              case AdminNavTab.requests:
                _goToRequests();
                break;
              case AdminNavTab.shipments:
                setState(() => _selectedIndex = 2);
                break;
              case AdminNavTab.finance:
                setState(() => _selectedIndex = 3);
                break;
            }
          },
          onMenu: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      );
    }

    // Company redesign Phase 1 (2026-08-17 mockup): Home/Shipments/+/
    // Finance/Profile bottom nav, mirroring AdminBottomNav's raised-FAB
    // layout. Only the Home tab is re-themed so far — Shipments/Finance/
    // Profile stay on the old dark theme until their own phases land.
    if (_isCompany) {
      return Scaffold(
        backgroundColor: LightColors.bg,
        body: IndexedStack(
          index: safeIndex,
          children: pages,
        ),
        bottomNavigationBar: CompanyBottomNav(
          selectedTab: switch (safeIndex) {
            1 => CompanyNavTab.shipments,
            2 => CompanyNavTab.finance,
            3 => CompanyNavTab.profile,
            _ => CompanyNavTab.home,
          },
          onSelectTab: (tab) {
            setState(() {
              _selectedIndex = switch (tab) {
                CompanyNavTab.home => 0,
                CompanyNavTab.shipments => 1,
                CompanyNavTab.finance => 2,
                CompanyNavTab.profile => 3,
              };
            });
          },
          onCreate: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddShipmentOfferPage()),
          ),
        ),
      );
    }

    // Driver redesign Phase 1 (2026-08-17 mockup): dedicated 4-tab bottom
    // nav (Home/Shipments/Wallet/Profile), replacing the old 3-tab
    // CelebrateBottomNav (Home/Offers/Profile). Stays on the dark AppColors
    // theme — the mockup itself is dark, and the user asked to improve the
    // existing workflow, not re-theme it like admin/company were.
    if (_isDriver) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: IndexedStack(
          index: safeIndex,
          children: pages,
        ),
        bottomNavigationBar: DriverBottomNav(
          selectedTab: switch (safeIndex) {
            1 => DriverNavTab.shipments,
            2 => DriverNavTab.wallet,
            3 => DriverNavTab.profile,
            _ => DriverNavTab.home,
          },
          onSelectTab: (tab) {
            setState(() {
              _selectedIndex = switch (tab) {
                DriverNavTab.home => 0,
                DriverNavTab.shipments => 1,
                DriverNavTab.wallet => 2,
                DriverNavTab.profile => 3,
              };
            });
          },
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