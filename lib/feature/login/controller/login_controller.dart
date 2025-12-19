/*import 'package:flutter/material.dart';
import 'package:intelliqueue/feature/login/model/login_model.dart';
import 'package:intelliqueue/feature/login/repository/login_repostiroy.dart';

class LoginController {
  final LoginRepository _repository = LoginRepository();

  bool isLoading = false;

  Future<LoginResponse?> login({
    required BuildContext context,
    required String phone,
    required String password,
  }) async {
    try {
      isLoading = true;

      final response = await _repository.login(
        phone: phone,
        password: password,
      );

      // TODO: Save token to secure storage later
      debugPrint("TOKEN: ${response.token}");

      return response;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      return null;
    } finally {
      isLoading = false;
    }
  }
}
*/