import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:HolaTalk/util/const.dart';
import 'package:HolaTalk/util/theme_config.dart';
import 'package:HolaTalk/views/screens/auth/login.dart';
import 'package:HolaTalk/views/screens/main_screen.dart';
import 'package:HolaTalk/util/online_status_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final OnlineStatusService _onlineStatusService = OnlineStatusService();
  var messageString = "";
  late FirebaseAnalytics _analytics;
  late FirebaseAnalyticsObserver _observer;

  @override
  void initState() {
    super.initState();
    // 앱이 시작될 때 온라인 상태로 설정
    WidgetsBinding.instance.addObserver(this);
    _onlineStatusService.setOnline();

    // Firebase Analytics 초기화
    _analytics = FirebaseAnalytics.instance;
    _observer = FirebaseAnalyticsObserver(analytics: _analytics);

    FirebaseMessaging.instance.getToken().then((token) {
      if (token != null) {
        saveTokenToDatabase(token);
      }
    });

    // 토큰이 갱신될 때마다 saveTokenToDatabase 메서드를 호출하여 새로운 토큰을 데이터베이스에 저장합니다.
    FirebaseMessaging.instance.onTokenRefresh.listen(saveTokenToDatabase);

    // foreground 상태에서 메시지 수신
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      RemoteNotification? notification = message.notification;

      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'high_importance_notification',
              importance: Importance.max,
            ),
          ),
        );
        setState(() {
          messageString = message.notification?.body ?? '';
          print("Foreground MESSAGE : $messageString");
        });
      }
    });
  }

  void saveTokenToDatabase(String token) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fcmToken': token,
      });
    }
  }

  @override
  void dispose() {
    _onlineStatusService.setOffline();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _onlineStatusService.setOnline();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _onlineStatusService.setOffline();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: Constants.appName,
      theme: themeData(ThemeConfig.lightTheme),
      darkTheme: themeData(ThemeConfig.darkTheme),
      navigatorObservers: [_observer], // Firebase Analytics Observer 추가
      home: AuthWrapper(),
    );
  }

  ThemeData themeData(ThemeData theme) {
    return theme.copyWith(
      textTheme: GoogleFonts.sourceSansProTextTheme(theme.textTheme),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasData) {
          return MainScreen();
        } else {
          return Login();
        }
      },
    );
  }
}
