import 'package:flutter/material.dart';

class ChangePassword extends StatefulWidget {
  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  bool _isObsecure = true;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController controllerEmail;
  late TextEditingController controllerFirstName;
  late TextEditingController controllerLastName;
  late TextEditingController controllerPassword;
  late TextEditingController controllerRetypePassword;

  @override
  void initState() {
    super.initState();
    controllerEmail = TextEditingController();
    controllerFirstName = TextEditingController();
    controllerLastName = TextEditingController();
    controllerPassword = TextEditingController();
    controllerRetypePassword = TextEditingController();
  }

  @override
  void dispose() {
    controllerEmail.dispose();
    controllerPassword.dispose();
    controllerFirstName.dispose();
    controllerLastName.dispose();
    controllerRetypePassword.dispose();
    super.dispose();
  }

  // Hàm validate email
  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập email';
    }
    // Kiểm tra format email
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email không hợp lệ';
    }
    return null;
  }

  // Hàm validate tên
  String? validateName(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập $fieldName';
    }
    if (value.length < 2) {
      return '$fieldName phải có ít nhất 2 ký tự';
    }
    return null;
  }

  // Hàm validate password
  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập mật khẩu';
    }
    if (value.length < 6) {
      return 'Mật khẩu phải có ít nhất 6 ký tự';
    }
    return null;
  }

  // Hàm validate retype password
  String? validateRetypePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Vui lòng nhập lại mật khẩu';
    }
    if (value != controllerPassword.text) {
      return 'Mật khẩu không khớp';
    }
    return null;
  }

  // Hàm xử lý đăng ký
  void onPressedRegister() async {
    // Validate tất cả các field
    if (_formKey.currentState!.validate()) {
      // Hiển thị loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      try {
        // TODO: Gọi API để lưu vào database
        // Ví dụ:
        // await AuthService.register(
        //   email: controllerEmail.text,
        //   firstName: controllerFirstName.text,
        //   lastName: controllerLastName.text,
        //   password: controllerPassword.text,
        // );

        // Giả lập delay API call
        await Future.delayed(Duration(seconds: 2));

        // Đóng loading dialog
        Navigator.pop(context);

        // Hiển thị thông báo thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đăng ký thành công!'),
            backgroundColor: Colors.green,
          ),
        );

        // Quay về trang trước hoặc chuyển sang trang login
        Navigator.pop(context);
      } catch (e) {
        // Đóng loading dialog
        Navigator.pop(context);

        // Hiển thị lỗi
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đăng ký thất bại: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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
            child: LayoutBuilder(
              builder: (context, BoxConstraints constraints) {
                return FractionallySizedBox(
                  widthFactor: mediaWidth > 1000 ? 0.5 : 1,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // HeroWidget(title: widget.title),
                        // SizedBox(height: 20.0),

                        // Password field
                        TextFormField(
                          controller: controllerPassword,
                          obscureText: _isObsecure,
                          decoration: InputDecoration(
                            hintText: 'Old Password',
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
                                _isObsecure
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: validatePassword,
                        ),
                        SizedBox(height: 10.0),
                        // New password field
                        TextFormField(
                          controller: controllerRetypePassword,
                          obscureText: _isObsecure,
                          decoration: InputDecoration(
                            hintText: 'New Password',
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
                                _isObsecure
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: validateRetypePassword,
                        ),
                        SizedBox(height: 10.0),
                        // Retype new password field
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
                                _isObsecure
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                            ),
                          ),
                          validator: validateRetypePassword,
                        ),
                        SizedBox(height: 20.0),

                        // Register button
                        // ElevatedButton(
                        //   onPressed: onPressedRegister,
                        //   style: FilledButton.styleFrom(
                        //     minimumSize: Size(double.infinity, 50.0),
                        //   ),
                        // child: Text(widget.title),
                        // ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
