import 'package:HolaTalk/util/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:HolaTalk/util/const.dart';
import 'package:HolaTalk/util/theme_config.dart';
import 'package:HolaTalk/views/screens/auth/login.dart';
import 'package:HolaTalk/views/screens/main_screen.dart';
import 'package:HolaTalk/services/online_status_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';

// Flutter 로컬 알림 플러그인을 초기화합니다.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final OnlineStatusService _onlineStatusService = OnlineStatusService();
  late FirebaseAnalytics _analytics;
  late FirebaseAnalyticsObserver _observer;
  ThemeMode _themeMode = ThemeMode.system;
  final ThemePreferences _themePreferences = ThemePreferences();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _onlineStatusService.setOnline();
    _initializeFirebaseAnalytics();
    _initializeFirebaseMessaging();
    _initializeNotifications();
    _requestNotificationPermissions();
    _handleInitialMessage();
    _loadThemeMode();
  }

  // Firebase Analytics를 초기화합니다.
  void _initializeFirebaseAnalytics() {
    _analytics = FirebaseAnalytics.instance;
    _observer = FirebaseAnalyticsObserver(analytics: _analytics);
  }

  // Firebase Messaging을 초기화하고 토큰을 저장합니다.
  void _initializeFirebaseMessaging() {
    FirebaseMessaging.instance.getToken().then((token) {
      if (token != null) {
        saveTokenToDatabase(token);
      }
    });

    FirebaseMessaging.instance.onTokenRefresh.listen(saveTokenToDatabase);

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  // 알림을 초기화합니다.
  Future<void> _initializeNotifications() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'high_importance_notification',
      importance: Importance.max,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await flutterLocalNotificationsPlugin.initialize(
      InitializationSettings(
        android: AndroidInitializationSettings("@mipmap/ic_launcher"),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (details) {
        // 알림 응답 처리 로직
      },
      onDidReceiveBackgroundNotificationResponse: _backgroundHandler,
    );
  }

  // 푸시 알림 권한을 요청합니다.
  Future<void> _requestNotificationPermissions() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');
  }

  // 앱이 종료된 상태에서 알림을 통해 열릴 때의 메시지를 처리합니다.
  Future<void> _handleInitialMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // 초기 메시지 처리 로직
    }
  }

  // 포그라운드 상태에서 메시지를 처리합니다.
  void _handleForegroundMessage(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    if (notification != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'high_importance_notification',
            importance: Importance.max,
          ),
        ),
      );
      print("Foreground MESSAGE : ${notification.body ?? ''}");
    }
  }

  // 백그라운드에서 알림 응답을 처리합니다.
  @pragma('vm:entry-point')
  static void _backgroundHandler(NotificationResponse details) {
    // 백그라운드 알림 처리 로직
  }

  // FCM 토큰을 데이터베이스에 저장합니다.
  void saveTokenToDatabase(String token) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fcmToken': token,
      });
    }
  }

  // 저장된 테마 모드를 로드합니다.
  void _loadThemeMode() async {
    ThemeMode themeMode = await _themePreferences.getThemeMode();
    setState(() {
      _themeMode = themeMode;
    });
  }

  // 테마 모드를 업데이트하고 저장합니다.
  void _updateThemeMode(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
    _themePreferences.setThemeMode(themeMode);
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
      themeMode: _themeMode,
      navigatorObservers: [_observer],
      home: AuthWrapper(updateThemeMode: _updateThemeMode),
    );
  }

  // 테마 데이터를 생성하고 Google Fonts를 적용합니다.
  ThemeData themeData(ThemeData theme) {
    return theme.copyWith(
      textTheme: GoogleFonts.sourceSansProTextTheme(theme.textTheme),
    );
  }
}

// 인증 상태에 따라 적절한 화면을 표시하는 래퍼 위젯입니다.
class AuthWrapper extends StatelessWidget {
  final Function(ThemeMode) updateThemeMode;

  AuthWrapper({required this.updateThemeMode});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasData && snapshot.data!.emailVerified) {
          return MainScreen(updateThemeMode: updateThemeMode);
        } else {
          return Login(updateThemeMode: updateThemeMode);
        }
      },
    );
  }
}