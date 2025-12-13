
// import 'package:first_flutter/models/user_model.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/token_service.dart';


class UserInfo {
  final String email;
  final String role;
  final String token;
  final String? firstname;
  final String? lastname;

  UserInfo({
    required this.email,
    required this.role,
    required this.token,
    this.firstname,
    this.lastname,
  });
}



class AuthService {
  static const String baseUrl = "https://traffic-system-2.onrender.com";
   static UserInfo? currentUser;  // 🔥 giữ user đăng nhập


  // 1️⃣ Send verification code
  static Future<bool> sendVerifyCode({
    required String email,
    required String firstname,
    required String lastname,
    required String password,
    required String retypePassword,
  }) async {
    final url = Uri.parse("$baseUrl/auth/register/send-code");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "firstname": firstname,
          "lastname": lastname,
          "password": password,
          "retype_password": retypePassword
        }),
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
  }) async {
    final url = Uri.parse("$baseUrl/auth/register/confirm");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "code": code,
        }),
      );

      print("Confirm status: ${response.statusCode}, body: ${response.body}");
      return response.statusCode == 200;
    } catch (e) {
      print("Confirm error: $e");
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
        // 🔥 LƯU TOKEN NGAY TẠI ĐÂY
      await TokenService.saveToken(token);
      // 2️⃣ GET /users/me -> lấy email + role
      final profileRes = await http.get(
        Uri.parse("$baseUrl/api/users/me"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (profileRes.statusCode != 200) return null;

      final profile = jsonDecode(profileRes.body);

      currentUser = UserInfo(
        email: profile["email"] ?? "",
        role: profile["role"] ?? "",
        token: token,
        firstname: profile["firstname"] ?? "",
        lastname: profile["lastname"] ?? "",
        );


      
      return currentUser;

    } catch (e) {
      print("Login error: $e");
      return null;
    }
  }
// change password//

  static Future<void> changePassword({
  required String oldPassword,
  required String newPassword,
  required String retypePassword,
}) async {

  final token = await TokenService.getToken(); // <-- Lấy JWT đã đăng nhập
  
  if (token == null) throw "Bạn chưa đăng nhập";
  print("TOKEN hiện tại: $token"); // DEBUG
  final url = Uri.parse("$baseUrl/auth/password/change"); // <-- FIX URL

  final response = await http.post(
    url,
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    },
    body: jsonEncode({
      "old_password": oldPassword,
      "new_password": newPassword,
      "retype_password": retypePassword,
    }),
  );

  if (response.statusCode != 200) {
    try {
      throw jsonDecode(response.body)["detail"];
    } catch (e) {
      throw "Đổi mật khẩu thất bại";
    }
  }
}

}

