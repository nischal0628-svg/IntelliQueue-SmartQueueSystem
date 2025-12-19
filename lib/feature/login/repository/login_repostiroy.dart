/*import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intelliqueue/feature/login/model/login_model.dart';

class LoginRepository {
  final String baseUrl = "https://your-api-url.com"; // change later

  Future<LoginResponse> login({
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"phone": phone, "password": password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return LoginResponse.fromJson(data);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? "Login failed");
    }
  }
}
*/