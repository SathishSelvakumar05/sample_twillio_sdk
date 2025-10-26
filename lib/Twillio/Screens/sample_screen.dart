// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/gestures.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// class VideoCallScreen extends StatefulWidget {
//   final String accessToken;
//   final String roomName;
//
//   const VideoCallScreen({super.key, required this.accessToken, required this.roomName});
//
//   @override
//   State<VideoCallScreen> createState() => _VideoCallScreenState();
// }
//
// class _VideoCallScreenState extends State<VideoCallScreen> {
//   static const platform = MethodChannel("twilio_video");
//   static const eventChannel = EventChannel("twilio_video_events");
//
//   bool isAudioMuted = false;
//   bool isVideoMuted = false;
//
//   // Dynamic remote participants
//   List<String> remoteParticipants = [];
//
//   // Local preview draggable position
//   double localX = 20, localY = 20;
//
//   // Active speaker
//   String? activeSpeaker;
//
//   @override
//   void initState() {
//     super.initState();
//     _requestPermissions();
//     _connectToRoom();
//     _listenForParticipants();
//
//     // Enable Hybrid Composition for Android
//     // if (Platform.isAndroid) {
//     //   AndroidViewController.enableHybridComposition();
//     // }
//   }
//
//   Future<void> _requestPermissions() async {
//     await [
//       Permission.camera,
//       Permission.microphone,
//     ].request();
//   }
//
//   void _listenForParticipants() {
//     eventChannel.receiveBroadcastStream().listen((event) {
//       if (event is Map) {
//         final eventType = event["event"];
//         final identity = event["identity"];
//
//         setState(() {
//           if (eventType == "participant_connected" && !remoteParticipants.contains(identity)) {
//             remoteParticipants.add(identity);
//           } else if (eventType == "participant_disconnected") {
//             remoteParticipants.remove(identity);
//             if (activeSpeaker == identity) activeSpeaker = null;
//           } else if (eventType == "active_speaker") {
//             activeSpeaker = identity;
//           }
//         });
//       }
//     });
//   }
//
//   Future<void> _connectToRoom() async {
//     try {
//       await platform.invokeMethod("connectToRoom", {
//         'token': widget.accessToken,
//         'roomName': widget.roomName,
//       });
//       print("Connected to room");
//     } on PlatformException catch (e) {
//       print("Failed to connect: ${e.message}");
//     }
//   }
//
//   Future<void> _toggleAudio() async {
//     final method = isAudioMuted ? "unmuteAudio" : "muteAudio";
//     await platform.invokeMethod(method);
//     setState(() => isAudioMuted = !isAudioMuted);
//   }
//
//   Future<void> _toggleVideo() async {
//     final method = isVideoMuted ? "enableVideo" : "disableVideo";
//     await platform.invokeMethod(method);
//     setState(() => isVideoMuted = !isVideoMuted);
//   }
//
//   Future<void> _switchCamera() async {
//     await platform.invokeMethod("switchCamera");
//   }
//
//   Future<void> _endCall() async {
//     await platform.invokeMethod("disconnect");
//     Navigator.pop(context);
//   }
//
//   Widget _localPreviewWidget() {
//     return SizedBox(
//       height: 160,
//       width: 120,
//       child: AndroidView(
//         viewType: "LocalVideoView",
//         creationParams: {},
//         creationParamsCodec: const StandardMessageCodec(),
//         gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{}.toSet(),
//       ),
//     );
//   }
//
//   Widget _buildRemoteGrid() {
//     final count = remoteParticipants.length;
//     final crossAxisCount = count <= 2 ? 1 : 2;
//
//     return GridView.builder(
//       padding: const EdgeInsets.all(8),
//       itemCount: count,
//       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: crossAxisCount,
//         mainAxisSpacing: 8,
//         crossAxisSpacing: 8,
//       ),
//       itemBuilder: (context, index) {
//         final identity = remoteParticipants[index];
//         return AnimatedContainer(
//           duration: const Duration(milliseconds: 300),
//           decoration: BoxDecoration(
//             border: Border.all(
//               color: activeSpeaker == identity ? Colors.greenAccent : Colors.white24,
//               width: activeSpeaker == identity ? 3 : 1,
//             ),
//             borderRadius: BorderRadius.circular(16),
//           ),
//           child: Stack(
//             children: [
//               ClipRRect(
//                 borderRadius: BorderRadius.circular(16),
//                 child: AndroidView(
//                   viewType: "RemoteVideoView",
//                   creationParams: {"identity": identity},
//                   creationParamsCodec: const StandardMessageCodec(),
//                   gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{}.toSet(),
//                 ),
//               ),
//               Positioned(
//                 bottom: 4,
//                 left: 4,
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                   decoration: BoxDecoration(
//                       color: Colors.black54, borderRadius: BorderRadius.circular(12)),
//                   child: Text(identity,
//                       style: const TextStyle(color: Colors.white, fontSize: 12)),
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildControls() {
//     return Positioned(
//       bottom: 30,
//       left: 16,
//       right: 16,
//       child: Container(
//         padding: const EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: Colors.black.withOpacity(0.3),
//           borderRadius: BorderRadius.circular(40),
//           border: Border.all(color: Colors.white24),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             _buildControlButton(icon: isAudioMuted ? Icons.mic_off : Icons.mic, onTap: _toggleAudio),
//             _buildControlButton(icon: isVideoMuted ? Icons.videocam_off : Icons.videocam, onTap: _toggleVideo),
//             _buildControlButton(icon: Icons.switch_camera, onTap: _switchCamera),
//             _buildControlButton(icon: Icons.call_end, color: Colors.red, onTap: _endCall),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildControlButton({required IconData icon, required VoidCallback onTap, Color color = Colors.white}) {
//     return GestureDetector(
//       onTap: onTap,
//       child: CircleAvatar(
//         radius: 28,
//         backgroundColor: Colors.black54,
//         child: Icon(icon, color: color, size: 28),
//       ),
//     );
//   }
//
//   Widget _buildParticipantDrawer() {
//     return DraggableScrollableSheet(
//       initialChildSize: 0.08,
//       minChildSize: 0.08,
//       maxChildSize: 0.35,
//       builder: (context, scrollController) {
//         return Container(
//           decoration: BoxDecoration(
//             color: Colors.black.withOpacity(0.6),
//             borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
//           ),
//           child: ListView.builder(
//             controller: scrollController,
//             itemCount: remoteParticipants.length,
//             itemBuilder: (context, index) {
//               final identity = remoteParticipants[index];
//               return ListTile(
//                 leading: CircleAvatar(child: Text(identity[0])),
//                 title: Text(identity, style: const TextStyle(color: Colors.white)),
//                 trailing: Icon(Icons.mic_off, color: Colors.red),
//               );
//             },
//           ),
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: SafeArea(
//         child: Stack(
//           children: [
//             _buildRemoteGrid(),
//
//             // Draggable local preview
//             Positioned(
//               left: localX,
//               top: localY,
//               child: Draggable(
//                 feedback: _localPreviewWidget(),
//                 childWhenDragging: Container(),
//                 child: _localPreviewWidget(),
//                 onDragEnd: (details) {
//                   setState(() {
//                     localX = details.offset.dx.clamp(0, MediaQuery.of(context).size.width - 140);
//                     localY = details.offset.dy.clamp(0, MediaQuery.of(context).size.height - 180);
//                   });
//                 },
//               ),
//             ),
//
//             _buildControls(),
//             _buildParticipantDrawer(),
//           ],
//         ),
//       ),
//     );
//   }
// }
