import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Account extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
              Navigator.of(context).popUntil((route) => route.isFirst);
              // 로그인 화면으로 이동하는 코드 추가
            },
          ),
          ListTile(
            leading: Icon(Icons.delete),
            title: Text('Delete account'),
            onTap: () async {
              try {
                await user?.delete();
                Navigator.of(context).popUntil((route) => route.isFirst);
                // 로그인 화면으로 이동하는 코드 추가
              } catch (e) {
                // 에러 처리
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete account: $e'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
