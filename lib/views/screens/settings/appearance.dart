import 'package:flutter/material.dart';

class Appearance extends StatefulWidget {
  @override
  _AppearanceState createState() => _AppearanceState();
}

class _AppearanceState extends State<Appearance> {
  ThemeMode _themeMode = ThemeMode.system; // 현재 선택된 테마 모드 상태 저장

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Appearance'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Theme',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            title: Text('System Default'),
            leading: Radio<ThemeMode>(
              value: ThemeMode.system,
              groupValue: _themeMode,
              onChanged: (ThemeMode? value) {
                setState(() {
                  _themeMode = value!;
                });
              },
            ),
            onTap: () {
              setState(() {
                _themeMode = ThemeMode.system;
              });
            },
          ),
          ListTile(
            title: Text('Dark Mode'),
            leading: Radio<ThemeMode>(
              value: ThemeMode.dark,
              groupValue: _themeMode,
              onChanged: (ThemeMode? value) {
                setState(() {
                  _themeMode = value!;
                });
              },
            ),
            onTap: () {
              setState(() {
                _themeMode = ThemeMode.dark;
              });
            },
          ),
          ListTile(
            title: Text('Light Mode'),
            leading: Radio<ThemeMode>(
              value: ThemeMode.light,
              groupValue: _themeMode,
              onChanged: (ThemeMode? value) {
                setState(() {
                  _themeMode = value!;
                });
              },
            ),
            onTap: () {
              setState(() {
                _themeMode = ThemeMode.light;
              });
            },
          ),
          // 다른 메뉴 추가 예정인 섹션
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Other Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          // 다른 메뉴들 추가 예정
        ],
      ),
    );
  }
}
