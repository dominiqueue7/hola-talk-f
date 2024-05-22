import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OnlineStatusService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  OnlineStatusService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? user) {
    if (user != null) {
      _updateOnlineStatus(user.uid, true);
      _setupDisconnectListener(user.uid);
    } else {
      // 사용자가 로그아웃했을 때 오프라인 상태로 설정
      _updateOfflineStatus();
    }
  }

  void _setupDisconnectListener(String uid) {
    _firestore.collection('users').doc(uid).update({
      'online': false,
    }).then((_) {
      _firestore.collection('users').doc(uid).update({
        'online': true,
      });
    }).catchError((error) {
      print('Failed to set up disconnect listener: $error');
    });
  }

  void _updateOnlineStatus(String uid, bool isOnline) {
    _firestore.collection('users').doc(uid).update({
      'online': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }).catchError((error) {
      print('Failed to update online status: $error');
    });
  }

  void _updateOfflineStatus() {
    final user = _auth.currentUser;
    if (user != null) {
      _firestore.collection('users').doc(user.uid).update({
        'online': false,
        'lastSeen': FieldValue.serverTimestamp(),
      }).catchError((error) {
        print('Failed to update offline status: $error');
      });
    }
  }

  void setOnline() {
    final user = _auth.currentUser;
    if (user != null) {
      _updateOnlineStatus(user.uid, true);
    }
  }

  void setOffline() {
    final user = _auth.currentUser;
    if (user != null) {
      _updateOnlineStatus(user.uid, false);
    }
  }
}
