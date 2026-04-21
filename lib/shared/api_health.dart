import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intelliqueue/shared/api_config.dart';

class ApiHealth {
  static Future<bool> check() async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/health'));
    if (res.statusCode != 200) return false;
    final body = jsonDecode(res.body);
    return body is Map && body['status'] == 'ok';
  }
}

