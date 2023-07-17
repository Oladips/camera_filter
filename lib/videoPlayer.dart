import 'dart:async';
import 'dart:io';

import 'package:camera_filters/src/draw_image.dart';
import 'package:camera_filters/src/painter.dart';
import 'package:camera_filters/src/tapioca/content.dart';
import 'package:camera_filters/src/tapioca/tapioca_ball.dart';
import 'package:camera_filters/src/widgets/_range_slider.dart';
import 'package:camera_filters/zettlo/text_edit.dart';
import 'package:camera_filters/zettlo/text_editing_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart' as video;
import 'package:video_player/video_player.dart';

import 'src/tapioca/cup.dart';
import 'zettlo/model/text_model.dart';

// ignore: must_be_immutable
class VideoPlayer extends StatefulWidget {
  String? video;
  final List<Color>? filters;
  final Color? selectedFilter;
  Function(String)? onVideoDone;

  VideoPlayer(
    this.video, {
    this.onVideoDone,
    this.filters,
    this.selectedFilter,
  });

  @override
  State<VideoPlayer> createState() => _VideoPlayersState();
}

late VideoPlayerController _videoPlayerController;

class _VideoPlayersState extends State<VideoPlayer> {
  Timer? timer;
  double videoTime = 0.0;
  bool cancelling = false;
  bool videoSpeedBar = false;
  ValueNotifier<bool> dragText = ValueNotifier(true);
  ValueNotifier<int> colorValue = ValueNotifier(0xFFFFFFFF);
  String text = '';
  double fontSize = 30;
  final tapiocaBalls = <TapiocaBall>[];

  String? finishedPath;

  late TextDelegate textDelegate;
  late final ValueNotifier<Controller> _controller;
  final TextEditingController _textEditingController = TextEditingController();
  ValueNotifier<bool> textFieldBool = ValueNotifier(false);
  Offset offset = Offset.zero;
  bool isLoading = false;
  List<TextModel> texts = [];

  @override
  void initState() {
    super.initState();
    _controller = ValueNotifier(
      const Controller().copyWith(
        mode: PaintMode.freeStyle,
        strokeWidth: 2,
        color: Colors.white,
      ),
    );
    textDelegate = TextDelegate();
    initVideo();
  }

  initVideo() async {
    _videoPlayerController = VideoPlayerController.file(File(widget.video!));
    _videoPlayerController.addListener(() {});
    _videoPlayerController.setLooping(true);
    _videoPlayerController.initialize().then((_) => setState(() {}));
    await _videoPlayerController.play();
    timer = null;
    await startTimer();
  }

