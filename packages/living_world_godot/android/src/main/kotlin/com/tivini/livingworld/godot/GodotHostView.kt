package com.tivini.livingworld.godot

import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.platform.PlatformView
import org.godotengine.godot.Godot
import org.godotengine.godot.GodotFragment
import org.godotengine.godot.plugin.GodotPlugin
import java.util.UUID

/** One native engine per process. No simulation or access to MemoryStore. */
class GodotHostView(private val activity: FragmentActivity, private var emit: ((Map<String, Any>) -> Unit)?) : PlatformView {
    private val container = FrameLayout(activity)
    private val session = UUID.randomUUID().toString()
    private var disposed = false
    private var fragment: WorldGodotFragment? = null
    private var ready = false

    companion object {
        private var owner: GodotHostView? = null
        private var renderPlugin: GodotRenderPlugin? = null
        private var booted = false
        // 4.5.1 cannot safely reinitialize after its GL surface destroys the engine.
        private var terminated = false
        private val ui = Handler(Looper.getMainLooper())
        internal fun plugins(engine: Godot): Set<GodotPlugin> {
            val plugin = renderPlugin ?: GodotRenderPlugin(engine) { session, kind, value ->
                if (kind == "boot") {
                    booted = true
                    owner?.requestReady()
                } else {
                    owner?.receive(session, kind, value)
                }
            }.also { renderPlugin = it }
            return setOf(plugin)
        }
        internal fun nativeTerminated() {
            ui.post {
                terminated = true
                booted = false
                renderPlugin = null
                owner?.error("renderer_terminated")
            }
        }
    }

    override fun getView(): View = container
    fun open() {
        if (disposed) { error("view_closed"); return }
        if (owner != null && owner !== this) { error("renderer_in_use"); return }
        if (terminated) { error("renderer_restart_required"); return }
        if (activity.supportFragmentManager.isStateSaved) { error("host_not_resumed"); return }
        if (owner === this) { requestReady(); return }
        try { activity.assets.open("world_godot.pck").use { } }
        catch (_: java.io.IOException) { error("missing_pack"); return }
        owner = this
        try {
            val manager = activity.supportFragmentManager
            val existing = manager.findFragmentByTag("living_world_godot")
            val host = existing as? WorldGodotFragment ?: WorldGodotFragment().also {
                manager.beginTransaction().add(it, "living_world_godot").commitNow()
            }
            fragment = host
            val root = host.requireView()
            (root.parent as? ViewGroup)?.removeView(root)
            container.addView(root, FrameLayout.LayoutParams(-1, -1))
            if (booted) requestReady()
        } catch (_: RuntimeException) {
            error("host_initialization_failed")
            dispose()
        }
    }
    private fun requestReady() { renderPlugin?.command(session, "open") }
    private fun receive(eventSession: String, kind: String, value: String) {
        if (disposed || owner !== this || eventSession != session) return
        when (kind) {
            "ready" -> {
                ready = true
                emit?.invoke(mapOf("type" to "ready", "version" to value, "singleton" to "LivingWorldRender"))
            }
            "probe" -> emit?.invoke(mapOf("type" to "probe", "nonce" to value))
        }
    }
    fun probe(nonce: String) {
        if (disposed || owner !== this || !ready) { error("renderer_not_ready"); return }
        if (nonce.length !in 1..128) { error("invalid_probe"); return }
        renderPlugin?.command(session, "probe", nonce)
    }
    private fun error(code: String) { if (!disposed) emit?.invoke(mapOf("type" to "error", "code" to code)) }
    override fun dispose() {
        if (disposed) return
        disposed = true
        emit = null
        ready = false
        if (owner !== this) return
        owner = null
        // Closing a Flutter view must not destroy the process-wide Godot engine.
        // Keep its Fragment registered in the current Activity so the next view
        // can reparent the existing surface and issue a fresh session handshake.
        // A genuine engine shutdown is still reported by nativeTerminated().
        fragment = null
        container.removeAllViews()
    }
}

/** Official fragment drives all Android lifecycle callbacks. Never exit Flutter. */
class WorldGodotFragment : GodotFragment() {
    override fun getCommandLine() = listOf("--main-pack", "res://world_godot.pck", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3")
    override fun getHostPlugins(engine: Godot): Set<GodotPlugin> = GodotHostView.plugins(engine)
    override fun onGodotForceQuit(instance: Godot) { GodotHostView.nativeTerminated() }
    override fun onGodotRestartRequested(instance: Godot) { GodotHostView.nativeTerminated() }
}
