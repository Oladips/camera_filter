// ignore_for_file: must_be_immutable

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'model/text_model.dart';

class TextEdit extends StatefulWidget {
  final TextModel text;
  final Function()? onCancel;
  final VideoPlayerController controller;
  bool isSelected;

  TextEdit({
    Key? key,
    required this.text,
    required this.isSelected,
    this.onCancel,
    required this.controller,
  }) : super(key: key);

  @override
  _TextEditState createState() => _TextEditState();
}

class _TextEditState extends State<TextEdit> {
  Offset _startPosition = Offset.zero;
  late double _boxWidth;
  late double _boxHeight;
  bool move = true;
  bool spin = false;
  bool scale = false;

  @override
  void initState() {
    super.initState();
    _startPosition = Offset(widget.text.left, widget.text.top);

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      _boxHeight = heightFullScreen();
      _boxWidth = widthFullScreen();
    });
  }

  heightFullScreen() {
    var phoneWidth = MediaQuery.of(context).size.width;
    var aspectRatioCalculation = phoneWidth / widget.controller.value.size.width;
    var finalVideoHeight = widget.controller.value.size.height * aspectRatioCalculation;
    return finalVideoHeight;
  }

  widthFullScreen() {
    var normalAspectRatioHeight = 9;
    var finalVideoHeight = 0.0;
    var initialAspectPerRatio;
    final deviceAspect = MediaQuery.of(context).size.width / 9;
    var conversionRate;
    var converted;
    var finalCalc;
    initialAspectPerRatio = widget.controller.value.size.width / normalAspectRatioHeight;
    conversionRate = deviceAspect / initialAspectPerRatio;
    converted = initialAspectPerRatio * conversionRate;
    finalCalc = converted * 9;
    finalVideoHeight = finalCalc;
    return finalVideoHeight;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: _startPosition.dy,
      left: _startPosition.dx,
      child: GestureDetector(
        onTap: () {
          if (widget.isSelected) {
            widget.isSelected = false;
            widget.text.isSelected = false;
          } else {
            widget.isSelected = true;
            widget.text.isSelected = true;
          }
          setState(() {});
        },
        onPanUpdate: (details) {
          if (move) {
            _startPosition += details.delta;

            _startPosition = Offset(
              _startPosition.dx.clamp(
                ((MediaQuery.of(context).size.width) - _boxWidth) / 2,
                MediaQuery.of(context).size.width - 100,
              ),
              _startPosition.dy.clamp(
                ((MediaQuery.of(context).size.height - 48) - _boxHeight) / 2,
                _boxHeight,
              ),
            );

            var varY = (widget.controller.value.size.height / _boxHeight) * _startPosition.dy;
            var varX = (widget.controller.value.size.width / (MediaQuery.of(context).size.width - 100)) * _startPosition.dx;

            widget.text.textOffsetX = varX;
            widget.text.textOffsetY = varY;
            setState(() {});
          }
        },
        child: GestureDetector(
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: DottedBorder(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    widget.text.name,
                    style: widget.text.textStyle,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.linear(widget.text.scale ?? 1),
                  ),
                ),
              ),

              /// top right corner of the selected text
              Positioned(
                top: 0,
                right: 0,
                child: InkWell(
                  onTap: () {
                    if (widget.onCancel != null) {
                      widget.onCancel!();
                    }

                    setState(() {});
                  },
                  child: widget.isSelected
                      ? Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: const Icon(
                            Icons.cancel_outlined,
                            color: Colors.red,
                            size: 15,
                          ),
                        )
                      : SizedBox.shrink(),
                ),
              ),

              /// top left corner of the selected text
              Positioned(
                top: 0,
                left: 0,
                child: InkWell(
                  onTap: () async {},
                  child: widget.isSelected
                      ? Builder(builder: (context) {
                          return Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 1),
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.black,
                              size: 10,
                            ),
                          );
                        })
                      : Container(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
