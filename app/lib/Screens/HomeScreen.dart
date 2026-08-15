import 'package:app/Screens/AddShipmentForm.dart';
import 'package:app/Screens/Driverspage.dart';
import 'package:flutter/material.dart';

import '../API/config.dart';
import '../models/Appuser.dart';
import '../models/NavItem.dart';


import 'CelebrateBottomNav.dart';
import 'Companiespage.dart';
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
            icon: Icons.local_shipping_outlined,
            activeIcon: Icons.local_shipping_rounded,
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
            icon: Icons.person_outline,
            activeIcon: Icons.person_rounded,
            label: 'Profile',
          ),
        ];

      case "admin":
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
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: 'Shipments',
          ),
          NavItem(
            icon: Icons.local_shipping_outlined,
            activeIcon: Icons.local_shipping_rounded,
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
          Profile(user: widget.user),
        ];
//
//
      case "admin":
        return [
          Driverspage(user: widget.user),
          Companiespage(user: widget.user),
          Shipmentpageadmin(user: widget.user),
          const ShipmentOffersAdminPage(),
          const ReportsHomePage(),
        ];

      default:
        return [
          UserHomePage(user: widget.user),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _navItems;
    final pages = _pages;

    // SAFE INDEX
    final safeIndex = _selectedIndex.clamp(
      0,
      pages.length - 1,
    );

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