import 'dart:convert';

import 'package:intelliqueue/portal/data/portal_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PortalSessionStore {
  static const _key = 'portal_session_v1';

  static Future<PortalSession?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return PortalSession(
        staffId: (map['staffId'] ?? '').toString(),
        email: (map['email'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
        role: (map['role'] ?? '').toString(),
        assignedCounterId: map['assignedCounterId']?.toString(),
        assignedCounterName: map['assignedCounterName']?.toString(),
        assignedServiceName: map['assignedServiceName']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(PortalSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'staffId': session.staffId,
        'email': session.email,
        'name': session.name,
        'role': session.role,
        'assignedCounterId': session.assignedCounterId,
        'assignedCounterName': session.assignedCounterName,
        'assignedServiceName': session.assignedServiceName,
      }),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

