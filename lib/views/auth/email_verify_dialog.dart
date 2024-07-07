import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerificationDialog {
  static void show(BuildContext context, User? user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Email not verified'),
        content: Text('Your email is not verified. Would you like to resend the verification email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await user?.sendEmailVerification();
              await FirebaseAuth.instance.signOut();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Verification email has been resent. Please check your email.')),
              );
            },
            child: Text('Resend'),
          ),
        ],
      ),
    );
  }
}