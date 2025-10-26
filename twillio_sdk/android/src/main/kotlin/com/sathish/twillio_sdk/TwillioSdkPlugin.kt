package com.sathish.twillio_sdk

import android.content.Context
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import androidx.annotation.NonNull
import com.twilio.video.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec
import tvi.webrtc.Camera2Enumerator
import tvi.webrtc.Camera2Capturer

class TwillioSdkPlugin : FlutterPlugin {

    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    private var room: Room? = null
    private var localVideoTrack: LocalVideoTrack? = null
    private var localAudioTrack: LocalAudioTrack? = null
    private var cameraCapturer: Camera2Capturer? = null

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        val messenger = binding.binaryMessenger
        val context = binding.applicationContext

        // Channels
        channel = MethodChannel(messenger, "twilio_video")
        eventChannel = EventChannel(messenger, "twilio_video_events")

        // Event channel setup
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        // Method channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> {
                    val token = call.argument<String>("token")
                    if (token.isNullOrEmpty()) {
                        result.error("ARG_NULL", "Token cannot be null or empty", null)
                        return@setMethodCallHandler
                    }
                    connectToRoom(context, token)
                    result.success("Connecting...")
                }
                "muteAudio" -> { localAudioTrack?.enable(false); result.success(null) }
                "unmuteAudio" -> { localAudioTrack?.enable(true); result.success(null) }
                "disableVideo" -> { localVideoTrack?.enable(false); result.success(null) }
                "enableVideo" -> { localVideoTrack?.enable(true); result.success(null) }
                "switchCamera" -> {
                    try { cameraCapturer?.switchCamera(null) } catch (e: Exception) {
                        Log.e("Twilio", "Camera switch error: ${e.message}")
                    }
                    result.success(null)
                }
                "disconnect" -> { room?.disconnect(); result.success(null) }
                else -> result.notImplemented()
            }
        }

        // Register platform views
        binding.platformViewRegistry.registerViewFactory("LocalVideoView", LocalVideoViewFactory())
        binding.platformViewRegistry.registerViewFactory("RemoteVideoView", RemoteVideoViewFactory())
    }

    private fun connectToRoom(context: Context, token: String) {
        val cameraEnumerator = Camera2Enumerator(context)
        val cameraId = cameraEnumerator.deviceNames.firstOrNull { cameraEnumerator.isFrontFacing(it) }
            ?: cameraEnumerator.deviceNames.firstOrNull()
        if (cameraId == null) {
            Log.e("Twilio", "No camera found!")
            return
        }

        localAudioTrack = LocalAudioTrack.create(context, true)
        cameraCapturer = Camera2Capturer(context, cameraId, object : Camera2Capturer.Listener {
            override fun onFirstFrameAvailable() = Log.i("Twilio", "First frame available")
            override fun onCameraSwitched(newCameraId: String) = Log.i("Twilio", "Camera switched: $newCameraId")
            override fun onError(error: Camera2Capturer.Exception) = Log.e("Twilio", "Camera error: ${error.message}")
        })

        localVideoTrack = LocalVideoTrack.create(context, true, cameraCapturer!!)
        LocalVideoViewFactory.currentView?.attachTrack(localVideoTrack!!)
            ?: run { LocalVideoViewFactory.pendingTrack = localVideoTrack }

        val connectOptions = ConnectOptions.Builder(token)
            .audioTracks(listOfNotNull(localAudioTrack))
            .videoTracks(listOfNotNull(localVideoTrack))
            .build()

        room = Video.connect(context, connectOptions, roomListener)
    }

    private val roomListener = object : Room.Listener {
        override fun onConnected(room: Room) {
            room.remoteParticipants.forEach { it.setListener(remoteParticipantListener) }
        }

        override fun onConnectFailure(room: Room, e: TwilioException) {
            Log.e("Twilio", "Connect failure: ${e.message}")
        }

        override fun onDisconnected(room: Room, e: TwilioException?) {
            room.remoteParticipants.forEach { it.setListener(null) }
        }

        override fun onParticipantConnected(room: Room, participant: RemoteParticipant) {
            participant.setListener(remoteParticipantListener)
            eventSink?.success(mapOf("event" to "participant_connected", "identity" to participant.identity))
        }

        override fun onParticipantDisconnected(room: Room, participant: RemoteParticipant) {
            eventSink?.success(mapOf("event" to "participant_disconnected", "identity" to participant.identity))
        }

        override fun onRecordingStarted(room: Room) {}
        override fun onRecordingStopped(room: Room) {}
        override fun onReconnecting(room: Room, e: TwilioException) {}
        override fun onReconnected(room: Room) {}
    }

    private val remoteParticipantListener = object : RemoteParticipant.Listener {
        override fun onVideoTrackSubscribed(
            participant: RemoteParticipant,
            publication: RemoteVideoTrackPublication,
            videoTrack: RemoteVideoTrack
        ) {
            RemoteVideoViewFactory.attachTrack(participant.identity, videoTrack)
        }

        override fun onVideoTrackUnsubscribed(
            participant: RemoteParticipant,
            publication: RemoteVideoTrackPublication,
            videoTrack: RemoteVideoTrack
        ) {
            RemoteVideoViewFactory.detachTrack(participant.identity, videoTrack)
        }

        override fun onAudioTrackSubscribed(p: RemoteParticipant, pub: RemoteAudioTrackPublication, t: RemoteAudioTrack) {}
        override fun onAudioTrackUnsubscribed(p: RemoteParticipant, pub: RemoteAudioTrackPublication, t: RemoteAudioTrack) {}
        override fun onDataTrackSubscribed(p: RemoteParticipant, pub: RemoteDataTrackPublication, t: RemoteDataTrack) {}
        override fun onDataTrackUnsubscribed(p: RemoteParticipant, pub: RemoteDataTrackPublication, t: RemoteDataTrack) {}
        override fun onAudioTrackPublished(p: RemoteParticipant, pub: RemoteAudioTrackPublication) {}
        override fun onAudioTrackUnpublished(p: RemoteParticipant, pub: RemoteAudioTrackPublication) {}
        override fun onVideoTrackPublished(p: RemoteParticipant, pub: RemoteVideoTrackPublication) {}
        override fun onVideoTrackUnpublished(p: RemoteParticipant, pub: RemoteVideoTrackPublication) {}
        override fun onDataTrackPublished(p: RemoteParticipant, pub: RemoteDataTrackPublication) {}
        override fun onDataTrackUnpublished(p: RemoteParticipant, pub: RemoteDataTrackPublication) {}
        override fun onAudioTrackEnabled(p: RemoteParticipant, pub: RemoteAudioTrackPublication) {}
        override fun onAudioTrackDisabled(p: RemoteParticipant, pub: RemoteAudioTrackPublication) {}
        override fun onVideoTrackEnabled(p: RemoteParticipant, pub: RemoteVideoTrackPublication) {}
        override fun onVideoTrackDisabled(p: RemoteParticipant, pub: RemoteVideoTrackPublication) {}
        override fun onAudioTrackSubscriptionFailed(p: RemoteParticipant, pub: RemoteAudioTrackPublication, e: TwilioException) {}
        override fun onVideoTrackSubscriptionFailed(p: RemoteParticipant, pub: RemoteVideoTrackPublication, e: TwilioException) {}
        override fun onDataTrackSubscriptionFailed(p: RemoteParticipant, pub: RemoteDataTrackPublication, e: TwilioException) {}
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventSink = null
        room?.disconnect()
    }
}

