import 'package:flutter/material.dart';

class TextModelPainter extends CustomPainter {
  String name;
  TextStyle? textStyle;
  bool isSelected;
  TextAlign textAlign;
  double? textOffsetX;
  double? textOffsetY;
  Color? textColor;
  TextSpan? textSpan;
  double? fontsize;
  TextPainter? textPainter;
  Offset? offset;

  TextModelPainter({
    required this.name,
    this.textStyle,
    this.textColor,
    required this.isSelected,
    required this.textAlign,
    this.textOffsetX,
    this.textOffsetY,
    this.fontsize,
    this.textPainter,
    this.offset,
    this.textSpan,
  });

  @override
  void paint(Canvas canvas, Size size) {
    textStyle = TextStyle(
      color: Colors.white,
      fontSize: fontsize,
    );
    textSpan = TextSpan(
      text: '$name',
      style: textStyle,
    );
    textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter!.layout(
      minWidth: 0,
      maxWidth: size.width,
    );
    offset = Offset(textOffsetX!, textOffsetY!);
    textPainter!.paint(canvas, offset!);
  }

  @override
  bool shouldRepaint(CustomPainter old) {
    return true;
  }
}
