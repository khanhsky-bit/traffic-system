// import 'dart:convert';
import 'package:first_flutter/data/auth_service.dart';
import 'package:first_flutter/views/widgets/hero_widget.dart';
import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, required this.title});

  final String title;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _isObsecure = true;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController controllerEmail;
  late TextEditingController controllerPassword;
  late TextEditingController controllerRetypePassword;
  late TextEditingController controllerCode;

  bool codeSent = false;

  @override
  void initState() {
    super.initState();
    controllerEmail = TextEditingController();
    controllerPassword = TextEditingController();
    controllerRetypePassword = TextEditingController();
    controllerCode = TextEditingController();
  }

  @override
  void dispose() {
    controllerEmail.dispose();
    controllerPassword.dispose();
    controllerRetypePassword.dispose();
    controllerCode.dispose();
    super.dispose();
  }

  // Validation
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập email';
    final emailRegex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Email không hợp lệ';
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.length < 6) return 'Mật khẩu phải có ít nhất 6 ký tự';
    return null;
  }

  String? validateRetypePassword(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập lại mật khẩu';
    if (value != controllerPassword.text) return 'Mật khẩu không khớp';
    return null;
  }

  String? validateCode(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập code';
    return null;
  }

  // Gửi code xác thực
  void onPressedSendCode() async {
    if (_formKey.currentState!.validate()) {
      try {
        final success = await AuthService.sendVerifyCode(controllerEmail.text);
        if (success) {
          setState(() {
            codeSent = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Verification code sent to your email")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to send verification code")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }
  }

  // Confirm đăng ký
  void onPressedRegister() async {
    if (_formKey.currentState!.validate()) {
      try {
        final success = await AuthService.confirmRegister(
          email: controllerEmail.text,
          code: controllerCode.text,
          password: controllerPassword.text,
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Register success!"), backgroundColor: Colors.green),
          );
          Navigator.pop(context); // quay về login
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Register failed!")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double mediaWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: FractionallySizedBox(
              widthFactor: mediaWidth > 1000 ? 0.5 : 1,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    HeroWidget(title: widget.title),
                    const SizedBox(height: 20.0),
                    TextFormField(
                      controller: controllerEmail,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15.0),
                        ),
                      ),
                      validator: validateEmail,
                      enabled: !codeSent,
                    ),
                    const SizedBox(height: 10.0),
                    if (!codeSent)
                      ElevatedButton(
                        onPressed: onPressedSendCode,
                        child: const Text("Send Code"),
                      ),
                    if (codeSent) ...[
                      const SizedBox(height: 10.0),
                      TextFormField(
                        controller: controllerCode,
                        decoration: InputDecoration(
                          hintText: 'Verification Code',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                        ),
                        validator: validateCode,
                      ),
                      const SizedBox(height: 10.0),
                      TextFormField(
                        controller: controllerPassword,
                        obscureText: _isObsecure,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _isObsecure = !_isObsecure;
                              });
                            },
                            icon: Icon(
                              _isObsecure ? Icons.visibility : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: validatePassword,
                      ),
                      const SizedBox(height: 10.0),
                      TextFormField(
                        controller: controllerRetypePassword,
                        obscureText: _isObsecure,
                        decoration: InputDecoration(
                          hintText: 'Retype Password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15.0),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _isObsecure = !_isObsecure;
                              });
                            },
                            icon: Icon(
                              _isObsecure ? Icons.visibility : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: validateRetypePassword,
                      ),
                      const SizedBox(height: 20.0),
                      ElevatedButton(
                        onPressed: onPressedRegister,
                        child: const Text("Register"),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
