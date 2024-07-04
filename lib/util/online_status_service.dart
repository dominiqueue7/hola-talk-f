import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 사용자의 온라인 상태를 관리하는 서비스 클래스
class OnlineStatusService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 생성자: 인증 상태 변경 리스너를 설정합니다.
  OnlineStatusService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  /// 인증 상태가 변경될 때 호출되는 메서드
  /// 
  /// [user]가 null이 아니면 로그인 상태, null이면 로그아웃 상태입니다.
  void _onAuthStateChanged(User? user) {
    if (user != null) {
      _updateOnlineStatus(user.uid, true);
      _setupDisconnectListener(user.uid);
    } else {
      // 사용자가 로그아웃했을 때 오프라인 상태로 설정
      _updateOfflineStatus();
    }
  }

  /// 사용자의 연결 해제를 감지하는 리스너를 설정합니다.
  /// 
  /// 연결이 해제되면 사용자의 상태를 오프라인으로 설정하고,
  /// 다시 연결되면 온라인으로 설정합니다.
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

  /// 사용자의 온라인 상태를 업데이트합니다.
  /// 
  /// [uid]: 사용자의 고유 ID
  /// [isOnline]: 온라인 상태 여부
  Future<void> _updateOnlineStatus(String uid, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'online': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      print('Failed to update online status: $error');
    }
  }

  /// 현재 로그인된 사용자의 상태를 오프라인으로 업데이트합니다.
  Future<void> _updateOfflineStatus() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'online': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } catch (error) {
        print('Failed to update offline status: $error');
      }
    }
  }

  /// 현재 로그인된 사용자의 상태를 온라인으로 설정합니다.
  Future<void> setOnline() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _updateOnlineStatus(user.uid, true);
    }
  }

  /// 현재 로그인된 사용자의 상태를 오프라인으로 설정합니다.
  Future<void> setOffline() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _updateOnlineStatus(user.uid, false);
    }
  }
}