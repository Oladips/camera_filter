// ignore_for_file: must_be_immutable

library camera_filters;

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:camera_filters/videoPlayer.dart';
import 'package:camera_filters/zettlo/timer_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'zettlo/filter_selector.dart';

@immutable
class CameraScreenPlugin extends StatefulWidget {
  Function(dynamic)? onDone;
  Function(String) onVideoDone;
  List<Color>? filters;
  bool applyFilters;
  List<Color>? gradientColors;
  final double maxHeight;
  final double maxWidth;
  final String customGalleryImage;
  final String customOrangeCheckImage;
  final String cuatomCameraSwitch;
  final String customFilterSwitch;
  final String customFilterImage;
  Widget? profileIconWidget;
  Widget? sendButtonWidget;

  CameraScreenPlugin({
    Key? key,
    this.onDone,
    required this.onVideoDone,
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
    required this.customFilterImage,
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
  Timer? recorderTimer;
  int? d;
  Offset? focusOffset;
  ValueNotifier<bool> isFilter = ValueNotifier(false);
  FlashMode? _currentFlashMode;
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

  startRecorderTimer() {
    recorderTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        setState(() {
          _recordedTime++;
        });
      },
    );
  }

  stopRecorderTimer() async {
    setState(() {
      recorderTimer?.cancel();
    });
  }

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
        d = null;
        _recordedTime = 0.0;
        stopRecorderTimer();
        setState(() {});
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayer(
              value.path,
              filters: _filters,
              selectedFilter: _filterColor.value,
              onVideoDone: widget.onVideoDone,
            ),
          ),
        );
      },
    );
  }

  pauseRecording() async {
    await controller?.pauseVideoRecording().then(
      (value) async {
        stopRecorderTimer();
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
                startRecorderTimer();
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
          startRecorderTimer();
        },
      );
    }
  }

  resumeRecording() async {
    await controller?.resumeVideoRecording().then(
      (value) async {
        startRecorderTimer();
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
            break;
          default:
            break;
        }
      }
    });
    controller?.prepareForVideoRecording();

    Future.delayed(Duration(seconds: 2), () {
      controller?.setFlashMode(FlashMode.off);
      _currentFlashMode = controller?.value.flashMode;
    });

    camLoading = false;
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
                                          cameraUsage = false;
                                          recording = false;
                                          recordingPaused = false;
                                          recordedFile = value;
                                          if (value != null) {
                                            stopRecorderTimer();
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => VideoPlayer(
                                                  value.path,
                                                  filters: _filters,
                                                  selectedFilter: _filterColor.value,
                                                  onVideoDone: widget.onVideoDone,
                                                ),
                                              ),
                                            );
                                          }

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
                                      return SelectTimer();
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
                      child: FilterSelector(
                        filterImage: widget.customFilterImage,
                        filters: _filters,
                        selectedFilter: _filterColor.value,
                        onFilterChanged: _onFilterChanged,
                        onTap: () {},
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        );
      }),
    );
  }
}
