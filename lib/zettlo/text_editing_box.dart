import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import 'model/text_model.dart';

class TextEditingBox extends StatefulWidget {
  final VideoPlayerController controller;
  const TextEditingBox({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<TextEditingBox> createState() => _TextEditingBoxState();
}

class _TextEditingBoxState extends State<TextEditingBox> {
  final textCon = TextEditingController();

  @override
  void dispose() {
    textCon.dispose();
    super.dispose();
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
    return Container(
      height: MediaQuery.of(context).size.height / 2,
      width: MediaQuery.of(context).size.width,
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () {
                  final textModel = TextModel(
                    name: textCon.text,
                    fontsize: 32,
                    textStyle: TextStyle(
                      fontFamily: "Poppins",
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                    ),
                    isSelected: true,
                    left: widthFullScreen() / 2,
                    top: heightFullScreen() / 2,
                    textAlign: TextAlign.center,
                    textColor: Colors.white,
                  );

                  Navigator.pop(context, textModel);
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.white,
                  ),
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "Done",
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            ],
          ),
          SizedBox(height: 24),
          Expanded(
            child: TextFormField(
              cursorColor: Color.fromRGBO(240, 128, 55, 1),
              autofocus: true,
              controller: textCon,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              textAlign: TextAlign.start,
              textAlignVertical: TextAlignVertical.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w400,
              ),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  vertical: 13,
                  horizontal: 16,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(24),
                  ),
                ),
                border: InputBorder.none,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(
                    Radius.circular(24),
                  ),
                  borderSide: BorderSide(
                    color: Color.fromRGBO(240, 128, 55, 1),
                    width: 2,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
