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

// 백그라운드에서 메시지를 처리하는 핸들러
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("백그라운드 메시지 처리.. ${message.notification!.body!}");
}

// 백그라운드에서 알림을 클릭하여 앱을 열 때의 동작
@pragma('vm:entry-point')
void backgroundHandler(NotificationResponse details) {
  // 액션 추가... 파라미터는 details.payload 방식으로 전달
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// 기본적인 notification 의 설정
void initializeNotification() async {
  // 백그라운드 메시지 핸들러 설정
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 안드로이드용 알림 채널 생성
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(const AndroidNotificationChannel(
          'high_importance_channel', 'high_importance_notification',
          importance: Importance.max));

  // 로컬 알림 플러그인 초기화 설정
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings("@mipmap/ic_launcher"),
      iOS: DarwinInitializationSettings(),
    ),
    // 알림을 클릭하여 앱을 열 때의 동작  (앱이 실행된 경우)
    onDidReceiveNotificationResponse: (details) {
      // 처리 로직 추가
    },
    // 알림을 클릭하여 앱을 열 때의 동작 (앱이 종료된 경우, 백그라운드의 경우)
    onDidReceiveBackgroundNotificationResponse: backgroundHandler,
  );

  // 푸시 알림 권한 요청
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // 앱이 실행되지 않은 상태에서 알림을 클릭하여 앱을 열 때의 동작
  RemoteMessage? message = await FirebaseMessaging.instance.getInitialMessage();
  if (message != null) {
    // 액션 부분 -> 파라미터는 message.data['test_parameter1'] 이런 방식으로...
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final OnlineStatusService _onlineStatusService = OnlineStatusService();
  var messageString = "";

  @override
  void initState() {
    super.initState();
    // 앱이 시작될 때 온라인 상태로 설정
    WidgetsBinding.instance.addObserver(this);
    _onlineStatusService.setOnline();

    // Firebase 클라우드 메시징(FCM) 토큰을 가져와 데이터베이스에 저장하고, 토큰이 갱신될 때마다 이를 처리합니다.
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
          print("Foreground 메시지 수신: $messageString");
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
