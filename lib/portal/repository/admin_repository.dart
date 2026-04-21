import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intelliqueue/shared/api_config.dart';

class AdminRepository {
  String _extractMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) return decoded['detail'].toString();
    } catch (_) {}
    return fallback;
  }

  Future<List<Map<String, dynamic>>> listBranches() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/admin/branches'));
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Backend not reachable'));
    final body = jsonDecode(res.body) as List;
    return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> listServices({String? branchId}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/services')
        .replace(queryParameters: branchId == null ? null : {'branchId': branchId});
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Backend not reachable'));
    final body = jsonDecode(res.body) as List;
    return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> queuesSummary({String? branchId}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/queues-summary')
        .replace(queryParameters: branchId == null ? null : {'branchId': branchId});
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Backend not reachable'));
    final body = jsonDecode(res.body) as List;
    return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> upsertService({
    required String serviceId,
    required String branchId,
    required String name,
    required String category,
    required int defaultEtaMinutes,
    required bool isActive,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/admin/services'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'serviceId': serviceId,
        'branchId': branchId,
        'name': name,
        'category': category,
        'defaultEtaMinutes': defaultEtaMinutes,
        'isActive': isActive,
      }),
    );
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Failed to save'));
  }

  Future<void> deleteService(String serviceId) async {
    final res = await http.delete(Uri.parse('${ApiConfig.baseUrl}/admin/services/$serviceId'));
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Failed to delete'));
  }

  Future<List<Map<String, dynamic>>> listCounters({String? branchId, String? serviceId}) async {
    final qp = <String, String>{};
    if (branchId != null && branchId.isNotEmpty) qp['branchId'] = branchId;
    if (serviceId != null && serviceId.isNotEmpty) qp['serviceId'] = serviceId;
    final uri = Uri.parse('${ApiConfig.baseUrl}/admin/counters')
        .replace(queryParameters: qp.isEmpty ? null : qp);
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Backend not reachable'));
    final body = jsonDecode(res.body) as List;
    return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> listStaff() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/admin/staff'));
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Backend not reachable'));
    final body = jsonDecode(res.body) as List;
    return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> upsertStaff({
    required String staffId,
    required String name,
    required String email,
    required String role,
    required String status,
    required String password,
    String? assignedCounterId,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/admin/staff'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'staffId': staffId,
        'name': name,
        'email': email,
        'role': role,
        'status': status,
        'assignedCounterId': assignedCounterId,
        'password': password,
      }),
    );
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Failed to save'));
  }

  Future<void> deleteStaff(String staffId) async {
    final res = await http.delete(Uri.parse('${ApiConfig.baseUrl}/admin/staff/$staffId'));
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Failed to delete'));
  }

  Future<List<Map<String, dynamic>>> listCustomers() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/admin/customers'));
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Backend not reachable'));
    final body = jsonDecode(res.body) as List;
    return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> resetCustomerPassword({
    required String userPhone,
    required String newPassword,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/admin/customers/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userPhone': userPhone,
        'newPassword': newPassword,
      }),
    );
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Failed to reset'));
  }

  Future<void> resetDemoData() async {
    final res = await http.post(Uri.parse('${ApiConfig.baseUrl}/admin/reset-demo'));
    if (res.statusCode != 200) throw Exception(_extractMessage(res.body, 'Failed to reset demo'));
  }
}

