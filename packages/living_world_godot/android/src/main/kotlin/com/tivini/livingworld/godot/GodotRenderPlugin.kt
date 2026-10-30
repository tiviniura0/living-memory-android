package com.tivini.livingworld.godot

import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

/** Only the real GDScript scene can provide ready and probe events. */
class GodotRenderPlugin(engine: Godot, private val receive: (String, String, String) -> Unit) : GodotPlugin(engine) {
    override fun getPluginName() = "LivingWorldRender"
    override fun getPluginSignals() = setOf(SignalInfo("host_command", String::class.java, String::class.java, String::class.java))
    @UsedByGodot
    fun sceneEvent(session: String, kind: String, value: String) {
        runOnHostThread { receive(session, kind, value) }
    }
    fun command(session: String, action: String, nonce: String = "") {
        emitSignal("host_command", session, action, nonce)
    }
}
