import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intelliqueue/portal/data/portal_session.dart';
import 'package:intelliqueue/shared/api_config.dart';

class PortalAuthRepository {
  Future<PortalSession> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (res.statusCode != 200) {
      String msg = 'Login failed';
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['detail'] != null) msg = body['detail'].toString();
      } catch (_) {}
      throw Exception(msg);
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return PortalSession(
      staffId: (body['staffId'] ?? '').toString(),
      email: (body['email'] ?? '').toString(),
      name: (body['name'] ?? '').toString(),
      role: (body['role'] ?? '').toString(),
      assignedCounterId: body['assignedCounterId']?.toString(),
      assignedCounterName: body['assignedCounterName']?.toString(),
      assignedServiceName: body['assignedServiceName']?.toString(),
    );
  }
}

