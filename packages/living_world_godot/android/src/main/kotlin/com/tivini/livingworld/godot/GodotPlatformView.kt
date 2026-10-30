package com.tivini.livingworld.godot

import android.view.View
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

// Compilable channel RED scaffold; deliberately does not open the host.
class GodotPlatformView(activity: FragmentActivity, messenger: BinaryMessenger, id: Int) : PlatformView, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val host = GodotHostView(activity) {}
    override fun getView(): View = host.getView()
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) { result.success(null) }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {}
    override fun onCancel(arguments: Any?) {}
    override fun dispose() { host.dispose() }
}
