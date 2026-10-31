package com.tivini.livingworld.godot

import android.app.Activity
import android.content.Intent
import android.content.res.Configuration
import android.os.Handler
import android.os.Looper
import android.view.SurfaceControlViewHost
import android.view.SurfaceView
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.Lifecycle
import org.godotengine.godot.Godot
import org.godotengine.godot.GodotHost
import org.godotengine.godot.plugin.GodotPlugin
import java.lang.ref.WeakReference

/**
 * One official Godot engine and one attached hierarchy per PROCESS. Activity
 * finish/recreation only replaces a presentation. Never retain an Activity,
 * Fragment or Flutter view in this object's strong fields.
 */
@Suppress("DEPRECATION")
internal object ProcessGodotHost : GodotHost {
    @Volatile private var activityRef = WeakReference<FragmentActivity>(null)
    private val ui = Handler(Looper.getMainLooper())
    private var engine: Godot? = null
    private var surfaceHost: SurfaceControlViewHost? = null
    private var presenting = false

    override fun getActivity(): Activity? = activityRef.get()
    override fun getGodot(): Godot = checkNotNull(engine)
    override fun getCommandLine() = listOf("--main-pack", "res://world_godot.pck", "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3")
    override fun getHostPlugins(engine: Godot): Set<GodotPlugin> = GodotHostView.plugins(engine)
    override fun runOnHostThread(action: Runnable?) { if (action != null) ui.post(action) }

    private fun boundEngine(activity: FragmentActivity): Godot? =
        if (activityRef.get() === activity) engine?.takeIf { it.isInitialized() } else null

    fun present(activity: FragmentActivity, surface: SurfaceView) {
        activityRef = WeakReference(activity)
        val godot = engine ?: Godot.getInstance(activity.applicationContext).also { engine = it }
        if (surfaceHost == null) {
            check(godot.initEngine(this, getCommandLine(), getHostPlugins(godot)))
            val root = checkNotNull(godot.onInitRenderView(this))
            val host = SurfaceControlViewHost(activity.applicationContext, surface.display, surface.hostToken)
            surfaceHost = host
            host.setView(root, maxOf(1, surface.width), maxOf(1, surface.height))
        }
        val host = checkNotNull(surfaceHost)
        resize(activity, surface.width, surface.height)
        surface.setChildSurfacePackage(checkNotNull(host.surfacePackage))
        presenting = true
        if (activity.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) godot.onStart(this)
        if (activity.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) godot.onResume(this)
    }
    fun resize(activity: FragmentActivity, width: Int, height: Int) {
        if (activityRef.get() === activity && width > 0 && height > 0) surfaceHost?.relayout(width, height)
    }
    fun suspendPresentation(activity: FragmentActivity) {
        if (activityRef.get() !== activity) return
        presenting = false
        boundEngine(activity)?.onPause(this)
    }
    fun start(activity: FragmentActivity) { if (presenting) boundEngine(activity)?.onStart(this) }
    fun resume(activity: FragmentActivity) { if (presenting) boundEngine(activity)?.onResume(this) }
    fun pause(activity: FragmentActivity) { boundEngine(activity)?.onPause(this) }
    fun stop(activity: FragmentActivity) { boundEngine(activity)?.onStop(this) }
    fun detach(activity: FragmentActivity) {
        if (activityRef.get() !== activity) return
        pause(activity)
        stop(activity)
        presenting = false
        activityRef = WeakReference(null)
        // Godot 4.5.1 cannot safely restart after JNI shutdown. Keep the single
        // application-context hierarchy paused until another view binds it.
        // Android reclaims these process-owned resources when the process ends.
    }
    fun configuration(activity: FragmentActivity, config: Configuration) {
        boundEngine(activity)?.onConfigurationChanged(config)
    }
    fun activityResult(activity: FragmentActivity, request: Int, result: Int, data: Intent?) {
        boundEngine(activity)?.onActivityResult(request, result, data)
    }
    fun permissionsResult(activity: FragmentActivity, request: Int, permissions: Array<out String>, results: IntArray) {
        boundEngine(activity)?.onRequestPermissionsResult(request, Array<String?>(permissions.size) { permissions[it] }, results)
    }
    override fun onGodotForceQuit(instance: Godot) { GodotHostView.nativeTerminated() }
    override fun onGodotRestartRequested(instance: Godot) { GodotHostView.nativeTerminated() }
}
