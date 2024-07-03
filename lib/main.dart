import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app.dart';

void main() async {
  // Flutter 엔진과 위젯 바인딩을 초기화합니다.
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase를 초기화합니다.
  await Firebase.initializeApp();

  // 백그라운드 메시지 핸들러를 설정합니다.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // MyApp 위젯을 실행합니다.
  runApp(MyApp());
}

// 백그라운드에서 Firebase 메시지를 처리하는 핸들러입니다.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("BACKGROUND MESSAGE : ${message.notification!.body!}");
}