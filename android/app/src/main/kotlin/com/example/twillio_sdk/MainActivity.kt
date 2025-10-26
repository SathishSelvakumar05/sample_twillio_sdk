package com.example.twillio_sdk

import android.content.Context
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import androidx.annotation.NonNull
import com.twilio.video.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.flutter.plugin.common.StandardMessageCodec
import tvi.webrtc.Camera2Enumerator
import io.flutter.plugin.common.EventChannel


class MainActivity : FlutterActivity() {
    private val EVENT_CHANNEL = "twilio_video_events"
    private var eventSink: EventChannel.EventSink? = null


    private val CHANNEL = "twilio_video"
    private var room: Room? = null
    private var localVideoTrack: LocalVideoTrack? = null
    private var localAudioTrack: LocalAudioTrack? = null
    private var cameraCapturer: Camera2Capturer? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })


        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "connectToRoom" -> {
                    val token = call.argument<String>("token")
                    val roomName = call.argument<String>("roomName")
                    if (token.isNullOrEmpty() || roomName.isNullOrEmpty()) {
                        result.error("ARG_NULL", "Token or RoomName is null", null)
                        return@setMethodCallHandler
                    }
                    connectToRoom(token, roomName)
                    result.success("Connecting to $roomName")
                }

                "muteAudio" -> { localAudioTrack?.enable(false); result.success(null) }
                "unmuteAudio" -> { localAudioTrack?.enable(true); result.success(null) }
                "disableVideo" -> { localVideoTrack?.enable(false); result.success(null) }
                "enableVideo" -> { localVideoTrack?.enable(true); result.success(null) }
                "disconnect" -> { room?.disconnect(); result.success(null) }
                else -> result.notImplemented()
            }
        }

        flutterEngine.platformViewsController.registry.registerViewFactory("LocalVideoView", LocalVideoViewFactory())
        flutterEngine.platformViewsController.registry.registerViewFactory("RemoteVideoView", RemoteVideoViewFactory())
    }

    private fun connectToRoom(token: String, roomName: String) {
        val cameraEnumerator = Camera2Enumerator(this)
        val cameraId = cameraEnumerator.deviceNames.firstOrNull { cameraEnumerator.isFrontFacing(it) }
            ?: cameraEnumerator.deviceNames.firstOrNull()
        if (cameraId == null) {
            Log.e("Twilio", "No camera found!")
            return
        }

        localAudioTrack = LocalAudioTrack.create(this, true)
        cameraCapturer = Camera2Capturer(this, cameraId, object : Camera2Capturer.Listener {
            override fun onFirstFrameAvailable() {
                Log.i("TwilioCamera", "First frame received!")
            }
            override fun onCameraSwitched(newCameraId: String) {
                Log.i("TwilioCamera", "Camera switched to $newCameraId")
            }
            override fun onError(error: Camera2Capturer.Exception) {
                Log.e("Twilio", "Camera error: ${error.message}")
            }
        })

        localVideoTrack = LocalVideoTrack.create(this, true, cameraCapturer!!)
        LocalVideoViewFactory.currentView?.attachTrack(localVideoTrack!!)
            ?: run { LocalVideoViewFactory.pendingTrack = localVideoTrack }

        val connectOptions = ConnectOptions.Builder(token)
            .roomName(roomName)
            .audioTracks(listOfNotNull(localAudioTrack))
            .videoTracks(listOfNotNull(localVideoTrack))
            .build()

        room = Video.connect(this, connectOptions, roomListener)
    }

    private val roomListener = object : Room.Listener {
        override fun onConnected(room: Room) {
            Log.i("Twilio", "Connected to room: ${room.name}")
            room.remoteParticipants.forEach { it.setListener(remoteParticipantListener) }
        }

        override fun onConnectFailure(room: Room, e: TwilioException) {
            Log.e("Twilio", "Connection failed: ${e.message}")
        }

        override fun onDisconnected(room: Room, e: TwilioException?) {
            room.remoteParticipants.forEach { it.setListener(null) }
        }

//        override fun onParticipantConnected(room: Room, participant: RemoteParticipant) {
//            participant.setListener(remoteParticipantListener)
//        }
//
//        override fun onParticipantDisconnected(room: Room, participant: RemoteParticipant) {
//            RemoteVideoViewFactory.detachAllForParticipant(participant.identity)
//        }
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
            runOnUiThread {
                RemoteVideoViewFactory.attachTrack(participant.identity, videoTrack)
            }
        }

        override fun onVideoTrackUnsubscribed(
            participant: RemoteParticipant,
            publication: RemoteVideoTrackPublication,
            videoTrack: RemoteVideoTrack
        ) {
            runOnUiThread {
                RemoteVideoViewFactory.detachTrack(participant.identity, videoTrack)
            }
        }

        // Required but unused listener methods
        override fun onAudioTrackSubscribed(p: RemoteParticipant, pub: RemoteAudioTrackPublication, t: RemoteAudioTrack) {}
        override fun onAudioTrackUnsubscribed(p: RemoteParticipant, pub: RemoteAudioTrackPublication, t: RemoteAudioTrack) {}
        override fun onDataTrackSubscribed(p: RemoteParticipant, pub: RemoteDataTrackPublication, t: RemoteDataTrack) {}
        override fun onDataTrackUnsubscribed(p: RemoteParticipant, pub: RemoteDataTrackPublication, t: RemoteDataTrack) {}
        override fun onVideoTrackPublished(p: RemoteParticipant, pub: RemoteVideoTrackPublication) {}
        override fun onVideoTrackUnpublished(p: RemoteParticipant, pub: RemoteVideoTrackPublication) {}
        override fun onAudioTrackPublished(p: RemoteParticipant, pub: RemoteAudioTrackPublication) {}
        override fun onAudioTrackUnpublished(p: RemoteParticipant, pub: RemoteAudioTrackPublication) {}
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
}

