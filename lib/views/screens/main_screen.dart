import 'package:flutter/material.dart';
import 'package:HolaTalk/views/widgets/icon_badge.dart';
import 'package:HolaTalk/views/screens/chat/chats.dart';
import 'package:HolaTalk/views/screens/friends.dart';
import 'package:HolaTalk/views/screens/home.dart';
import 'package:HolaTalk/views/screens/notifications.dart';
import 'package:HolaTalk/views/screens/profile.dart';

class MainScreen extends StatefulWidget {
  final Function(ThemeMode) updateThemeMode;

  MainScreen({required this.updateThemeMode});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late PageController _pageController;
  int _page = 2;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void onPageChanged(int page) {
    setState(() {
      _page = page;
    });
  }

  void navigationTapped(int page) {
    _pageController.jumpToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        physics: NeverScrollableScrollPhysics(),
        controller: _pageController,
        onPageChanged: onPageChanged,
        children: <Widget>[
          Chats(),
          Friends(),
          Home(),
          Notifications(),
          Profile(updateThemeMode: widget.updateThemeMode), // updateThemeMode 전달
        ],
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Theme.of(context).primaryColor,
          primaryColor: Theme.of(context).colorScheme.secondary,
          textTheme: Theme.of(context).textTheme.copyWith(
            bodySmall: TextStyle(color: Colors.grey[500]),
          ),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.message),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.group),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: IconBadge(icon: Icons.notifications),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: '',
            ),
          ],
          onTap: navigationTapped,
          currentIndex: _page,
        ),
      ),
    );
  }
}
