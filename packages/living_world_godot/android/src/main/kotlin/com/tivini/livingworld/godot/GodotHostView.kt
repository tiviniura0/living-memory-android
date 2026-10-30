package com.tivini.livingworld.godot

import android.view.View
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.platform.PlatformView

// Compilable RED scaffold: deliberately does not produce ready.
class GodotHostView(activity: FragmentActivity, emit: (Map<String, Any>) -> Unit) : PlatformView {
    private val container = FrameLayout(activity)
    override fun getView(): View = container
    fun open() {}
    fun probe(nonce: String) {}
    override fun dispose() {}
}
