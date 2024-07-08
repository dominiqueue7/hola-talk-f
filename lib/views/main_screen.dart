import 'package:flutter/material.dart';
import 'package:HolaTalk/views/chat/chats.dart';
import 'package:HolaTalk/views/friends.dart';
import 'package:HolaTalk/views/home.dart';
import 'package:HolaTalk/views/voice_chat.dart';
import 'package:HolaTalk/views/profile.dart';

// 메인 화면 위젯 클래스
class MainScreen extends StatefulWidget {
  final Function(ThemeMode) updateThemeMode;

  MainScreen({required this.updateThemeMode});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late PageController _pageController;
  int _page = 3; // 초기 페이지 인덱스 설정 (Home 화면)

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

  // 페이지 변경 시 호출되는 메서드
  void onPageChanged(int page) {
    setState(() {
      _page = page;
    });
  }

  // 하단 네비게이션 바 탭 시 호출되는 메서드
  void navigationTapped(int page) {
    _pageController.jumpToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        physics: NeverScrollableScrollPhysics(), // 스와이프로 페이지 전환 비활성화
        controller: _pageController,
        onPageChanged: onPageChanged,
        children: <Widget>[
          Chats(),
          Friends(),
          Home(),
          VoiceChatRoomList(),
          Profile(updateThemeMode: widget.updateThemeMode), // 테마 모드 업데이트 함수 전달
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
              icon: Icon(Icons.mic),
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