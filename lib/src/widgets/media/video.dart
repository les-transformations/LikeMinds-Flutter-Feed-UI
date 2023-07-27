import 'dart:async';
import 'dart:io';

import 'package:flick_video_player/flick_video_player.dart';
import 'package:flutter/material.dart';
import 'package:likeminds_feed_ui_fl/src/widgets/common/buttons/icon_button.dart';
import 'package:likeminds_feed_ui_fl/src/widgets/common/shimmer/post_shimmer.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class LMVideo extends StatefulWidget {
  const LMVideo({
    super.key,
    this.videoUrl,
    this.videoFile,
    this.height,
    this.width,
    this.aspectRatio,
    this.borderRadius,
    this.borderColor,
    this.loaderWidget,
    this.errorWidget,
    this.shimmerWidget,
    this.boxFit,
    this.videoPlayerController,
    this.playButton,
    this.pauseButton,
    this.muteButton,
    this.showControls,
    this.autoPlay,
    this.looping,
    this.allowFullScreen,
    this.allowMuting,
  }) : assert(videoUrl != null || videoFile != null);

  final String? videoUrl;
  final File? videoFile;

  final double? height;
  final double? width;
  final double? aspectRatio; // defaults to 16/9
  final double? borderRadius; // defaults to 0
  final Color? borderColor;

  final Widget? loaderWidget;
  final Widget? errorWidget;
  final Widget? shimmerWidget;

  final BoxFit? boxFit; // defaults to BoxFit.cover

  final VideoPlayerController? videoPlayerController;
  final LMIconButton? playButton;
  final LMIconButton? pauseButton;
  final LMIconButton? muteButton;
  final bool? showControls;
  final bool? autoPlay;
  final bool? looping;
  final bool? allowFullScreen;
  final bool? allowMuting;

  @override
  State<LMVideo> createState() => _LMVideoState();
}

class _LMVideoState extends State<LMVideo> {
  late VideoPlayerController videoPlayerController;
  FlickManager? flickManager;
  ValueNotifier<bool> rebuildOverlay = ValueNotifier(false);
  bool _onTouch = true;
  bool initialiseOverlay = false;

  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> initialiseControllers() async {
    if (widget.videoUrl != null) {
      videoPlayerController = widget.videoPlayerController ??
          VideoPlayerController.networkUrl(
            Uri.parse(widget.videoUrl!),
            videoPlayerOptions: VideoPlayerOptions(
              allowBackgroundPlayback: false,
            ),
          );
    } else {
      videoPlayerController = widget.videoPlayerController ??
          VideoPlayerController.file(
            widget.videoFile!,
            videoPlayerOptions: VideoPlayerOptions(
              allowBackgroundPlayback: false,
            ),
          );
    }
    flickManager ??= FlickManager(
      videoPlayerController: videoPlayerController,
      autoPlay: true,
      autoInitialize: true,
    );

    if (!flickManager!
        .flickVideoManager!.videoPlayerController!.value.isInitialized) {
      await flickManager!.flickVideoManager!.videoPlayerController!
          .initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return FutureBuilder(
      future: initialiseControllers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LMPostShimmer();
        } else if (snapshot.connectionState == ConnectionState.done) {
          if (!initialiseOverlay) {
            _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
              initialiseOverlay = true;
              _onTouch = false;
              rebuildOverlay.value = !rebuildOverlay.value;
            });
          }
          return Stack(children: [
            GestureDetector(
              onTap: () {
                _onTouch = !_onTouch;
                rebuildOverlay.value = !rebuildOverlay.value;
              },
              child: VisibilityDetector(
                key: Key('post_video_${widget.videoUrl ?? widget.videoFile}'),
                onVisibilityChanged: (visibilityInfo) async {
                  var visiblePercentage = visibilityInfo.visibleFraction * 100;
                  if (visiblePercentage <= 50) {}
                  if (visiblePercentage > 50) {
                    if (!videoPlayerController.value.isInitialized) {
                      await flickManager!
                          .flickVideoManager!.videoPlayerController!
                          .initialize();
                    }
                    flickManager!.flickControlManager!.play();
                    rebuildOverlay.value = !rebuildOverlay.value;
                  }
                },
                child: Container(
                  width: widget.width ?? screenSize.width,
                  height: widget.height ?? screenSize.width,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(widget.borderRadius ?? 0),
                    border: Border.all(
                      color: widget.borderColor ?? Colors.transparent,
                      width: 0,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: FlickVideoPlayer(
                    flickManager: flickManager!,
                    flickVideoWithControls:
                        widget.showControls != null && widget.showControls!
                            ? FlickVideoWithControls(
                                aspectRatioWhenLoading:
                                    widget.aspectRatio ?? 16 / 9,
                                controls: const FlickPortraitControls(),
                                videoFit: widget.boxFit ?? BoxFit.cover,
                              )
                            : FlickVideoWithControls(
                                aspectRatioWhenLoading:
                                    widget.aspectRatio ?? 16 / 9,
                                controls: const SizedBox(),
                                videoFit: widget.boxFit ?? BoxFit.cover,
                              ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder(
                  valueListenable: rebuildOverlay,
                  builder: (context, _, __) {
                    return Visibility(
                      visible: _onTouch,
                      child: Container(
                        alignment: Alignment.center,
                        child: TextButton(
                          style: ButtonStyle(
                            shape: MaterialStateProperty.all(const CircleBorder(
                                side: BorderSide(color: Colors.white))),
                          ),
                          child: Icon(
                            flickManager!.flickVideoManager!
                                    .videoPlayerController!.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            size: 30,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            _timer?.cancel();

                            // pause while video is playing, play while video is pausing

                            flickManager!.flickVideoManager!
                                    .videoPlayerController!.value.isPlaying
                                ? flickManager!
                                    .flickVideoManager!.videoPlayerController!
                                    .pause()
                                : flickManager!
                                    .flickVideoManager!.videoPlayerController!
                                    .play();
                            rebuildOverlay.value = !rebuildOverlay.value;

                            // Auto dismiss overlay after 1 second
                            _timer = Timer.periodic(
                                const Duration(milliseconds: 2500), (_) {
                              _onTouch = false;
                              rebuildOverlay.value = !rebuildOverlay.value;
                            });
                          },
                        ),
                      ),
                    );
                  }),
            )
          ]);
        } else {
          return const SizedBox();
        }
      },
    );
  }
}
