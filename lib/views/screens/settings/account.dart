import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:HolaTalk/views/screens/auth/login.dart';
import 'package:HolaTalk/util/validations.dart';
import 'package:HolaTalk/util/online_status_service.dart'; // 실제 경로로 변경

class Account extends StatefulWidget {
  final Function(ThemeMode) updateThemeMode;

  Account({required this.updateThemeMode}); // 생성자에 updateThemeMode 추가

  @override
  _AccountState createState() => _AccountState();
}

class _AccountState extends State<Account> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final OnlineStatusService _onlineStatusService = OnlineStatusService(); // OnlineStatusService 인스턴스 추가

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Account'),
      ),
      body: ListView(
        children: [
          FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('users').doc(user?.uid).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Loading...'),
                );
              }
              if (snapshot.hasError) {
                return ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Error loading name'),
                );
              }
              var userData = snapshot.data?.data() as Map<String, dynamic>?;
              var userName = userData?['name'] ?? 'No name';
              return ListTile(
                leading: Icon(Icons.person),
                title: Text('Name'),
                subtitle: Text(userName),
                onTap: () => _showChangeNameDialog(context, userName),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.email),
            title: Text('Email'),
            subtitle: Text(user?.email ?? 'No email'),
          ),
          ListTile(
            leading: Icon(Icons.lock),
            title: Text('Change Password'),
            onTap: () async {
              if (user?.email != null) {
                await _auth.sendPasswordResetEmail(email: user!.email!);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Password reset email sent to ${user.email}.'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No email associated with this account.'),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Sign out'),
            onTap: () async {
              // 로그아웃할 때 온라인 상태를 false로 설정
              _onlineStatusService.setOffline();

              await _auth.signOut();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => Login(updateThemeMode: widget.updateThemeMode), // updateThemeMode 전달
                ), 
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

  Future<void> _showChangeNameDialog(BuildContext context, String currentName) async {
    TextEditingController nameController = TextEditingController(text: currentName);
    User? user = _auth.currentUser;

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Change Name'),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: 'New Name'),
            maxLength: 30, // 최대 길이 제한
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () async {
                String newName = nameController.text.trim();
                String? validationResult = Validations.validateName(newName);
                if (validationResult != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(validationResult)),
                  );
                  return;
                }
                if (newName.isNotEmpty && user != null) {
                  await _firestore.collection('users').doc(user.uid).update({'name': newName});
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Name updated successfully')),
                  );
                  setState(() {}); // 화면을 갱신합니다.
                }
              },
            ),
          ],
        );
      },
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
                    // Firebase Storage에서 사용자 프로필 이미지 삭제 시도
                    try {
                      await _storage.ref('user_profile/${user?.uid}.heic').delete();
                    } catch (e) {
                      if (e is FirebaseException && e.code == 'object-not-found') {
                        // 파일이 존재하지 않는 경우 무시
                      } else {
                        rethrow; // 다른 예외는 재던지기
                      }
                    }

                    // Firestore에서 사용자 문서 삭제
                    await _firestore.collection('users').doc(user?.uid).delete();

                    // Firebase Authentication에서 사용자 삭제
                    await user?.delete();

                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => Login(updateThemeMode: widget.updateThemeMode), // updateThemeMode 전달
                      ), 
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
