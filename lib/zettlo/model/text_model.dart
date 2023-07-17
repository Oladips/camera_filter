import 'package:camera_filters/src/painter.dart';
import 'package:flutter/material.dart';

class TextModel {
  String name;
  TextStyle textStyle;
  bool isSelected;
  double? scale;
  double top;
  double left;
  TextAlign textAlign;
  double? textOffsetX;
  double? textOffsetY;
  Color textColor = Colors.white;
  bool? box = false;
  double? boxheight;
  double? fontsize;
  double? textangle;
  Color? boxcolor;
  Controller? textController;

  TextModel({
    required this.name,
    required this.textStyle,
    required this.isSelected,
    this.scale,
    required this.left,
    required this.top,
    required this.textAlign,
    this.textOffsetX,
    this.box,
    this.boxheight,
    this.fontsize,
    this.textangle,
    required this.textColor,
    this.textOffsetY,
    this.boxcolor,
    this.textController,
  });
}
