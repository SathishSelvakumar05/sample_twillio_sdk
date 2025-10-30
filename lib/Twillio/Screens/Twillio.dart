import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VideoCallScreen extends StatefulWidget {
  final String accessToken;
  final String roomName;
  const VideoCallScreen({super.key, required this.accessToken, required this.roomName});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> with WidgetsBindingObserver {
  static const eventChannel = EventChannel("twilio_video_events");

  static const platform = MethodChannel("twilio_video");

  bool isAudioMuted = false;
  bool isVideoMuted = false;

  bool isStarted=false;

  // Temporary: list of remote participants (later can be updated from native events)
  List<String> remoteParticipants = []; // Example identities
  Map<String, bool> participantAudioState = {};
  Map<String, bool> participantVideoState = {};


  @override
  void initState() {
    super.initState();
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   const platform = MethodChannel('twilio_video');
    //   platform.invokeMethod('reattachLocalVideoTrack');
    // });
    _connectToRoom();
    _listenForParticipants();
    WidgetsBinding.instance.addObserver(this);

  }
  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);

  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-attach the local video track when app comes to foreground
      // platform.invokeMethod("reattachLocalVideoTrack");
    }
    if (state == AppLifecycleState.paused) {
      // Optionally, pause the track or stop camera
      // platform.invokeMethod("pauseLocalVideoTrack");
    }
    else{
      // platform.invokeMethod("pauseLocalVideoTrack");

    }
  }

  void _listenForParticipants() {
    eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final eventType = event["event"];
        final identity = event["identity"];

        setState(() {
          switch (eventType) {
            case "participant_connected":
              if (!remoteParticipants.contains(identity)) {
                remoteParticipants.add(identity);
              }
              participantAudioState[identity] = true;
                participantVideoState[identity] = true;

              _showConnectionStatus(
                message: "$identity joined the room",
                color: Colors.blueAccent,
                icon: Icons.person_add_alt_1,
              );
              break;

            case "participant_disconnected":
              remoteParticipants.remove(identity);
              participantAudioState.remove(identity);
              participantVideoState.remove(identity);

              _showConnectionStatus(
                message: "$identity left the room",
                color: Colors.redAccent,
                icon: Icons.exit_to_app,
              );
              break;

            case "audio_enabled":
              participantAudioState[identity] = true;
              break;

            case "audio_disabled":
              participantAudioState[identity] = false;
              break;

            case "video_enabled":
              participantVideoState[identity] = true;
              break;

            case "video_disabled":
              participantVideoState[identity] = false;
              break;
            case "room_disconnected":
            // 🟢 Handle disconnection event from native side
              _handleRoomDisconnected(event);
              break;

          // 🟡 NEW: Handle network reconnecting/reconnected events
            case "reconnecting":
              _showConnectionStatus(
                message: "Reconnecting... Please wait",
                color: Colors.orangeAccent,
                icon: Icons.wifi_off,
              );
              break;

            case "reconnected":
              _showConnectionStatus(
                message: "Reconnected successfully",
                color: Colors.greenAccent,
                icon: Icons.wifi,
              );
              break;
          }
        });
      }
    });
  }
  void _handleRoomDisconnected(Map event) {
    final roomName = event["room"];
    print("Room disconnected: $roomName");

    // Optional: show a snackbar or dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Disconnected from room $roomName"),
        backgroundColor: Colors.redAccent,
      ),
    );

    // // Small delay so user can see the message, then pop
    // Future.delayed(const Duration(seconds: 1), () {
    //   if (mounted) Navigator.pop(context);
    // });
  }



  Future<void> _connectToRoom() async {
    try {
      await platform.invokeMethod("connectToRoom", {
        'token': widget.accessToken,
        'roomName': widget.roomName,
      });
      // await platform.invokeMethod("reattachLocalVideoTrack");

      print("Connected to room");
      _listenForParticipants();
    } on PlatformException catch (e) {
      print("Failed to connect: ${e.message}");
    }
  }

  // Widget _buildRemoteGrid() {
  //   final count = remoteParticipants.length;
  //   final crossAxisCount = count <= 2 ? 1 : 2;
  //
  //   return GridView.builder(
  //     itemCount: count,
  //     gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
  //       crossAxisCount: crossAxisCount,
  //       mainAxisSpacing: 4,
  //       crossAxisSpacing: 4,
  //     ),
  //     itemBuilder: (context, index) {
  //       final identity = remoteParticipants[index];
  //
  //       final isAudioOn = participantAudioState[identity] ?? true;
  //       final isVideoOn = participantVideoState[identity] ?? true;
  //       return Container(
  //         decoration: BoxDecoration(
  //           border: Border.all(color: Colors.white24),
  //           borderRadius: BorderRadius.circular(8),
  //         ),
  //         child: Column(
  //           children: [
  //             Expanded(
  //               child: AndroidView(
  //                 viewType: "RemoteVideoView",
  //                 creationParams: {"identity": identity},
  //                 creationParamsCodec: const StandardMessageCodec(),
  //               ),
  //             ),
  //             Text(identity, style: TextStyle(color: Colors.white)),
  //           ],
  //         )
  //
  //       );
  //     },
  //   );
  // }
  Widget _buildRemoteGrid() {
    final count = remoteParticipants.length;
    final crossAxisCount = count <= 2 ? 1 : 2;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: count,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, index) {
        final identity = remoteParticipants[index];
        final isAudioOn = participantAudioState[identity] ?? true;
        final isVideoOn = participantVideoState[identity] ?? true;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // 🎥 Video view
              Positioned.fill(
                child: isVideoOn
                    ? AndroidView(
                  viewType: "RemoteVideoView",
                  creationParams: {"identity": identity},
                  creationParamsCodec: const StandardMessageCodec(),
                )
                    : Container(
                  color: Colors.grey[900],
                  child: Center(
                    child: Icon(Icons.videocam_off,
                        color: Colors.white54, size: 48),
                  ),
                ),
              ),

              // 🧍 Participant info footer
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black54, Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          identity,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isAudioOn ? Icons.mic : Icons.mic_off,
                        color: isAudioOn ? Colors.greenAccent : Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isVideoOn ? Icons.videocam : Icons.videocam_off,
                        color: isVideoOn ? Colors.greenAccent : Colors.redAccent,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),

              // ✨ Subtle border glow for active video
              if (isAudioOn && isVideoOn)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.greenAccent.withOpacity(0.4), width: 1.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocalPreview() {
    return Positioned(
      bottom: 110,
      right: 10,
      child: Container(
        height: 160,
        width: 120,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: AndroidView(
          viewType: "LocalVideoView",
          creationParams: {},
          creationParamsCodec: const StandardMessageCodec(),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 25,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 7),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: isAudioMuted ? Icons.mic_off : Icons.mic,
              onTap: _toggleAudio,
              isActive: isAudioMuted,
              activeColor: Colors.redAccent,
            ),
            _buildControlButton(
              icon: isVideoMuted ? Icons.videocam_off : Icons.videocam,
              onTap: _toggleVideo,
              isActive: isVideoMuted,
              activeColor: Colors.orangeAccent,
            ),
            _buildControlButton(
              icon: Icons.switch_camera,
              onTap: _switchCamera,
              isActive: false,
              activeColor: Colors.blueAccent,
            ),
            _buildControlButton(
              icon: Icons.call_end,
              onTap: _endCall,
              isActive: true,
              activeColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
    Color activeColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isActive
              ? LinearGradient(
            colors: [activeColor.withOpacity(0.8), activeColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : LinearGradient(
            colors: [Colors.grey.shade800, Colors.grey.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive ? activeColor.withOpacity(0.6) : Colors.black54,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  Future<void> _toggleAudio() async {
    final method = isAudioMuted ? "unmuteAudio" : "muteAudio";
    await platform.invokeMethod(method);
    setState(() => isAudioMuted = !isAudioMuted);
  }

  Future<void> _toggleVideo() async {
    final method = isVideoMuted ? "enableVideo" : "disableVideo";
    await platform.invokeMethod(method);
    setState(() => isVideoMuted = !isVideoMuted);
  }

  Future<void> _switchCamera() async {
    await platform.invokeMethod("switchCamera");
  }

  Future<void> _endCall() async {
    await platform.invokeMethod("disconnect");
    Navigator.pop(context);
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            _buildRemoteGrid(),
            _buildLocalPreview(),
            _buildControls(),
          ],
        ),
      ),
    );
  }
  void _showConnectionStatus({
    required String message,
    required Color color,
    required IconData icon,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar(); // hide any existing message

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        backgroundColor: color.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

}
