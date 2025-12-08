// import 'package:first_flutter/models/user_model.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class UserInfo {
  final String email;
  final String role;
  final String token;

  UserInfo({required this.email, required this.role, required this.token});
}

class AuthService {
  static const String baseUrl = "http://127.0.0.1:8000";

  // 1️⃣ Send verification code
  static Future<bool> sendVerifyCode(String email) async {
    final url = Uri.parse("$baseUrl/auth/register/send-code");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );
      print("SendCode status: ${response.statusCode}, body: ${response.body}");
      return response.statusCode == 200;
    } catch (e) {
      print("SendCode error: $e");
      return false;
    }
  }

  // 2️⃣ Confirm registration
  static Future<bool> confirmRegister({
    required String email,
    required String code,
    required String password,
  }) async {
    final url = Uri.parse("$baseUrl/auth/register/confirm");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "code": code, "password": password}),
      );
      print(
        "ConfirmRegister status: ${response.statusCode}, body: ${response.body}",
      );
      return response.statusCode == 200;
    } catch (e) {
      print("ConfirmRegister error: $e");
      return false;
    }
  }

  //-------login----------
  static Future<UserInfo?> login(String email, String password) async {
    final url = Uri.parse("$baseUrl/auth/token");

    try {
      // 1️⃣ POST login -> nhận token
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {
          "username": email, // chú ý username
          "password": password,
        },
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final token = data["access_token"];

      // 2️⃣ GET /users/me -> lấy email + role
      final profileRes = await http.get(
        Uri.parse("$baseUrl/api/users/me"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (profileRes.statusCode != 200) return null;

      final profile = jsonDecode(profileRes.body);

      return UserInfo(
        email: profile["email"],
        role: profile["role"],
        token: token,
      );
    } catch (e) {
      print("Login error: $e");
      return null;
    }
  }
}
