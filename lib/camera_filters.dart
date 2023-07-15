// ignore_for_file: must_be_immutable

library camera_filters;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:camera_filters/src/edit_image_screen.dart';
import 'package:camera_filters/src/filters.dart';
import 'package:camera_filters/src/widgets/circularProgress.dart';
import 'package:camera_filters/videoPlayer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class CameraScreenPlugin extends StatefulWidget {
  Function(dynamic)? onDone;
  Function(dynamic)? onVideoDone;
  List<Color>? filters;
  bool applyFilters;
  List<Color>? gradientColors;
  final double maxHeight;
  final double maxWidth;
  final String customGalleryImage;
  final String customOrangeCheckImage;
  final String cuatomCameraSwitch;
  final String customFilterSwitch;
  final Widget selectTimer;
  final Widget filterSelector;

//! my ownn imports
  Timer? timer;
  int? d;
  Offset? focusOffset;

  Widget? profileIconWidget;
  Widget? sendButtonWidget;

  CameraScreenPlugin({
    Key? key,
    this.onDone,
    this.onVideoDone,
    this.filters,
    this.profileIconWidget,
    this.applyFilters = true,
    this.gradientColors,
    this.sendButtonWidget,
    required this.maxHeight,
    required this.maxWidth,
    required this.customGalleryImage,
    required this.customOrangeCheckImage,
    required this.cuatomCameraSwitch,
    required this.customFilterSwitch,
    required this.selectTimer,
    required this.filterSelector,
  }) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreenPlugin> with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _sizeAnimation;
  late AnimationController _focusController;
  late Animation<double> _focusSizeAnimation;

  CameraController? controller;

  List<CameraDescription> cameras = [];
  bool camLoading = false;
  Timer? timer;
  int? d;
  Offset? focusOffset;
  ValueNotifier<bool> isFilter = ValueNotifier(false);
  FlashMode? _currentFlashMode;
  String? outputPath;
  XFile? recordedFile;
  double baseScale = 1.0;
  double baseAngle = 0.0;
  double scaleFactor = 1.0;
  double zoomLevel = 1.0;
  double minZoom = 1.0;
  double maxZoom = 1.0;
  double _recordedTime = 0.0;
  bool recording = false;
  bool cameraUsage = false;
  bool recordingPaused = false;
  bool postEditStage = false;
  bool isTimer = false;
  bool _isRearCameraSelected = true;
  final _filterColor = ValueNotifier<Color>(Colors.transparent);

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) async {
    if (controller == null) {
      return;
    }
    if (!controller!.value.isInitialized) {
      return;
    }
    focusOffset = details.localPosition;
    _focusController.forward();
    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    setState(() {});

    controller!.setExposurePoint(offset);
    controller!.setFocusPoint(offset);
    await Future.delayed(const Duration(milliseconds: 800));
    focusOffset = null;
    _focusController.reverse();
    setState(() {});
  }

  toggleFlash() async {
    if (controller == null || !controller!.value.isInitialized) {
      return;
    }
    switch (_currentFlashMode) {
      case FlashMode.torch:
        await controller?.setFlashMode(FlashMode.off);
        _currentFlashMode = FlashMode.off;
        break;
      case FlashMode.auto:
        await controller?.setFlashMode(FlashMode.torch);
        _currentFlashMode = FlashMode.torch;
        break;
      case FlashMode.off:
        await controller?.setFlashMode(FlashMode.auto);
        _currentFlashMode = FlashMode.auto;
        break;
      default:
        await controller?.setFlashMode(FlashMode.auto);
        _currentFlashMode = FlashMode.auto;
    }
    setState(() {});
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    camLoading = true;
    setState(() {});
    final previousCameraController = controller;

    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.veryHigh,
      enableAudio: true,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.jpeg : ImageFormatGroup.bgra8888,
    );

    await previousCameraController?.dispose();

    if (mounted) {
      setState(() {
        controller = cameraController;
      });
    }
    cameraController.addListener(() {
      if (mounted) setState(() {});
    });

    try {
      await cameraController.initialize().then(
        (value) async {
          if (mounted) {
            await controller?.getMaxZoomLevel().then((value) => maxZoom = value);
            await controller?.getMinZoomLevel().then((value) => minZoom = value);
            setState(() {});
          }
        },
      );
      _currentFlashMode = controller?.value.flashMode;
      camLoading = false;
      setState(() {});

      controller?.prepareForVideoRecording();
    } on CameraException catch (e) {
      print('Error initializing camera: $e');
    }
  }

  void _onFilterChanged(Color value) {
    _filterColor.value = value;
  }

  void isFilterChange() {
    isFilter.value = !isFilter.value;
  }

  ///list of filters color
  final _filters = [
    Colors.transparent,
    ...List.generate(
      Colors.primaries.length,
      (index) => Colors.primaries[(index) % Colors.primaries.length],
    )
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _focusController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _sizeAnimation = TweenSequence(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 300, end: 500),
        weight: 200,
      ),
    ]).animate(_controller);

    _focusSizeAnimation = TweenSequence(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 60, end: 70),
        weight: 200,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 70, end: 60),
        weight: 200,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 65, end: 70),
        weight: 200,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 70, end: 65),
        weight: 200,
      ),
    ]).animate(_focusController);
    initCamera();
  }

  stopVideoRecording() async {
    await controller?.stopVideoRecording().then(
      (value) async {
        //Todo move the reset camera function oout of this place
        cameraUsage = false;
        recording = false;
        recordedFile = value;
        recordingPaused = false;
        outputPath = value.path;
        // await context.read<CameraProvider>().stopTimer();
        // await context.read<CameraProvider>().updateVideoPath(outputPath);
        setState(() {});
      },
    );
  }

  pauseRecording() async {
    await controller?.pauseVideoRecording().then(
      (value) async {
        // await context.read<CameraProvider>().pauseTimer();
        cameraUsage = false;
        recording = false;
        recordingPaused = true;
        setState(() {});
      },
    );
  }

  startRecording() async {
    cameraUsage = true;
    recording = true;
    recordingPaused = false;
    if (d != null) {
      isTimer = true;
    }
    _controller.forward();
    await Future.delayed(const Duration(milliseconds: 1000));
    _controller.reverse();
    setState(() {});

    if (d != null) {
      timer = Timer.periodic(
        Duration(seconds: 1),
        (timer) async {
          if (d == 0) {
            timer.cancel();
            isTimer = false;
            d = null;
            setState(() {});
            await controller?.startVideoRecording().then(
              (value) async {
                // await context.read<CameraProvider>().startTimer();
              },
            );
            return;
          }
          setState(() {});
          d = d! - 1;
          _controller.forward();
          await Future.delayed(const Duration(milliseconds: 500));
          _controller.reverse();
        },
      );
    } else {
      await controller?.startVideoRecording().then(
        (value) async {
          // await context.read<CameraProvider>().startTimer();
        },
      );
    }
  }

  resumeRecording() async {
    await controller?.resumeVideoRecording().then(
      (value) async {
        // await context.read<CameraProvider>().startTimer();
        cameraUsage = true;
        recording = true;
        recordingPaused = false;
        setState(() {});
      },
    );
  }

  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      //! Resume preview
      if (cameraController.value.previewPauseOrientation == null) {
        //! Restart all processes
        onNewCameraSelected(cameraController.description);
      } else {
        //! Continue all processes
        cameraController.resumePreview();
        controller?.prepareForVideoRecording();
      }
    } else if (state == AppLifecycleState.inactive) {
      //! if video is recording, pause.
      cameraController.pausePreview();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  showInSnackBar(String error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $error')));
  }

  ///timer Widget
  // timer() {
  //   t = Timer.periodic(Duration(seconds: 1), (timer) {
  //     time.value = timer.tick.toString();
  //   });
  // }

  ///timer function
  String formatHHMMSS(int seconds) {
    int hours = (seconds / 3600).truncate();
    seconds = (seconds % 3600).truncate();
    int minutes = (seconds / 60).truncate();

    String hoursStr = (hours).toString().padLeft(2, '0');
    String minutesStr = (minutes).toString().padLeft(2, '0');
    String secondsStr = (seconds % 60).toString().padLeft(2, '0');

    if (hours == 0) {
      return "$minutesStr:$secondsStr";
    }

    return "$hoursStr:$minutesStr:$secondsStr";
  }

  ///this function will initialize camera
  initCamera() async {
    WidgetsFlutterBinding.ensureInitialized();
    camLoading = true;
    setState(() {});
    cameras = await availableCameras();
    controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.jpeg : ImageFormatGroup.bgra8888,
    );
    _currentFlashMode = controller?.value.flashMode;
    await controller?.initialize().then((value) async {
      if (!mounted) return;
      await controller?.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await controller?.getMaxZoomLevel().then((value) => maxZoom = value);
      await controller?.getMinZoomLevel().then((value) => minZoom = value);

      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            // Handle access errors here.
            break;
          default:
            // Handle other errors here.
            break;
        }
      }
    });
    controller?.prepareForVideoRecording();

    Future.delayed(Duration(seconds: 2), () {
      controller?.setFlashMode(FlashMode.off);
      _currentFlashMode = controller?.value.flashMode;
    });

    camLoading = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Builder(builder: (context) {
        if (_recordedTime == 60) {
          if (controller != null && controller!.value.isInitialized) {
            if (controller!.value.isRecordingVideo) {
              stopVideoRecording();
            }
          }
        }
        return Builder(builder: (context) {
          if (outputPath == null) {
            return SafeArea(
              child: Stack(
                children: [
                  Container(
                    height: widget.maxHeight * 0.92,
                    width: widget.maxWidth,
                    color: Colors.black,
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      child: Builder(builder: (context) {
                        if (camLoading) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: Color.fromRGBO(240, 128, 55, 1),
                            ),
                          );
                        }
                        return OverflowBox(
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: GestureDetector(
                              onScaleStart: (details) {
                                baseScale = zoomLevel;
                                setState(() {});
                              },
                              onScaleUpdate: (scale) async {
                                zoomLevel = (baseScale * scale.scale).clamp(minZoom, maxZoom);
                                if (controller != null && controller!.value.isInitialized) {
                                  await controller?.setZoomLevel(zoomLevel);
                                }

                                setState(() {});
                              },
                              child: Container(
                                width: widget.maxWidth,
                                color: Colors.black,
                                child: Builder(builder: (context) {
                                  if (controller != null && controller!.value.isInitialized) {
                                    return ValueListenableBuilder(
                                        valueListenable: _filterColor,
                                        builder: (context, value, _) {
                                          return ColorFiltered(
                                            colorFilter: ColorFilter.mode(
                                              _filterColor.value,
                                              BlendMode.softLight,
                                            ),
                                            child: CameraPreview(
                                              controller!,
                                              child: LayoutBuilder(
                                                builder: (context, constraints) {
                                                  return GestureDetector(
                                                    behavior: HitTestBehavior.opaque,
                                                    onTapDown: (details) {
                                                      onViewFinderTap(details, constraints);
                                                    },
                                                  );
                                                },
                                              ),
                                            ),
                                          );
                                        });
                                  }

                                  return SizedBox.shrink();
                                }),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Builder(builder: (context) {
                    if (isTimer) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      height: widget.maxHeight,
                      width: widget.maxWidth,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Builder(builder: (context) {
                                      if (cameraUsage) {
                                        return const SizedBox.shrink();
                                      }
                                      return InkWell(
                                        onTap: () async {
                                          if (controller != null && controller!.value.isInitialized) {
                                            if (controller!.value.isRecordingVideo || controller!.value.isRecordingPaused) {
                                              await stopVideoRecording();
                                            }
                                          }

                                          // await camera.discardAndCancel();
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
                                      );
                                    }),
                                    Builder(builder: (context) {
                                      if (cameraUsage) {
                                        return const SizedBox.shrink();
                                      }
                                      return InkWell(
                                        onTap: () async {
                                          if (controller != null && controller!.value.isInitialized) {
                                            if (controller!.value.isRecordingVideo || controller!.value.isRecordingPaused) {
                                              await stopVideoRecording();
                                            } else {
                                              // camera.discardAndCancel();
                                            }
                                          } else {
                                            // camera.discardAndCancel();
                                          }
                                        },
                                        child: Container(
                                          height: 50,
                                          width: 50,
                                          child: SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: Icon(
                                              Icons.clear,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      );
                                    })
                                  ],
                                ),
                              ),
                              SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 8,
                                      padding: EdgeInsets.symmetric(horizontal: 24),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(seconds: 1),
                                      width: (widget.maxWidth - 48) * (_recordedTime / 60),
                                      height: 8,
                                      padding: EdgeInsets.symmetric(horizontal: 24),
                                      decoration: BoxDecoration(
                                        color: Color.fromRGBO(240, 128, 55, 1),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    height: 10,
                                    width: 10,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    _recordedTime.toString(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  )
                                ],
                              )
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 36),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Builder(builder: (context) {
                                  if (cameraUsage) {
                                    return SizedBox(
                                      width: 60,
                                    );
                                  }
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      GestureDetector(
                                        onTap: () async {
                                          await ImagePicker()
                                              .pickVideo(
                                            source: ImageSource.gallery,
                                          )
                                              .then(
                                            (value) async {
                                              // await camera.resetCamera();
                                              cameraUsage = false;
                                              recording = false;
                                              recordingPaused = false;
                                              recordedFile = value;
                                              outputPath = value?.path;
                                              // await camera.stopTimer();
                                              // await camera.updateVideoPath(outputPath);

                                              setState(() {});
                                            },
                                          );
                                        },
                                        child: Container(
                                          width: 60,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                          ),
                                          padding: EdgeInsets.all(7),
                                          child: Image.asset(
                                            widget.customGalleryImage,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 5),
                                      Text(
                                        "Upload",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      height: 80,
                                      width: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withOpacity(0.3),
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 500),
                                      height: 80,
                                      width: 80,
                                      decoration: BoxDecoration(
                                        color: Color.fromRGBO(240, 128, 55, 1),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () async {
                                        if (controller != null && controller!.value.isInitialized) {
                                          if (controller!.value.isRecordingPaused) {
                                            resumeRecording();
                                          } else if (controller!.value.isRecordingVideo) {
                                            pauseRecording();
                                          } else if (!controller!.value.isRecordingVideo) {
                                            startRecording();
                                          }
                                        }
                                      },
                                      child: Container(
                                        height: 64,
                                        width: 64,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                        ),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: Builder(
                                            builder: (builder) {
                                              if (recording && recordingPaused == false) {
                                                return Icon(
                                                  Icons.pause_outlined,
                                                  color: Colors.red,
                                                  size: 30,
                                                );
                                              }

                                              if (recording == false && recordingPaused) {
                                                return Icon(
                                                  Icons.play_arrow_rounded,
                                                  color: Colors.red,
                                                  size: 30,
                                                );
                                              }

                                              return Center(
                                                child: Container(
                                                  height: 20,
                                                  width: 20,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: () async {
                                        stopVideoRecording();
                                      },
                                      child: Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                        ),
                                        padding: EdgeInsets.all(7),
                                        child: Image.asset(
                                          widget.customOrangeCheckImage,
                                          fit: BoxFit.contain,
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
                          ),
                        ],
                      ),
                    );
                  }),
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
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    if (controller != null && controller!.value.isInitialized) {
                                      if (controller!.value.isRecordingVideo || controller!.value.isRecordingPaused) {
                                        controller?.setDescription(cameras[_isRearCameraSelected ? 0 : 1]);
                                      } else {
                                        onNewCameraSelected(cameras[_isRearCameraSelected ? 0 : 1]);
                                      }
                                    }
                                    setState(() {
                                      _isRearCameraSelected = !_isRearCameraSelected;
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(shape: BoxShape.circle),
                                    child: SizedBox(
                                      height: 30,
                                      width: 30,
                                      child: Image.asset(
                                        widget.cuatomCameraSwitch,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 7),
                                Expanded(
                                  child: Text(
                                    "Switch Camera",
                                    textAlign: TextAlign.center,
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
                          Builder(builder: (context) {
                            if (cameraUsage) {
                              return SizedBox.shrink();
                            }
                            return SizedBox(
                              height: 80,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(height: 10),
                                  GestureDetector(
                                    onTap: () async {
                                      toggleFlash();
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color.fromRGBO(19, 15, 38, 1.0),
                                      ),
                                      child: SizedBox(
                                        height: 30,
                                        width: 30,
                                        child: Icon(
                                          _currentFlashMode == FlashMode.off
                                              ? Icons.flash_off_outlined
                                              : _currentFlashMode == FlashMode.auto
                                                  ? Icons.flash_auto_rounded
                                                  : Icons.flash_on_rounded,
                                          color: Colors.white,
                                          size: 17,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 7),
                                  Expanded(
                                    child: Text(
                                      "Flash",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            );
                          }),
                          Builder(builder: (context) {
                            if (cameraUsage) {
                              return SizedBox.shrink();
                            }

                            return SizedBox(
                              height: 80,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(height: 10),
                                  GestureDetector(
                                    onTap: () async {
                                      if (isFilter.value) {
                                        isFilter.value = false;
                                      }

                                      final s = await showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        isDismissible: true,
                                        backgroundColor: Colors.transparent,
                                        enableDrag: true,
                                        builder: (context) {
                                          return widget.selectTimer;
                                        },
                                      );

                                      if (!mounted) return;
                                      if (s != null) {
                                        d = s;
                                        setState(() {});
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color.fromRGBO(19, 15, 38, 1.0),
                                      ),
                                      child: SizedBox(
                                        height: 30,
                                        width: 30,
                                        child: Icon(
                                          Icons.timer,
                                          color: Colors.white,
                                          size: 17,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 7),
                                  Expanded(
                                    child: Text(
                                      "Timer",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            );
                          }),
                          Builder(builder: (context) {
                            if (cameraUsage) {
                              return SizedBox.shrink();
                            }
                            return SizedBox(
                              height: 80,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(height: 10),
                                  GestureDetector(
                                    onTap: () async {
                                      isFilterChange();
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color.fromRGBO(19, 15, 38, 1.0),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10000),
                                        child: SizedBox(
                                          height: 30,
                                          width: 30,
                                          child: Image.asset(
                                            widget.customFilterSwitch,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 7),
                                  Expanded(
                                    child: Text(
                                      "Filters",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  Builder(builder: (context) {
                    if (d == null) {
                      return const SizedBox.shrink();
                    }

                    if (d! < 1) {
                      return const SizedBox.shrink();
                    }
                    if (isTimer == false) {
                      return const SizedBox.shrink();
                    }
                    return Center(
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return Container(
                            child: Text(
                              "$d",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: _sizeAnimation.value,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
                  Builder(builder: (context) {
                    if (focusOffset == null) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      top: focusOffset?.dy,
                      left: focusOffset?.dx,
                      child: AnimatedBuilder(
                        animation: _focusController,
                        builder: (context, _) {
                          return Icon(
                            Icons.filter_center_focus_outlined,
                            color: Colors.white,
                            size: _focusSizeAnimation.value,
                            weight: 0.1,
                            fill: .1,
                            grade: .1,
                            opticalSize: 1,
                          );
                        },
                      ),
                    );
                  }),
                  ValueListenableBuilder(
                    valueListenable: isFilter,
                    builder: (context, value, _) {
                      if (value == true) {
                        return Positioned(
                          left: 0.0,
                          right: 0.0,
                          bottom: 0.0,
                          child: widget.filterSelector,
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            );
          }
          return SizedBox();
          // return Stack(
          //   children: [
          //     Positioned(
          //       left: 0.0,
          //       right: 0.0,
          //       bottom: 0.0,
          //       child: ValueListenableBuilder(
          //           valueListenable: cameraChange,
          //           builder: (context, value, Widget? c) {
          //             return cameraChange.value == false ? _buildFilterSelector() : videoRecordingWidget();
          //           }),
          //     ),
          //     Positioned(
          //       right: 10.0,
          //       top: 30.0,
          //       child: widget.profileIconWidget ?? Container(),
          //     ),
          //     Positioned(
          //       left: 10.0,
          //       top: 30.0,
          //       child: Row(
          //         children: [
          //           /// icon for flash modes
          //           IconButton(
          //             onPressed: () {
          //               /// if flash count is zero flash will off
          //               if (flashCount.value == 0) {
          //                 flashCount.value = 1;
          //                 sp.write("flashCount", 1);
          //                 _controller!.setFlashMode(FlashMode.torch);

          //                 /// if flash count is one flash will on
          //               } else if (flashCount.value == 1) {
          //                 flashCount.value = 2;
          //                 sp.write("flashCount", 2);
          //                 _controller!.setFlashMode(FlashMode.auto);
          //               }

          //               /// if flash count is two flash will auto
          //               else {
          //                 flashCount.value = 0;
          //                 sp.write("flashCount", 0);
          //                 _controller!.setFlashMode(FlashMode.off);
          //               }
          //             },
          //             icon: ValueListenableBuilder(
          //                 valueListenable: flashCount,
          //                 builder: (context, value, Widget? c) {
          //                   return Icon(
          //                     flashCount.value == 0
          //                         ? Icons.flash_off
          //                         : flashCount.value == 1
          //                             ? Icons.flash_on
          //                             : Icons.flash_auto,
          //                     color: Colors.white,
          //                   );
          //                 }),
          //           ),
          //           SizedBox(
          //             width: 5,
          //           ),

          //           /// camera change to front or back
          //           IconButton(
          //             icon: Icon(
          //               Icons.cameraswitch,
          //               color: Colors.white,
          //             ),
          //             onPressed: () {
          //               if (_controller!.description.lensDirection == CameraLensDirection.front) {
          //                 final CameraDescription selectedCamera = cameras[0];
          //                 _initCameraController(selectedCamera);
          //               } else {
          //                 final CameraDescription selectedCamera = cameras[1];
          //                 _initCameraController(selectedCamera);
          //               }
          //             },
          //           ),
          //           SizedBox(
          //             width: 5,
          //           ),
          //           ValueListenableBuilder(
          //               valueListenable: cameraChange,
          //               builder: (context, value, Widget? c) {
          //                 return IconButton(
          //                   icon: Icon(
          //                     cameraChange.value == false ? Icons.videocam : Icons.camera,
          //                     color: Colors.white,
          //                   ),
          //                   onPressed: () {
          //                     if (cameraChange.value == false) {
          //                       cameraChange.value = true;
          //                       _controller!.prepareForVideoRecording();
          //                     } else {
          //                       cameraChange.value = false;
          //                     }
          //                   },
          //                 );
          //               }),
          //         ],
          //       ),
          //     ),
          //   ],
          // );
        });
      }),
    );
  }

  // flashCheck() {
  //   if (sp.read("flashCount") == 1) {
  //     _controller!.setFlashMode(FlashMode.off);
  //   }
  // }

  // /// function will call when user tap on picture button
  // void onTakePictureButtonPressed(context) {
  //   takePicture(context).then((String? filePath) async {
  //     if (_controller!.value.isInitialized) {
  //       if (filePath != null) {
  //         Navigator.push(
  //           context,
  //           MaterialPageRoute(
  //               builder: (context) => EditImageScreen(
  //                     path: filePath,
  //                     applyFilters: widget.applyFilters,
  //                     sendButtonWidget: widget.sendButtonWidget,
  //                     filter: ColorFilter.mode(widget.filterColor == null ? _filterColor.value : widget.filterColor!.value, BlendMode.softLight),
  //                     onDone: widget.onDone,
  //                   )),
  //         ).then((value) {
  //           // _controller = CameraController(cameras[0], ResolutionPreset.high);
  //           if (sp.read("flashCount") == 1) {
  //             _controller!.setFlashMode(FlashMode.torch);
  //           }
  //         });
  //         flashCheck();
  //       }
  //     }
  //   });
  // }

  // /// function will call when user take picture
  // Future<String> takePicture(context) async {
  //   if (!_controller!.value.isInitialized) {
  //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: camera is not initialized')));
  //   }
  //   final dirPath = await getTemporaryDirectory();
  //   String filePath = '${dirPath.path}/${timestamp()}.jpg';

  //   try {
  //     final picture = await _controller!.takePicture();
  //     filePath = picture.path;
  //   } on CameraException catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.description}')));
  //   }
  //   return filePath;
  // }

  // /// timestamp for image creation date
  // String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  // /// widget will build the filter selector
  // Widget _buildFilterSelector() {
  //   return FilterSelector(
  //     onFilterChanged: _onFilterChanged,
  //     filters: widget.applyFilters == false ? [] : widget.filters ?? _filters,
  //     onTap: () {
  //       if (capture == false) {
  //         capture = true;
  //         onTakePictureButtonPressed(context);
  //         Future.delayed(Duration(seconds: 3), () {
  //           capture = false;
  //         });
  //       }
  //     },
  //   );
  // }

  // /// function initialize camera controller
  // Future _initCameraController(CameraDescription cameraDescription) async {
  //   /// 1
  //   _controller = CameraController(cameraDescription, ResolutionPreset.high);

  //   /// 2
  //   /// If the controller is updated then update the UI.
  //   _controller!.addListener(() {
  //     /// 3
  //     if (_controller!.value.hasError) {
  //       print('Camera error ${_controller!.value.errorDescription}');
  //     }
  //   });

  //   /// 4
  //   try {
  //     await _controller!.initialize();
  //   } on CameraException catch (e) {
  //     print(e);
  //   }
  //   setState(() {});
  // }

  // ///video recording function
  // Widget videoRecordingWidget() {
  //   return Padding(
  //     padding: const EdgeInsets.only(bottom: 10),
  //     child: GestureDetector(
  //       onLongPress: () async {
  //         // if(controller.value ){

  //         await _controller!.prepareForVideoRecording();
  //         await _controller!.startVideoRecording();
  //         timer();
  //         controller.forward();
  //         _rotationController!.forward();
  //         // }
  //       },
  //       onLongPressEnd: (v) async {
  //         t!.cancel();
  //         time.value = "";
  //         controller.reset();
  //         _rotationController!.reset();
  //         final file = await _controller!.stopVideoRecording();
  //         flashCheck();
  //         Navigator.push(
  //           context,
  //           MaterialPageRoute(
  //               builder: (context) => VideoPlayer(
  //                     file.path,
  //                     applyFilters: widget.applyFilters,
  //                     onVideoDone: widget.onVideoDone,
  //                     sendButtonWidget: widget.sendButtonWidget,
  //                   )),
  //         ).then((value) {
  //           if (sp.read("flashCount") == 1) {
  //             _controller!.setFlashMode(FlashMode.torch);
  //           }
  //         });
  //       },
  //       child: Container(
  //         width: 70,
  //         height: 70,
  //         child: ConstrainedBox(
  //           constraints: BoxConstraints(minWidth: 10, minHeight: 10),
  //           child: Stack(
  //             alignment: Alignment.bottomCenter,
  //             children: [
  //               if (_showWaves) ...[
  //                 Blob(color: Color(0xff0092ff), scale: _scale, rotation: _rotation),
  //                 Blob(color: Color(0xff4ac7b7), scale: _scale, rotation: _rotation * 2 - 30),
  //                 Blob(color: Color(0xffa4a6f6), scale: _scale, rotation: _rotation * 3 - 45),
  //               ],
  //               Container(
  //                 constraints: BoxConstraints.expand(),
  //                 child: AnimatedSwitcher(
  //                   child: Container(
  //                     width: 70,
  //                     height: 70,
  //                     decoration: BoxDecoration(color: Color(0xffd51820), borderRadius: BorderRadius.circular(100)),
  //                   ),
  //                   duration: Duration(milliseconds: 300),
  //                 ),
  //                 decoration: BoxDecoration(
  //                   shape: BoxShape.circle,
  //                   color: Colors.white,
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
}
