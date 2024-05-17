import 'package:flutter/material.dart';

class Settings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.account_circle),
            title: Text('Account'),
            onTap: () {
              // Account 설정 화면으로 이동하는 코드 추가
            },
          ),
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text('Notifications'),
            onTap: () {
              // Notifications 설정 화면으로 이동하는 코드 추가
            },
          ),
          ListTile(
            leading: Icon(Icons.lock),
            title: Text('Privacy'),
            onTap: () {
              // Privacy 설정 화면으로 이동하는 코드 추가
            },
          ),
          ListTile(
            leading: Icon(Icons.chat),
            title: Text('Chat Settings'),
            onTap: () {
              // Chat Settings 설정 화면으로 이동하는 코드 추가
            },
          ),
          ListTile(
            leading: Icon(Icons.info),
            title: Text('About'),
            onTap: () {
              // About 화면으로 이동하는 코드 추가
            },
          ),
          ListTile(
            leading: Icon(Icons.help),
            title: Text('Help'),
            onTap: () {
              // Help 화면으로 이동하는 코드 추가
            },
          ),
        ],
      ),
    );
  }
}
