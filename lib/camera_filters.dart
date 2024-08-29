library camera_filters;

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

@immutable
class CameraScreenPlugin extends StatefulWidget {
  final Function(XFile) onVideoDone;
  final double maxHeight;
  final double maxWidth;

  CameraScreenPlugin({
    Key? key,
    required this.onVideoDone,
    required this.maxHeight,
    required this.maxWidth,
  }) : super(key: key);

  @override
  State<CameraScreenPlugin> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreenPlugin> with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;

  final cameraController = ValueNotifier<CameraController?>(null);
  final cameraList = ValueNotifier<List<CameraDescription>>([]);
  final cameraFlashMode = ValueNotifier<FlashMode?>(null);
  final recordFile = ValueNotifier<XFile?>(null);
  final cameraLoading = ValueNotifier<bool>(false);
  final isFilter = ValueNotifier(false);
  final cameraMaxZoom = ValueNotifier(1.0);
  final cameraMinZoom = ValueNotifier(1.0);
  final cameraZoomLevel = ValueNotifier(1.0);
  final isRearCameraSelected = ValueNotifier(true);
  final recordedTime = ValueNotifier(0.0);
  final recordTimer = ValueNotifier<Timer?>(null);
  final cameraBaseScale = ValueNotifier(1.0);

  toggleFlash() async {
    if (cameraController.value == null || !cameraController.value!.value.isInitialized) return;
    switch (cameraFlashMode.value) {
      case FlashMode.torch:
        await cameraController.value!.setFlashMode(FlashMode.off);
        cameraFlashMode.value = FlashMode.off;
        break;
      case FlashMode.auto:
        await cameraController.value!.setFlashMode(FlashMode.torch);
        cameraFlashMode.value = FlashMode.torch;
        break;
      case FlashMode.off:
        await cameraController.value!.setFlashMode(FlashMode.auto);
        cameraFlashMode.value = FlashMode.auto;
        break;
      default:
        await cameraController.value!.setFlashMode(FlashMode.auto);
        cameraFlashMode.value = FlashMode.auto;
    }
  }

  void onNewCameraSelected(
    CameraDescription cameraDescription,
  ) async {
    cameraLoading.value = true;
    if (cameraController.value == null) return;
    final previousCameraController = cameraController.value;

    final CameraController controller = CameraController(
      cameraDescription,
      ResolutionPreset.veryHigh,
      enableAudio: true,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.jpeg : ImageFormatGroup.bgra8888,
    );
    await previousCameraController?.dispose();
    if (mounted) cameraController.value = controller;
    try {
      if (cameraController.value == null) return;
      await cameraController.value!.initialize().then(
        (value) async {
          if (mounted) {
            await cameraController.value!.getMaxZoomLevel().then((value) => cameraMaxZoom.value = value);
            await cameraController.value!.getMinZoomLevel().then((value) => cameraMinZoom.value = value);
          }
        },
      );
      cameraFlashMode.value = cameraController.value!.value.flashMode;
      cameraLoading.value = false;
      cameraController.value!.prepareForVideoRecording();
    } on CameraException catch (_) {
      Navigator.pop(context);
    }
  }

  void isFilterChange() {
    isFilter.value = !isFilter.value;
  }

  startRecorderTimer() {
    recordTimer.value = Timer.periodic(const Duration(seconds: 1), (timer) {
      recordedTime.value = recordedTime.value + 1;
    });
  }

  pauseRecorderTimer() async {
    if (recordTimer.value == null) return;
    recordTimer.value?.cancel();
  }

  stopRecorderTimer() async {
    if (recordTimer.value == null) return;
    recordTimer.value?.cancel();
    recordedTime.value = 0.0;
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    initCamera();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    super.initState();
  }

  stopVideoRecording() async {
    if (cameraController.value == null) return;
    await cameraController.value!.stopVideoRecording().then(
      (value) async {
        await stopRecorderTimer();
      },
    );
  }

  saveVideoRecording() async {
    if (cameraController.value == null) return;
    await cameraController.value!.stopVideoRecording().then(
      (value) async {
        await stopRecorderTimer();
        widget.onVideoDone(value);
      },
    );
  }

  pauseRecording() async {
    if (cameraController.value == null) return;
    await cameraController.value!.pauseVideoRecording().then(
      (value) async {
        pauseRecorderTimer();
      },
    );
  }

  startRecording() async {
    if (cameraController.value == null) return;
    await cameraController.value!.startVideoRecording().then(
      (value) async {
        startRecorderTimer();
      },
    );
  }

