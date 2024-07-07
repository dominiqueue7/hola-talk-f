import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Appearance extends StatelessWidget {
  final Function(ThemeMode) updateThemeMode;

  Appearance({required this.updateThemeMode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Appearance'),
      ),
      body: ThemeSelection(updateThemeMode: updateThemeMode),
    );
  }
}

class ThemeSelection extends StatefulWidget {
  final Function(ThemeMode) updateThemeMode;

  ThemeSelection({required this.updateThemeMode});

  @override
  _ThemeSelectionState createState() => _ThemeSelectionState();
}

class _ThemeSelectionState extends State<ThemeSelection> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  void _loadThemeMode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int index = prefs.getInt('theme_mode') ?? ThemeMode.system.index;
    setState(() {
      _themeMode = ThemeMode.values[index];
    });
  }

  void _updateThemeMode(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
    widget.updateThemeMode(themeMode);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('theme_mode', themeMode.index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
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
              _updateThemeMode(value!);
            },
          ),
          onTap: () {
            _updateThemeMode(ThemeMode.system);
          },
        ),
        ListTile(
          title: Text('Dark Mode'),
          leading: Radio<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: _themeMode,
            onChanged: (ThemeMode? value) {
              _updateThemeMode(value!);
            },
          ),
          onTap: () {
            _updateThemeMode(ThemeMode.dark);
          },
        ),
        ListTile(
          title: Text('Light Mode'),
          leading: Radio<ThemeMode>(
            value: ThemeMode.light,
            groupValue: _themeMode,
            onChanged: (ThemeMode? value) {
              _updateThemeMode(value!);
            },
          ),
          onTap: () {
            _updateThemeMode(ThemeMode.light);
          },
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Other Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        // 다른 메뉴들 추가 예정
      ],
    );
  }
}