  startTimer() {
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        setState(() {});
        if (videoTime == (_videoPlayerController.value.duration.inSeconds)) {
          timer.cancel();
          videoTime = 0;
          startTimer();
          return;
        }

        videoTime++;
      },
    );
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: WillPopScope(
        onWillPop: () async {
          if (isLoading) {
            return false;
          }

          return true;
        },
        child: Material(
          color: Colors.black,
          child: Builder(builder: (context) {
            if (isLoading) {
              return Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 30,
                        width: 30,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color.fromRGBO(240, 128, 55, 1),
                          ),
                          strokeWidth: 5,
                        ),
                      ),
                      SizedBox(height: 15),
                      Text(
                        "Processing",
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  color: Colors.black,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: _videoPlayerController.value.isInitialized
                              ? AspectRatio(
                                  aspectRatio: _videoPlayerController.value.aspectRatio,
                                  child: InkWell(
                                    onTap: () {
                                      if (_videoPlayerController.value.isPlaying) {
                                        _videoPlayerController.pause();
                                        timer?.cancel();
                                      } else {
                                        startTimer();
                                        _videoPlayerController.play();
                                      }
                                    },
                                    child: ColorFiltered(
                                      colorFilter: ColorFilter.mode(
                                        widget.selectedFilter!,
                                        BlendMode.softLight,
                                      ),
                                      child: video.VideoPlayer(
                                        _videoPlayerController,
                                      ),
                                    ),
                                  ))
                              : AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Container(
                                    color: Colors.black,
                                    width: double.maxFinite,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Color.fromRGBO(240, 128, 55, 1),
                                        ),
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                        ...texts.map((e) {
                          return TextEdit(
                            text: e,
                            isSelected: e.isSelected,
                            controller: _videoPlayerController,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                Container(
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () async {
                                    if (finishedPath != null) {
                                      await File(widget.video!).delete();
                                      await File(finishedPath!).delete();
                                    } else {
                                      await File(widget.video!).delete();
                                    }
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    height: 30,
                                    width: 30,
                                    child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      height: 8,
                                      padding: EdgeInsets.symmetric(horizontal: 24),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    Builder(builder: (context) {
                                      if (timer != null) {
                                        return AnimatedContainer(
                                          duration: const Duration(seconds: 1),
                                          width: (MediaQuery.of(context).size.width - 48) * (videoTime / _videoPlayerController.value.duration.inSeconds),
                                          height: 8,
                                          padding: EdgeInsets.symmetric(horizontal: 24),
                                          decoration: BoxDecoration(
                                            color: Color.fromRGBO(240, 128, 55, 1),
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    }),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () async {
                                //! Discard all changes.
                                texts.clear();
                                _videoPlayerController.dispose();
                                _videoPlayerController = VideoPlayerController.file(File(widget.video!));
                                _videoPlayerController.addListener(() {});
                                _videoPlayerController.setLooping(true);
                                _videoPlayerController.initialize().then((_) => setState(() {}));
                                _videoPlayerController.play();
                              },
                              child: Column(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    child: Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 40,
                                    ),
                                  ),
                                  Text(
                                    "Discard changes",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                if (texts.isNotEmpty) {
                                  for (var element in texts) {
                                    final ball = TapiocaBall.textOverlay(
                                      element.name,
                                      element.textOffsetX!.toInt() - 48,
                                      element.textOffsetY!.toInt(),
                                      (element.fontsize! * 1.5).toInt(),
                                      element.textColor,
                                    );
                                    tapiocaBalls.add(ball);
                                  }
                                }
                                if (widget.selectedFilter != null) {
                                  tapiocaBalls.add(
                                    TapiocaBall.filterFromColor(
                                      widget.selectedFilter!.withOpacity(.1),
                                      100,
                                    ),
                                  );
                                }
                                String? video;
                                if (finishedPath == null) {
                                  video = widget.video;
                                } else {
                                  video = finishedPath;
                                }

                                await makeVideo(tapiocaBalls, video);
                              },
                              child: Column(
                                children: [
                                  Container(
                                    height: 80,
                                    width: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color.fromRGBO(240, 128, 55, 1).withOpacity(0.5),
                                    ),
                                    padding: EdgeInsets.all(6.0),
                                    child: Container(
                                      height: 64,
                                      width: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color.fromRGBO(240, 128, 55, 1),
                                      ),
                                      child: Icon(
                                        Icons.movie_edit,
                                        size: 32,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    "Edit",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    if (finishedPath == null) {
                                      if (widget.selectedFilter != Colors.transparent && texts.isEmpty) {
                                        tapiocaBalls.add(
                                          TapiocaBall.filterFromColor(
                                            widget.selectedFilter!.withOpacity(.1),
                                            100,
                                          ),
                                        );

                                        await makeVideo(tapiocaBalls, widget.video);
                                      } else if (widget.selectedFilter != Colors.transparent && texts.isNotEmpty) {
                                        for (var element in texts) {
                                          final ball = TapiocaBall.textOverlay(
                                            element.name,
                                            element.textOffsetX!.toInt() - 48,
                                            element.textOffsetY!.toInt(),
                                            (element.fontsize! * 1.5).toInt(),
                                            element.textColor,
                                          );
                                          tapiocaBalls.add(ball);
                                        }

                                        tapiocaBalls.add(
                                          TapiocaBall.filterFromColor(
                                            widget.selectedFilter!.withOpacity(.1),
                                            100,
                                          ),
                                        );

                                        await makeVideo(tapiocaBalls, widget.video);
                                      } else if (widget.selectedFilter == Colors.transparent && texts.isNotEmpty) {
                                        for (var element in texts) {
                                          final ball = TapiocaBall.textOverlay(
                                            element.name,
                                            element.textOffsetX!.toInt() - 48,
                                            element.textOffsetY!.toInt(),
                                            (element.fontsize! * 1.5).toInt(),
                                            element.textColor,
                                          );
                                          tapiocaBalls.add(ball);
                                        }

                                        await makeVideo(tapiocaBalls, widget.video);
                                      } else if (widget.selectedFilter == Colors.transparent && texts.isEmpty) {
                                        finishedPath = widget.video;
                                        Navigator.pop(context);
                                        await (widget.onVideoDone ?? () {})(finishedPath);
                                      }
                                    } else {
                                      Navigator.pop(context);
                                      await (widget.onVideoDone ?? () {})(finishedPath);
                                    }
                                  },
                                  child: Container(
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color.fromRGBO(240, 128, 55, 1),
                                    ),
                                    padding: EdgeInsets.all(7),
                                    child: Center(
                                      child: Icon(
                                        Icons.check,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  "Continue",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                Positioned(
                  top: 241,
                  right: 0,
                  child: Container(
                    width: 77,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        bottomLeft: Radius.circular(24),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 22,
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 70,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: () async {
                                  final s = await showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    isDismissible: true,
                                    backgroundColor: Colors.transparent,
                                    enableDrag: true,
                                    builder: (context) {
                                      return TextEditingBox(
                                        controller: _videoPlayerController,
                                      );
                                    },
                                  );

                                  if (!mounted) return;

                                  if (s != null) {
                                    texts.add(s);
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF000000),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF000000),
                                    ),
                                    padding: EdgeInsets.all(7),
                                    child: SizedBox(
                                      height: 30,
                                      width: 30,
                                      child: Icon(
                                        Icons.text_fields_sharp,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 7),
                              Expanded(
                                child: Text(
                                  "Text",
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // SizedBox(height: 12),
                        // SizedBox(
                        //   height: 70,
                        //   child: Column(
                        //     children: [
                        //       PopupMenuButton(
                        //         tooltip: textDelegate.changeBrushSize,
                        //         shape: ContinuousRectangleBorder(
                        //           borderRadius: BorderRadius.circular(20),
                        //         ),
                        //         icon: Icon(
                        //           Icons.font_download_outlined,
                        //           color: Colors.white,
                        //           size: 30,
                        //         ),
                        //         itemBuilder: (_) => [
                        //           _showTextSlider(),
                        //         ],
                        //       ),
                        //       SizedBox(height: 5),
                        //       Expanded(
                        //         child: Text(
                        //           "Font Edit",
                        //           style: GoogleFonts.poppins(
                        //             fontSize: 10,
                        //             fontWeight: FontWeight.w500,
                        //             color: Colors.white,
                        //           ),
                        //         ),
                        //       ),
                        //     ],
                        //   ),
                        // ),
                        // SizedBox(height: 12),
                        // SizedBox(
                        //   height: 70,
                        //   child: Column(
                        //     children: [
                        //       ValueListenableBuilder<Controller>(
                        //         valueListenable: _controller,
                        //         builder: (_, controller, __) {
                        //           return IconButton(
                        //             icon: Icon(
                        //               Icons.color_lens_rounded,
                        //               color: Colors.white,
                        //               size: 30,
                        //             ),
                        //             onPressed: () {
                        //               colorPicker(controller);
                        //             },
                        //           );
                        //         },
                        //       ),
                        //       SizedBox(height: 7),
                        //       Expanded(
                        //         child: Text(
                        //           "Choose color",
                        //           style: GoogleFonts.poppins(
                        //             fontSize: 10,
                        //             fontWeight: FontWeight.w500,
                        //             color: Colors.white,
                        //           ),
                        //         ),
                        //       ),
                        //     ],
                        //   ),
                        // ),
                        // SizedBox(height: 12),
                        // SizedBox(
                        //   height: 70,
                        //   child: Column(
                        //     children: [
                        //       InkWell(
                        //         onTap: () {},
                        //         child: Container(
                        //           decoration: BoxDecoration(
                        //             shape: BoxShape.circle,
                        //             color: Color(0xFF000000),
                        //           ),
                        //           child: Container(
                        //             decoration: BoxDecoration(
                        //               shape: BoxShape.circle,
                        //               color: Color(0xFF000000),
                        //             ),
                        //             padding: EdgeInsets.all(7),
                        //             child: SizedBox(
                        //               height: 30,
                        //               width: 30,
                        //               child: Icon(
                        //                 Icons.music_note_sharp,
                        //                 color: Colors.white,
                        //               ),
                        //             ),
                        //           ),
                        //         ),
                        //       ),
                        //       SizedBox(height: 7),
                        //       Expanded(
                        //         child: Text(
                        //           "Sound",
                        //           style: GoogleFonts.poppins(
                        //             fontSize: 10,
                        //             fontWeight: FontWeight.w500,
                        //             color: Colors.white,
                        //           ),
                        //         ),
                        //       )
                        //     ],
                        //   ),
                        // )
                      ],
                    ),
                  ),
                ),

                // try {
                //   var a = 1.7 * int.parse(xPos.toString().split(".")[0]);
                //   var b = 1.7 * int.parse(yPos.toString().split(".")[0]);

                //   if (text == "" && _filterColor.value.value == 0) {
                //     widget.onVideoDone!.call(widget.video);
                //   } else if (text == "" && _filterColor.value.value != 0) {
                //     final tapiocaBalls = [
                //       TapiocaBall.filterFromColor(Color(_filterColor.value.value)),
                //     ];
                //     makeVideo(tapiocaBalls, path);
                //   } else if (text != "" && _filterColor.value.value == 0) {
                //     final tapiocaBalls = [
                //       TapiocaBall.textOverlay(text, int.parse(a.toString().split(".")[0]), int.parse(b.toString().split(".")[0]), (fontSize * 2).toInt(),
                //           Color(colorValue.value))
                //     ];
                //     makeVideo(tapiocaBalls, path);
                //   } else {
                //     final tapiocaBalls = [
                //       TapiocaBall.filterFromColor(Color(_filterColor.value.value)),
                //       TapiocaBall.textOverlay(text, int.parse(a.toString().split(".")[0]), int.parse(b.toString().split(".")[0]), (fontSize * 2).toInt(),
                //           Color(colorValue.value))
                //     ];
                //     makeVideo(tapiocaBalls, path);
                //   }
                // } on PlatformException {
                //   print("error!!!!");
                // }
                //         },
                // child: widget.sendButtonWidget ??
                //     Container(
                //       height: 60,
                //       width: 60,
                //       decoration: BoxDecoration(color: Color(0xffd51820), borderRadius: BorderRadius.circular(60)),
                //       child: Center(
                //         child: Icon(Icons.send),
                //       ),
                //     ),
                //       ),
                //     ),
                //   ),
                // ),
              ],
            );
          }),
        ),
      ),
    );
  }

  makeVideo(
    tapiocaBalls,
    video,
  ) async {
    isLoading = true;
    setState(() {});
    _videoPlayerController.pause();
    timer?.cancel();
    videoTime = 0.0;
    timer = null;

    var tempDir = await getApplicationDocumentsDirectory();
    final path = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}result.mp4';

    final cup = Cup(Content(video), tapiocaBalls);
    await cup.suckUp(path).then((_) async {
      _videoPlayerController.dispose();
      finishedPath = path;
      _videoPlayerController = VideoPlayerController.file(File(path));
      _videoPlayerController.addListener(() {});
      _videoPlayerController.setLooping(true);
      await _videoPlayerController.initialize().then((_) => setState(() {}));
      _videoPlayerController.play();

      texts.clear();
      setState(() {});
      startTimer();

      isLoading = false;
      setState(() {});
    });
  }

  PopupMenuItem _showTextSlider() {
    return PopupMenuItem(
      enabled: false,
      child: SizedBox(
        width: double.maxFinite,
        child: ValueListenableBuilder<Controller>(
          valueListenable: _controller,
          builder: (_, ctrl, __) {
            return FontVideoRangedSlider(
              value: fontSize,
              onChanged: (value) {
                _controller.value = ctrl.copyWith(fontSize: value);
                fontSize = value;
                setState(() {});
              },
            );
          },
        ),
      ),
    );
  }

  colorPicker(controller) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              'Pick a color!',
              style: GoogleFonts.poppins(),
            ),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: Color(controller.color.value),
                onColorChanged: (color) {
                  _controller.value = controller.copyWith(color: color);
                  colorValue.value = color.value;
                },
              ),
            ),
            actions: <Widget>[
              ElevatedButton(
                child: Text(
                  'Ok',
                  style: GoogleFonts.poppins(),
                ),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        });
  }

  Widget textField(context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 10,
        right: 10,
      ),
      child: Container(
        height: 55,
        alignment: Alignment.bottomCenter,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 3),
                child: TextFormField(
                  cursorColor: Colors.black,
                  autofocus: true,
                  controller: _textEditingController,
                  style: TextStyle(color: Colors.black, fontSize: 25),
                  decoration: InputDecoration(border: InputBorder.none),
                ),
              ),
            ),
            IconButton(
                onPressed: () {
                  if (_textEditingController.text.isNotEmpty) {
                    text = _textEditingController.text;
                    Navigator.pop(context);
                    dragText.value = true;
                  }
                },
                icon: const Icon(
                  Icons.send,
                  color: Colors.black,
                ))
          ],
        ),
      ),
    );
  }

  var xPos = 30.0;
  var yPos = 30.0;
  final width = 100.0;
  final height = 100.0;

  Widget positionedText() {
    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          xPos += details.delta.dx;
          yPos += details.delta.dy;
        });
      },
      child: ValueListenableBuilder(
          valueListenable: colorValue,
          builder: (context, int value, Widget? child) {
            return CustomPaint(
              willChange: true,
              size: Size(
                MediaQuery.of(context).size.width,
                300,
              ),
              painter: MyPainter(
                xPos,
                yPos,
                text,
                Color(colorValue.value),
                fontSize,
              ),
              child: Container(),
            );
          }),
    );
  }
}

class MyPainter extends CustomPainter {
  MyPainter(this.xPos, this.yPos, this.text, this.color, this.fontSize);

  double? xPos;
  double? yPos;
  double? fontSize;
  String? text;
  Color? color;
  Offset? offset;
  TextPainter? textPainter;
  TextSpan? textSpan;
  TextStyle? textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    textStyle = TextStyle(
      color: color,
      fontSize: fontSize,
    );
    textSpan = TextSpan(
      text: '$text',
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
    offset = Offset(xPos!, yPos!);
    textPainter!.paint(canvas, offset!);
  }

  @override
  bool shouldRepaint(CustomPainter old) {
    return true;
  }
}
