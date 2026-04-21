import 'package:flutter/material.dart';
import 'package:intelliqueue/feature/notifications/view/notifications_page.dart';
import 'package:intelliqueue/feature/profile/view/profile_page.dart';

class AppNav {
  static void openNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  static void openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
  }
}

