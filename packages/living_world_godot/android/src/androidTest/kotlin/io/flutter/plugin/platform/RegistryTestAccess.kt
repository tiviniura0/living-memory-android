package io.flutter.plugin.platform

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine

/** Test-only access to the package-private registry lookup in pinned Flutter. */
object RegistryTestAccess {
    fun create(engine: FlutterEngine, context: Context, id: Int): PlatformView {
        val registry = engine.platformViewsController.registry as PlatformViewRegistryImpl
        val factory = requireNotNull(registry.getFactory("living_world/godot_view")) { "Real Godot factory is not registered" }
        return factory.create(context, id, null)
    }
}
