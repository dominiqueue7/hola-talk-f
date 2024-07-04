import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:HolaTalk/views/screens/auth/login.dart';
import 'package:HolaTalk/util/validations.dart';
import 'package:HolaTalk/services/online_status_service.dart'; // 실제 경로로 변경

class Account extends StatefulWidget {
  final Function(ThemeMode) updateThemeMode;

  Account({required this.updateThemeMode}); // 생성자에 updateThemeMode 추가

  @override
  _AccountState createState() => _AccountState();
}

class _AccountState extends State<Account> {
  // Firebase 인스턴스들
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final OnlineStatusService _onlineStatusService = OnlineStatusService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text('Account')),
      body: ListView(
        children: [
          _buildUserInfoTile(user),
          _buildEmailTile(user),
          _buildChangePasswordTile(user),
          _buildSignOutTile(),
          _buildDeleteAccountTile(user),
        ],
      ),
    );
  }

  // 사용자 정보 타일 위젯
  Widget _buildUserInfoTile(User? user) {
    return FutureBuilder<DocumentSnapshot>(
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
            leading: Icon(Icons.error),
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
    );
  }

  // 이메일 정보 타일 위젯
  Widget _buildEmailTile(User? user) {
    return ListTile(
      leading: Icon(Icons.email),
      title: Text('Email'),
      subtitle: Text(user?.email ?? 'No email'),
    );
  }

  // 비밀번호 변경 타일 위젯
  Widget _buildChangePasswordTile(User? user) {
    return ListTile(
      leading: Icon(Icons.lock),
      title: Text('Change Password'),
      onTap: () => _sendPasswordResetEmail(user),
    );
  }

  // 로그아웃 타일 위젯
  Widget _buildSignOutTile() {
    return ListTile(
      leading: Icon(Icons.logout),
      title: Text('Sign out'),
      onTap: _signOut,
    );
  }

  // 계정 삭제 타일 위젯
  Widget _buildDeleteAccountTile(User? user) {
    return ListTile(
      leading: Icon(Icons.delete),
      title: Text('Delete account'),
      onTap: () => _showDeleteAccountDialog(context, user),
    );
  }

  // 비밀번호 재설정 이메일 전송
  Future<void> _sendPasswordResetEmail(User? user) async {
    if (user?.email != null) {
      await _auth.sendPasswordResetEmail(email: user!.email!);
      _showSnackBar('Password reset email sent to ${user.email}.');
    } else {
      _showSnackBar('No email associated with this account.');
    }
  }

  // 로그아웃 처리
  Future<void> _signOut() async {
    await _onlineStatusService.setOffline();
    await _auth.signOut();
    _navigateToLogin();
  }

  // 로그인 화면으로 이동
  void _navigateToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => Login(updateThemeMode: widget.updateThemeMode),
      ), 
      (Route<dynamic> route) => false,
    );
  }

  // 계정 삭제 대화상자 표시
  Future<void> _showDeleteAccountDialog(BuildContext context, User? user) async {
    if (user == null) {
      _showSnackBar('User is not logged in.');
      return;
    }

    // 사용자의 로그인 방식 확인
    if (user.providerData.isEmpty) {
      _showSnackBar('Unable to determine login method.');
      return;
    }

    String providerId = user.providerData[0].providerId;

    switch (providerId) {
      case 'password':
        _showPasswordReauthDialog(user);
        break;
      case 'google.com':
        _showGoogleReauthDialog(user);
        break;
      default:
        _showGenericReauthDialog(user);
    }
  }

  // 비밀번호 재인증 대화상자
  Future<void> _showPasswordReauthDialog(User user) async {
    TextEditingController passwordController = TextEditingController();

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
                Text('Please enter your password to confirm:'),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Confirm'),
              onPressed: () => _confirmPasswordReauth(user, passwordController.text),
            ),
          ],
        );
      },
    );
  }

  // Google 재인증 대화상자
  Future<void> _showGoogleReauthDialog(User user) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Account'),
          content: Text('To delete your account, you need to re-authenticate with Google. Press Confirm to proceed.'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Confirm'),
              onPressed: () => _confirmGoogleReauth(user),
            ),
          ],
        );
      },
    );
  }

  // 일반 재인증 대화상자 (다른 제공자용)
  Future<void> _showGenericReauthDialog(User user) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Account'),
          content: Text('To delete your account, you need to re-authenticate. Please log out and log back in, then try deleting your account again.'),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // 비밀번호 재인증 확인
  Future<void> _confirmPasswordReauth(User user, String password) async {
    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      await _deleteAccount(user);
      _navigateToLogin();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        _showSnackBar('Incorrect password. Please try again.');
      } else {
        _showSnackBar('Failed to delete account: ${e.message}');
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e');
    }
  }

  // Google 재인증 확인
  Future<void> _confirmGoogleReauth(User user) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth?.accessToken,
        idToken: googleAuth?.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      await _deleteAccount(user);
      _navigateToLogin();
    } catch (e) {
      _showSnackBar('Failed to re-authenticate: $e');
    }
  }

  // 계정 삭제 처리
  Future<void> _deleteAccount(User user) async {
    try {
      // 1. Firebase Authentication에서 사용자 삭제
      await user.delete();

      // 2. 온라인 상태 업데이트
      await _onlineStatusService.setOffline();

      // 3. Firebase Storage에서 프로필 이미지 삭제
      await _deleteProfileImage(user.uid);

      // 4. Firestore Database에서 사용자 데이터 삭제
      await _deleteUserDataFromFirestore(user.uid);


      _showSnackBar('Your account has been successfully deleted.');
      _navigateToLogin();
    } catch (e) {
      _showSnackBar('Failed to delete account: $e');
    }
  }

  // Firestore에서 사용자 데이터 삭제
  Future<void> _deleteUserDataFromFirestore(String uid) async {
    await _firestore.runTransaction((transaction) async {
      transaction.delete(_firestore.collection('users').doc(uid));
    });
  }

  // Firebase Storage에서 프로필 이미지 삭제
  Future<void> _deleteProfileImage(String uid) async {
    try {
      await _storage.ref('user_profile/$uid.heic').delete();
    } catch (e) {
      // 이미지가 없는 경우 무시
      if (e is! FirebaseException || e.code != 'object-not-found') {
        print('Failed to delete profile image: $e');
      }
    }
  }

  // 스낵바 표시 헬퍼 메서드
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // 이름 변경 대화상자 표시
  Future<void> _showChangeNameDialog(BuildContext context, String currentName) async {
    TextEditingController nameController = TextEditingController(text: currentName);
    User? user = _auth.currentUser;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Change Name'),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: 'New Name'),
            maxLength: 30,
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () => _saveName(user, nameController.text.trim()),
            ),
          ],
        );
      },
    );
  }

  // 새 이름 저장
  Future<void> _saveName(User? user, String newName) async {
    String? validationResult = Validations.validateName(newName);
    if (validationResult != null) {
      _showSnackBar(validationResult);
      return;
    }
    if (newName.isNotEmpty && user != null) {
      await _firestore.collection('users').doc(user.uid).update({'name': newName});
      Navigator.of(context).pop();
      _showSnackBar('Name updated successfully');
      setState(() {});
    }
  }
}