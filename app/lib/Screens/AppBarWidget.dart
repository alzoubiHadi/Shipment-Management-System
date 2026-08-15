import 'package:flutter/material.dart';

import '../API/config.dart';
import '../models/Appuser.dart';

class AppBarWidget extends StatelessWidget {
  final AppUser user;
  final String? subtitle;
  final List<Widget>? actions;

  const AppBarWidget({
    required this.user,
    this.subtitle,
    this.actions,
  });

  //  Safe helper method to get avatar initials
  String _getAvatarInitials() {
    // 1. Use avatarInitials if provided and not empty
    if (user.avatarInitials?.isNotEmpty == true) {
      return user.avatarInitials!;
    }
    // 2. Fallback to first character of name if name exists and not empty
    if (user.name?.isNotEmpty == true) {
      return user.name![0].toUpperCase();
    }
    // 3. Final fallback
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = user.role;

    final roleColor = switch (user.role.toLowerCase()) {
      "company" => AppColors.gold,
      "driver" => AppColors.info,
      "admin" => AppColors.error,
      _ => AppColors.muted,
    };

    return SliverAppBar(
      backgroundColor: AppColors.bg,
      floating: true,
      pinned: false,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Avatar
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.gold.withOpacity(0.4),
                width: 1.5,
              ),
              color: AppColors.surfaceHigh,
            ),
            child: Center(
              child: Text(
                //  Safe: uses helper method instead of direct indexing
                _getAvatarInitials(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle ?? 'Good ${_greeting()},',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
                Text(
                  //  Also guard user.name display in case it's null/empty
                  user.name?.isNotEmpty == true ? user.name! : 'Guest',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cream,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: roleColor.withOpacity(0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              roleLabel,
              style: TextStyle(
                fontSize: 10,
                color: roleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}