// -------------------- LocalVideoView --------------------
class LocalVideoViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    companion object {
        var currentView: LocalVideoView? = null
        var pendingTrack: LocalVideoTrack? = null
    }

    override fun create(context: Context?, id: Int, args: Any?): PlatformView {
        val view = LocalVideoView(context!!)
        currentView = view
        pendingTrack?.let {
            view.attachTrack(it)
            pendingTrack = null
        }
        return view
    }
}

class LocalVideoView(context: Context) : PlatformView {
    private val frame = FrameLayout(context)
    private val videoView = VideoView(context)

    init {
        videoView.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        frame.addView(videoView)
    }

    fun attachTrack(track: LocalVideoTrack) = track.addSink(videoView)
    override fun getView(): View = frame
    override fun dispose() {}
}

// -------------------- RemoteVideoView --------------------
class RemoteVideoViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    companion object {
        private val views = mutableMapOf<String, RemoteVideoView>()
        private val pendingTracks = mutableMapOf<String, RemoteVideoTrack>()

        fun attachTrack(identity: String, track: RemoteVideoTrack) {
            views[identity]?.attachTrack(track) ?: run { pendingTracks[identity] = track }
        }

        fun detachTrack(identity: String, track: RemoteVideoTrack) {
            views[identity]?.detachTrack(track)
        }
    }

    override fun create(context: Context?, id: Int, args: Any?): PlatformView {
        val identity = (args as? Map<*, *>)?.get("identity") as? String
            ?: throw IllegalArgumentException("Missing identity for RemoteVideoView")
        val view = RemoteVideoView(context!!)
        views[identity] = view
        pendingTracks.remove(identity)?.let { view.attachTrack(it) }
        return view
    }
}

class RemoteVideoView(context: Context) : PlatformView {
    private val frame = FrameLayout(context)
    private val videoView = VideoView(context)

    init {
        videoView.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        frame.addView(videoView)
    }

    fun attachTrack(track: RemoteVideoTrack) = track.addSink(videoView)
    fun detachTrack(track: RemoteVideoTrack) = track.removeSink(videoView)
    override fun getView(): View = frame
    override fun dispose() {}
}
