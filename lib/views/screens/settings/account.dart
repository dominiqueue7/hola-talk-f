import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:HolaTalk/views/screens/auth/login.dart';

class Account extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Account'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.person),
            title: Text('ID'),
            subtitle: Text(user?.uid ?? 'Unknown'),
          ),
          ListTile(
            leading: Icon(Icons.email),
            title: Text('Email'),
            subtitle: Text(user?.email ?? 'No email'),
          ),
          ListTile(
            leading: Icon(Icons.lock),
            title: Text('Change Password'),
            onTap: () {
              // 비밀번호 변경 화면으로 이동하는 코드 추가
            },
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Sign out'),
            onTap: () async {
              await _auth.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => Login()), 
                (Route<dynamic> route) => false,
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.delete),
            title: Text('Delete account'),
            onTap: () async {
              _showDeleteAccountDialog(context, user);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context, User? user) async {
    TextEditingController emailController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // 다이얼로그 외부 클릭 시 닫히지 않도록 설정
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Account'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Are you sure you want to delete your account? This action cannot be undone.'),
                SizedBox(height: 20),
                Text('Please enter your email to confirm:'),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email address',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Confirm'),
              onPressed: () async {
                if (user?.email == emailController.text.trim()) {
                  try {
                    // Firestore에서 사용자 문서 삭제
                    await _firestore.collection('users').doc(user?.uid).delete();

                    // Firebase Authentication에서 사용자 삭제
                    await user?.delete();

                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => Login()), 
                      (Route<dynamic> route) => false,
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete account: $e'),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Email does not match. Please try again.'),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
