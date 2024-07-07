// animated_button.dart
import 'package:flutter/material.dart';

class AnimatedButton extends StatefulWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onPressed;

  const AnimatedButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onPressed,
  });

  @override
  _AnimatedButtonState createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: TweenAnimationBuilder(
        tween: ColorTween(
          begin: widget.color,
          end: _isPressed ? widget.color.withOpacity(0.7) : widget.color,
        ),
        duration: Duration(milliseconds: 150),
        builder: (BuildContext context, Color? color, Widget? child) {
          return Container(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }

  void _setPressed(bool isPressed) {
    setState(() {
      _isPressed = isPressed;
    });
  }
}