  resumeRecording() async {
    if (cameraController.value == null) return;
    await cameraController.value?.resumeVideoRecording().then(
      (value) async {
        startRecorderTimer();
      },
    );
  }

  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final CameraController? camController = cameraController.value;
    if (camController == null || !camController.value.isInitialized) return;

    if (state == AppLifecycleState.resumed) {
      // Resume preview
      if (camController.value.previewPauseOrientation == null) {
        // Restart all processes
        onNewCameraSelected(camController.description);
      } else {
        // Continue all processes
        camController.resumePreview();
        if (cameraController.value == null || !cameraController.value!.value.isInitialized) return;
        cameraController.value!.prepareForVideoRecording();
      }
    } else if (state == AppLifecycleState.inactive) {
      // if video is recording, pause.
      camController.pausePreview();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    if (cameraController.value != null) cameraController.value?.dispose();
    super.dispose();
  }

  initCamera() async {
    WidgetsFlutterBinding.ensureInitialized();
    cameraLoading.value = true;
    cameraList.value = await availableCameras();
    cameraController.value = CameraController(
      cameraList.value[0],
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.jpeg : ImageFormatGroup.bgra8888,
    );
    cameraFlashMode.value = cameraController.value?.value.flashMode;
    await cameraController.value?.initialize().then((value) async {
      if (!mounted) return;
      await cameraController.value?.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await cameraController.value?.getMaxZoomLevel().then((value) => cameraMaxZoom.value = value);
      await cameraController.value?.getMinZoomLevel().then((value) => cameraMinZoom.value = value);
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            Navigator.pop(context);
            break;
          default:
            break;
        }
      }
    });
    cameraController.value?.prepareForVideoRecording();
    await Future.delayed(Duration(seconds: 2), () {
      cameraController.value?.setFlashMode(FlashMode.off);
      cameraFlashMode.value = cameraController.value?.value.flashMode;
    });
    cameraLoading.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        cameraController,
        cameraList,
        cameraFlashMode,
        recordFile,
        cameraLoading,
        isFilter,
        cameraMaxZoom,
        cameraMinZoom,
        isRearCameraSelected,
        recordedTime,
        recordTimer,
        cameraBaseScale,
      ]),
      builder: (context, _) {
        return Material(
          color: Colors.black,
          child: Builder(
            builder: (context) {
              if (recordedTime.value == 60.0) {
                if (cameraController.value != null && cameraController.value!.value.isInitialized) {
                  if (cameraController.value!.value.isRecordingVideo) stopVideoRecording();
                }
              }
              return PopScope(
                canPop: false,
                onPopInvoked: (didPop) async {
                  if (cameraController.value!.value.isRecordingVideo) return;
                  SchedulerBinding.instance.addPostFrameCallback((callback) {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  });
                },
                child: SafeArea(
                  child: Stack(
                    children: [
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: widget.maxHeight * 0.92,
                        ),
                        height: widget.maxHeight * 0.92,
                        width: widget.maxWidth,
                        color: Colors.black,
                        child: Builder(
                          builder: (context) {
                            if (cameraLoading.value) {
                              return Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation(Color.fromRGBO(240, 128, 55, 1)),
                                ),
                              );
                            }
                            return OverflowBox(
                              alignment: Alignment.center,
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: GestureDetector(
                                  onScaleStart: (details) {
                                    cameraBaseScale.value = cameraZoomLevel.value;
                                  },
                                  onScaleUpdate: (scale) async {
                                    if (cameraController.value == null || !cameraController.value!.value.isInitialized) return;
                                    cameraZoomLevel.value = (cameraBaseScale.value * scale.scale).clamp(cameraMinZoom.value, cameraMaxZoom.value);
                                    await cameraController.value!.setZoomLevel(cameraZoomLevel.value);
                                  },
                                  child: Container(
                                    width: widget.maxWidth,
                                    color: Colors.black,
                                    child: Builder(
                                      builder: (context) {
                                        if (cameraController.value == null || !cameraController.value!.value.isInitialized) return SizedBox.shrink();
                                        return CameraPreview(cameraController.value!);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Builder(
                        builder: (context) {
                          if (cameraController.value == null || !cameraController.value!.value.isInitialized) return const SizedBox.shrink();
                          return Container(
                            height: widget.maxHeight * .92,
                            width: widget.maxWidth,
                            padding: EdgeInsets.symmetric(vertical: 15),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: InkWell(
                                        onTap: () async {
                                          if (cameraController.value == null || !cameraController.value!.value.isInitialized) return;
                                          if (cameraController.value!.value.isRecordingVideo || cameraController.value!.value.isRecordingPaused) {
                                            await stopVideoRecording();
                                          }
                                          Navigator.pop(context);
                                        },
                                        child: SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: Icon(
                                            Icons.close,
                                            color: Colors.white,
                                          ),
                                        ),
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
                                          recordedTime.value.toString(),
                                          style: GoogleFonts.outfit(
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
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Builder(
                                          builder: (context) {
                                            if (cameraController.value != null &&
                                                (cameraController.value!.value.isRecordingVideo || cameraController.value!.value.isRecordingPaused))
                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  GestureDetector(
                                                    onTap: () async {
                                                      stopVideoRecording();
                                                    },
                                                    child: Icon(
                                                      Icons.stop_circle_rounded,
                                                      size: 48,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  SizedBox(height: 5),
                                                  Text(
                                                    "Stop Recording",
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w400,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                GestureDetector(
                                                  onTap: () async {
                                                    final video = await ImagePicker().pickVideo(source: ImageSource.gallery);
                                                    if (!mounted) return;
                                                    if (video != null) {
                                                      stopRecorderTimer();
                                                      await widget.onVideoDone(video);
                                                    }
                                                  },
                                                  child: Container(
                                                    width: 48,
                                                    height: 48,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                    ),
                                                    padding: EdgeInsets.all(7),
                                                    child: Icon(
                                                      Icons.photo_rounded,
                                                      size: 40,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(height: 5),
                                                Text(
                                                  "Gallery",
                                                  textAlign: TextAlign.center,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w400,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                      Expanded(
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            GestureDetector(
                                              onTap: () async {
                                                if (cameraController.value == null || !cameraController.value!.value.isInitialized) return;
                                                if (cameraController.value!.value.isRecordingPaused) {
                                                  resumeRecording();
                                                } else if (cameraController.value!.value.isRecordingVideo) {
                                                  pauseRecording();
                                                } else {
                                                  startRecording();
                                                }

                                                setState(() {});
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
                                                      if (cameraController.value != null && cameraController.value!.value.isRecordingPaused) {
                                                        return Icon(
                                                          Icons.play_arrow_rounded,
                                                          color: Colors.red,
                                                          size: 40,
                                                        );
                                                      }

                                                      if (cameraController.value != null && cameraController.value!.value.isRecordingVideo) {
                                                        return Icon(
                                                          Icons.pause_outlined,
                                                          color: Colors.red,
                                                          size: 30,
                                                        );
                                                      }

                                                      return Center(
                                                        child: Container(
                                                          height: 48,
                                                          width: 48,
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
                                      ),
                                      Expanded(
                                        child: Builder(
                                          builder: (context) {
                                            if (cameraController.value != null &&
                                                (cameraController.value!.value.isRecordingPaused || cameraController.value!.value.isRecordingVideo)) {
                                              return InkWell(
                                                onTap: () {
                                                  saveVideoRecording();
                                                },
                                                child: Column(
                                                  children: [
                                                    Icon(
                                                      Icons.check_circle,
                                                      color: Color.fromRGBO(240, 128, 55, 1),
                                                      size: 48,
                                                    ),
                                                    SizedBox(height: 5),
                                                    Text(
                                                      "Continue",
                                                      textAlign: TextAlign.center,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w400,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12, top: 17),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  if (cameraController.value == null || !cameraController.value!.value.isInitialized) return;
                                  if (cameraController.value!.value.isRecordingVideo || cameraController.value!.value.isRecordingPaused) {
                                    cameraController.value?.setDescription(cameraList.value[isRearCameraSelected.value ? 1 : 0]);
                                  } else {
                                    onNewCameraSelected(cameraList.value[isRearCameraSelected.value ? 1 : 0]);
                                  }
                                  isRearCameraSelected.value = !isRearCameraSelected.value;
                                },
                                child: Icon(
                                  Icons.cameraswitch_rounded,
                                  size: 30,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 16),
                              GestureDetector(
                                onTap: () async {
                                  toggleFlash();
                                },
                                child: Icon(
                                  cameraFlashMode.value == FlashMode.off
                                      ? Icons.flash_off_outlined
                                      : cameraFlashMode.value == FlashMode.auto
                                          ? Icons.flash_auto_rounded
                                          : Icons.flash_on_rounded,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
