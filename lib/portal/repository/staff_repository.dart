import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intelliqueue/shared/api_config.dart';

class StaffRepository {
  String _extractMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) return decoded['detail'].toString();
    } catch (_) {}
    return fallback;
  }
  Future<Map<String, dynamic>> getContext(String staffId) async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/staff/context/$staffId'));
    if (res.statusCode != 200) throw Exception('Failed to load staff context');
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  Future<void> assignCounter({required String staffId, required String counterId}) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/staff/assign-counter'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'staffId': staffId, 'counterId': counterId}),
    );
    if (res.statusCode != 200) throw Exception('Failed to assign counter');
  }

  Future<Map<String, dynamic>> getQueue(String staffId) async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/staff/queue/$staffId'));
    if (res.statusCode != 200) throw Exception('Failed to load queue');
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  Future<Map<String, dynamic>> getOverview(String staffId) async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/staff/overview/$staffId'));
    if (res.statusCode != 200) {
      throw Exception(_extractMessage(res.body, 'Failed to load overview'));
    }
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  Future<String?> callNextV2(String staffId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/staff/call-next-v2')
        .replace(queryParameters: {'staffId': staffId});
    final res = await http.post(uri);
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Call Next failed'));
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['message'] != null) return decoded['message'].toString();
    } catch (_) {}
    return null;
  }

  Future<void> skip({required String staffId, required String counterId, required String bookingId}) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/staff/skip'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'staffId': staffId,
        'counterId': counterId,
        'branchId': '',
        'serviceId': '',
        'bookingId': bookingId,
      }),
    );
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Skip failed'));
  }

  Future<void> complete({required String staffId, required String counterId, required String bookingId}) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/staff/complete'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'staffId': staffId,
        'counterId': counterId,
        'branchId': '',
        'serviceId': '',
        'bookingId': bookingId,
      }),
    );
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Complete failed'));
  }

  Future<void> cancel({required String staffId, required String counterId, required String bookingId}) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/staff/cancel'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'staffId': staffId,
        'counterId': counterId,
        'branchId': '',
        'serviceId': '',
        'bookingId': bookingId,
      }),
    );
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Cancel failed'));
  }

  Future<void> callNow({required String staffId, required String counterId, required String bookingId}) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/staff/call-now'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'staffId': staffId,
        'counterId': counterId,
        'branchId': '',
        'serviceId': '',
        'bookingId': bookingId,
      }),
    );
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Call Now failed'));
  }

  Future<List<Map<String, dynamic>>> tokenListByStaff(String staffId) async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/staff/token-list-by-staff/$staffId'));
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Failed to load tokens'));
    final body = jsonDecode(res.body) as List;
    return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> sendNotification({
    required String staffId,
    required String title,
    required String message,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/staff/notifications-by-staff/$staffId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'subtitle': message,
        'type': 'staff_broadcast',
      }),
    );
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Failed to send notification'));
  }
}

