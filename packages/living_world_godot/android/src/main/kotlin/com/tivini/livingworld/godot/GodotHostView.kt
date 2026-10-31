package com.tivini.livingworld.godot

import android.content.Intent
import android.content.res.Configuration
import android.view.SurfaceHolder
import android.view.SurfaceView
import androidx.fragment.app.Fragment
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.platform.PlatformView
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import java.util.UUID

/** One native engine per process. No simulation or access to MemoryStore. */
class GodotHostView(private val activity: FragmentActivity, private var emit: ((Map<String, Any>) -> Unit)?) : PlatformView {
    private val container = FrameLayout(activity)
    private val surface = SurfaceView(activity).apply { setZOrderOnTop(true) }
    private val session = UUID.randomUUID().toString()
    private var disposed = false
    private var fragment: WorldGodotFragment? = null
    private var ready = false

    init {
        container.addView(surface, FrameLayout.LayoutParams(-1, -1))
        surface.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) { attachSurface() }
            override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
                if (!disposed && owner === this@GodotHostView) fragment?.resize(width, height)
            }
            override fun surfaceDestroyed(holder: SurfaceHolder) {
                // Only this presentation SurfacePackage is detached. The Godot
                // view hierarchy stays attached to its SurfaceControlViewHost.
            }
        })
    }

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
            attachSurface()
        } catch (_: RuntimeException) {
            error("host_initialization_failed")
            dispose()
        }
    }
    private fun attachSurface() {
        if (disposed || owner !== this || !surface.holder.surface.isValid) return
        val host = fragment ?: return
        try {
            host.present(surface)
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
        // Pause rendering without detaching the live Godot hierarchy. A new
        // presentation receives a new SurfacePackage, never the GLSurfaceView.
        fragment?.suspendPresentation()
        fragment = null
        container.removeAllViews()
    }
}

/** Activity callbacks are temporary; the official engine has process lifetime. */
class WorldGodotFragment : Fragment() {
    fun present(surface: SurfaceView) = ProcessGodotHost.present(requireActivity(), surface)
    fun resize(width: Int, height: Int) { activity?.let { ProcessGodotHost.resize(it, width, height) } }
    fun suspendPresentation() { activity?.let { ProcessGodotHost.suspendPresentation(it) } }
    override fun onStart() {
        super.onStart()
        activity?.let { ProcessGodotHost.start(it) }
    }
    override fun onResume() {
        super.onResume()
        activity?.let { ProcessGodotHost.resume(it) }
    }
    override fun onPause() {
        activity?.let { ProcessGodotHost.pause(it) }
        super.onPause()
    }
    override fun onStop() {
        activity?.let { ProcessGodotHost.stop(it) }
        super.onStop()
    }
    override fun onConfigurationChanged(config: Configuration) {
        super.onConfigurationChanged(config)
        activity?.let { ProcessGodotHost.configuration(it, config) }
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        activity?.let { ProcessGodotHost.activityResult(it, requestCode, resultCode, data) }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, results: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, results)
        activity?.let { ProcessGodotHost.permissionsResult(it, requestCode, permissions, results) }
    }
    override fun onDestroy() {
        activity?.let { ProcessGodotHost.detach(it) }
        super.onDestroy()
    }
}
