package com.tivini.livingworld.godot

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

/** Per-view channels. A method success means accepted, never native-ready. */
class GodotPlatformView(
    context: Context,
    activity: FragmentActivity?,
    messenger: BinaryMessenger,
    id: Int,
    private val onDisposed: () -> Unit = {}
) : PlatformView, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    constructor(activity: FragmentActivity, messenger: BinaryMessenger, id: Int) : this(activity, activity, messenger, id)

    private var sink: EventChannel.EventSink? = null
    private val methods = MethodChannel(messenger, "living_world/godot/methods/$id")
    private val events = EventChannel(messenger, "living_world/godot/events/$id")
    private val host = activity?.let { GodotHostView(it) { event -> sink?.success(event) } }
    private val fallback = if (host == null) FrameLayout(context) else null
    private var listening = false
    private var channelsDetached = false
    private var closed = false
    private var disposed = false

    init {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }
    override fun getView(): View = host?.getView() ?: fallback!!
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        listening = true
        sink = events
        if (disposed) events.endOfStream()
    }
    override fun onCancel(arguments: Any?) {
        sink = null
        listening = false
        if (disposed) detachChannels()
    }
    private fun detachChannels() {
        if (channelsDetached) return
        channelsDetached = true
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if ((disposed || closed) && call.method != "close") {
            result.error("view_closed", "Renderer view is closed", null)
            return
        }
        try {
            when (call.method) {
                "open" -> {
                    if (sink == null) { result.error("event_listener_required", null, null); return }
                    if (host == null) sink?.success(mapOf("type" to "error", "code" to "fragment_activity_required"))
                    else host.open()
                    result.success(null)
                }
                "probe" -> {
                    val nonce = (call.arguments as? Map<*, *>)?.get("nonce") as? String
                    if (nonce == null || nonce.length !in 1..128) { result.error("invalid_probe", null, null); return }
                    host?.probe(nonce)
                    result.success(null)
                }
                "close" -> {
                    closed = true
                    host?.dispose()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (_: RuntimeException) {
            result.error("native_host_error", null, null)
        }
    }
    override fun dispose() {
        if (disposed) return
        disposed = true
        closed = true
        try { host?.dispose() } finally {
            sink = null
            // Flutter unmounts the child PlatformView before disposing the parent
            // controller. Keep its close/cancel endpoint until that subscription
            // cancels, so EventChannel can acknowledge cancellation normally.
            if (!listening) detachChannels()
            onDisposed()
        }
    }
}
