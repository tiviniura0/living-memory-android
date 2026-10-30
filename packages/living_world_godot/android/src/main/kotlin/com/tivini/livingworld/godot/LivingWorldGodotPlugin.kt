package com.tivini.livingworld.godot

import android.content.Context
import androidx.fragment.app.FragmentActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class LivingWorldGodotPlugin : FlutterPlugin, ActivityAware {
    private var activity: FragmentActivity? = null
    private val views = mutableSetOf<GodotPlatformView>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        binding.platformViewRegistry.registerViewFactory("living_world/godot_view", object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
            override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
                lateinit var view: GodotPlatformView
                view = GodotPlatformView(context, activity, binding.binaryMessenger, viewId) { views.remove(view) }
                views.add(view)
                return view
            }
        })
    }
    private fun releaseViews() {
        views.toList().forEach { it.dispose() }
        views.clear()
        activity = null
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) { releaseViews() }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity as? FragmentActivity }
    override fun onDetachedFromActivityForConfigChanges() { releaseViews() }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { onAttachedToActivity(binding) }
    override fun onDetachedFromActivity() { releaseViews() }
}