// -------------------- LocalVideoView --------------------
class LocalVideoViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    companion object {
        var currentView: LocalVideoView? = null
        var pendingTrack: LocalVideoTrack? = null
    }

    override fun create(context: Context?, id: Int, args: Any?): PlatformView {
        val view = LocalVideoView(context ?: throw IllegalStateException("Context cannot be null"))
        currentView = view
        pendingTrack?.let {
            view.attachTrack(it)
            pendingTrack = null
        }
        return view
    }
}

class LocalVideoView(context: Context) : PlatformView {
    private val frameLayout = FrameLayout(context)
    private val videoView = VideoView(context)

    init {
        videoView.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        frameLayout.addView(videoView)
    }

    fun attachTrack(track: LocalVideoTrack) = track.addSink(videoView)
    fun detachTrack(track: LocalVideoTrack) = track.removeSink(videoView)
    override fun getView(): View = frameLayout
    override fun dispose() {}
}

// -------------------- RemoteVideoView --------------------
class RemoteVideoViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    companion object {
        private val remoteViews = mutableMapOf<String, RemoteVideoView>()
        private val pendingTracks = mutableMapOf<String, RemoteVideoTrack>()

        fun attachTrack(identity: String, track: RemoteVideoTrack) {
            remoteViews[identity]?.attachTrack(track) ?: run {
                pendingTracks[identity] = track
            }
        }

        fun detachTrack(identity: String, track: RemoteVideoTrack) {
            remoteViews[identity]?.detachTrack(track)
        }

        fun detachAllForParticipant(identity: String) {
            remoteViews.remove(identity)
            pendingTracks.remove(identity)
        }
    }

    override fun create(context: Context?, id: Int, args: Any?): PlatformView {
        val identity = (args as? Map<*, *>)?.get("identity") as? String
            ?: throw IllegalArgumentException("Missing identity for RemoteVideoView")
        val view = RemoteVideoView(context ?: throw IllegalStateException("Context cannot be null"))
        remoteViews[identity] = view
        pendingTracks.remove(identity)?.let { view.attachTrack(it) }
        return view
    }
}

class RemoteVideoView(context: Context) : PlatformView {
    private val frameLayout = FrameLayout(context)
    private val videoView = VideoView(context)

    init {
        videoView.layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        frameLayout.addView(videoView)
    }

    fun attachTrack(track: RemoteVideoTrack) = track.addSink(videoView)
    fun detachTrack(track: RemoteVideoTrack) = track.removeSink(videoView)
    override fun getView(): View = frameLayout
    override fun dispose() {}
}
