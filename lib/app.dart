import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:HolaTalk/util/const.dart';
import 'package:HolaTalk/util/theme_config.dart';
import 'package:HolaTalk/views/screens/auth/login.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:HolaTalk/util/online_status_service.dart'; // 실제 경로로 변경

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final OnlineStatusService _onlineStatusService = OnlineStatusService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _onlineStatusService.setOnline();
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
      home: Login(),
    );
  }

  ThemeData themeData(ThemeData theme) {
    return theme.copyWith(
      textTheme: GoogleFonts.sourceSansProTextTheme(theme.textTheme),
    );
  }
}
