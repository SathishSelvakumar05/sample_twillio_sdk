import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VideoCallScreen extends StatefulWidget {
  final String accessToken;
  final String roomName;
  const VideoCallScreen({super.key, required this.accessToken, required this.roomName});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  static const eventChannel = EventChannel("twilio_video_events");

  static const platform = MethodChannel("twilio_video");

  bool isAudioMuted = false;
  bool isVideoMuted = false;

  // Temporary: list of remote participants (later can be updated from native events)
  List<String> remoteParticipants = []; // Example identities

  @override
  void initState() {
    super.initState();
    _connectToRoom();
    _listenForParticipants();
  }
  void _listenForParticipants() {
    eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final eventType = event["event"];
        final identity = event["identity"];

        setState(() {
          if (eventType == "participant_connected" && !remoteParticipants.contains(identity)) {
            remoteParticipants.add(identity);
          } else if (eventType == "participant_disconnected") {
            remoteParticipants.remove(identity);
          }
        });
      }
    });
  }


  Future<void> _connectToRoom() async {
    try {
      await platform.invokeMethod("connectToRoom", {
        'token': widget.accessToken,
        'roomName': widget.roomName,
      });
      print("Connected to room");
    } on PlatformException catch (e) {
      print("Failed to connect: ${e.message}");
    }
  }

  Widget _buildRemoteGrid() {
    final count = remoteParticipants.length;
    final crossAxisCount = count <= 2 ? 1 : 2;
    return GridView.builder(
      itemCount: count,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final identity = remoteParticipants[index];
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Expanded(
                child: AndroidView(
                  viewType: "RemoteVideoView",
                  creationParams: {"identity": identity},
                  creationParamsCodec: const StandardMessageCodec(),
                ),
              ),
              Text(identity, style: TextStyle(color: Colors.white)),
            ],
          )

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
}
