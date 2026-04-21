import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intelliqueue/shared/api_config.dart';

class AdminDashboardRepository {
  String _extractMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) return decoded['detail'].toString();
    } catch (_) {}
    return fallback;
  }

  Future<Map<String, dynamic>> overview() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/admin/overview'));
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Backend not reachable'));
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  Future<Map<String, dynamic>> analytics() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/admin/analytics'));
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Backend not reachable'));
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }
}

