import 'package:firebase_auth/firebase_auth.dart';

class Validations {
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) return 'Name is Required.';
    // 모든 유니코드 문자를 허용하는 정규식
    final RegExp nameExp = new RegExp(r'^[\p{L} ]+$', unicode: true);
    if (!nameExp.hasMatch(value))
      return 'Please enter a valid name.';
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter an Email Address.';
    final RegExp nameExp = new RegExp(
        r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,2"
        r"53}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-z"
        r"A-Z0-9])?)*$");
    if (!nameExp.hasMatch(value)) return 'Invalid email address';
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty || value.length < 6)
      return 'Please enter a valid password.';
    return null;
  }

  static Future<String?> checkEmailInUse(String email) async {
    try {
      final list = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (list.isNotEmpty) {
        return 'This email is already in use.';
      }
    } catch (e) {
      return 'Error occurred while checking email.';
    }
    return null;
  }
}
