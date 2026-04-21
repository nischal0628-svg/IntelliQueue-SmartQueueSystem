import 'package:flutter/material.dart';
import 'package:intelliqueue/ui/app_nav.dart';

class AppScaffoldActions {
  static List<Widget> actions(BuildContext context) {
    return [
      IconButton(
        tooltip: 'Notifications',
        onPressed: () => AppNav.openNotifications(context),
        icon: const Icon(Icons.notifications_none),
      ),
      IconButton(
        tooltip: 'Profile',
        onPressed: () => AppNav.openProfile(context),
        icon: const Icon(Icons.person_outline),
      ),
      const SizedBox(width: 4),
    ];
  }
}

