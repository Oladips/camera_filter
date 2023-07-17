import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SelectTimer extends StatefulWidget {
  final int? duration;
  const SelectTimer({
    Key? key,
    this.duration,
  }) : super(key: key);

  @override
  State<SelectTimer> createState() => _SelectTimerState();
}

class _SelectTimerState extends State<SelectTimer> {
  double currentTimer = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height * .25,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.1),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Timer",
              style: GoogleFonts.poppins(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              "Use the slider to choose a countdown limit.",
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 30),
            Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  "0",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
                Expanded(
                  child: Slider(
                    divisions: 5,
                    label: currentTimer.floor().toString(),
                    value: widget.duration?.toDouble() ?? currentTimer,
                    onChanged: (val) {
                      currentTimer = val;
                      setState(() {});
                    },
                    max: 15,
                    min: 0,
                    activeColor: Color.fromRGBO(240, 128, 55, 1),
                    inactiveColor: Colors.white,
                  ),
                ),
                Text(
                  "15",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            InkWell(
              onTap: () {
                Navigator.pop(context, currentTimer.floor());
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: 13,
                  horizontal: 13,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.transparent),
                  color: Colors.white,
                ),
                child: Center(
                  child: Text(
                    "Set timer",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color.fromRGBO(19, 15, 38, 1.0),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
