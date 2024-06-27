import 'package:HolaTalk/util/shared_preferences.dart';
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

// Flutter 로컬 알림 플러그인 초기화
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
  ThemeMode _themeMode = ThemeMode.system;
  final ThemePreferences _themePreferences = ThemePreferences();

  @override
  void initState() {
    super.initState();
    // 앱이 시작될 때 온라인 상태로 설정
    WidgetsBinding.instance.addObserver(this);
    _onlineStatusService.setOnline();

    // Firebase Analytics 초기화
    _analytics = FirebaseAnalytics.instance;
    _observer = FirebaseAnalyticsObserver(analytics: _analytics);

    // Firebase Messaging 초기화 및 토큰 저장
    FirebaseMessaging.instance.getToken().then((token) {
      if (token != null) {
        saveTokenToDatabase(token);
      }
    });

    // 토큰이 갱신될 때마다 토큰을 데이터베이스에 저장
    FirebaseMessaging.instance.onTokenRefresh.listen(saveTokenToDatabase);

    // foreground 상태에서 메시지 수신
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      RemoteNotification? notification = message.notification;

      if (notification != null) {
        // 알림을 표시
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
        // 수신된 메시지를 상태에 반영
        setState(() {
          messageString = message.notification?.body ?? '';
          print("Foreground MESSAGE : $messageString");
        });
      }
    });

    // 테마 모드 로드
    _loadThemeMode();
  }

  // 저장된 테마 모드를 로드하여 설정
  void _loadThemeMode() async {
    ThemeMode themeMode = await _themePreferences.getThemeMode();
    setState(() {
      _themeMode = themeMode;
    });
  }

  // 테마 모드를 업데이트하여 저장
  void _updateThemeMode(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
    _themePreferences.setThemeMode(themeMode);
  }

  // FCM 토큰을 데이터베이스에 저장
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
    // 앱이 종료될 때 오프라인 상태로 설정
    _onlineStatusService.setOffline();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 앱 생명주기 상태 변경에 따라 온라인/오프라인 상태 업데이트
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
      themeMode: _themeMode,
      navigatorObservers: [_observer],
      home: AuthWrapper(updateThemeMode: _updateThemeMode),
    );
  }

  // 테마 데이터를 생성하고 Google Fonts를 적용
  ThemeData themeData(ThemeData theme) {
    return theme.copyWith(
      textTheme: GoogleFonts.sourceSansProTextTheme(theme.textTheme),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final Function(ThemeMode) updateThemeMode;

  AuthWrapper({required this.updateThemeMode});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // 인증 상태를 확인하는 동안 로딩 인디케이터 표시
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasData && snapshot.data!.emailVerified) {
          // 사용자가 로그인되고 이메일이 인증된 경우 메인 화면으로 이동
          return MainScreen(updateThemeMode: updateThemeMode);
        } else {
          // 사용자가 로그인되지 않은 경우 로그인 화면으로 이동
          return Login(updateThemeMode: updateThemeMode);
        }
      },
    );
  }
}
