package com.tivini.livingworld.godot

import android.content.pm.ActivityInfo
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.tivini.livingworld.MainActivity
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit

// Removing the real scene callback, owner guard, reattach or lifecycle handling
// must respectively break these tests. No fake engine or ready source is used.
@RunWith(AndroidJUnit4::class)
class GodotHostTest {
    private fun ui(block: () -> Unit) = InstrumentationRegistry.getInstrumentation().runOnMainSync(block)
    private fun event(queue: LinkedBlockingQueue<Map<String, Any>>, type: String): Map<String, Any> {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(20)
        while (System.nanoTime() < deadline) {
            val e = queue.poll(100, TimeUnit.MILLISECONDS) ?: continue
            if (e["type"] == type) return e
            if (e["type"] == "error" && type != "error") fail("Unexpected renderer error: $e")
        }
        throw AssertionError("No real Godot $type event within 20 seconds")
    }
    private fun withHost(block: (MainActivity, GodotHostView, LinkedBlockingQueue<Map<String, Any>>) -> Unit) {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            lateinit var activity: MainActivity
            lateinit var host: GodotHostView
            val events = LinkedBlockingQueue<Map<String, Any>>()
            scenario.onActivity {
                activity = it
                host = GodotHostView(it) { e -> events.offer(e) }
                it.addContentView(host.getView(), FrameLayout.LayoutParams(600, 600))
                host.open()
            }
            try { block(activity, host, events) } finally { ui { host.dispose() } }
        }
    }
    @Test fun realGodotReadyHasEngineVersion() = withHost { _, host, events ->
        val ready = event(events, "ready")
        assertTrue("Engine version must come from Engine.get_version_info()", (ready["version"] as String).startsWith("4.5.1"))
        assertEquals("LivingWorldRender", ready["singleton"])
        ui { host.probe("android-scene-roundtrip") }
        assertEquals("android-scene-roundtrip", event(events, "probe")["nonce"])
    }
    @Test fun secondOwnerIsRejectedWithoutKillingFirst() = withHost { activity, first, events ->
        event(events, "ready")
        val rejected = LinkedBlockingQueue<Map<String, Any>>()
        lateinit var second: GodotHostView
        ui {
            second = GodotHostView(activity) { rejected.offer(it) }
            activity.addContentView(second.getView(), FrameLayout.LayoutParams(100, 100))
            second.open()
        }
        assertEquals("renderer_in_use", event(rejected, "error")["code"])
        ui { second.dispose(); first.probe("first-still-alive") }
        assertEquals("first-still-alive", event(events, "probe")["nonce"])
    }
    @Test fun reopenTwentyTimes() = withHost { activity, initial, initialEvents ->
        event(initialEvents, "ready")
        ui { initial.dispose(); (initial.getView().parent as? ViewGroup)?.removeView(initial.getView()) }
        repeat(20) { n ->
            val events = LinkedBlockingQueue<Map<String, Any>>()
            lateinit var host: GodotHostView
            ui {
                host = GodotHostView(activity) { events.offer(it) }
                activity.addContentView(host.getView(), FrameLayout.LayoutParams(600, 600))
                host.open()
            }
            event(events, "ready")
            ui { host.probe("reopen-$n") }
            assertEquals("reopen-$n", event(events, "probe")["nonce"])
            ui { host.dispose(); (host.getView().parent as? ViewGroup)?.removeView(host.getView()) }
        }
        assertFalse(activity.isFinishing)
    }
    @Test fun resizeAndRotateKeepsHostAlive() = withHost { activity, host, events ->
        event(events, "ready")
        for (orientation in listOf(ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE, ActivityInfo.SCREEN_ORIENTATION_PORTRAIT)) {
            ui {
                host.getView().layoutParams = FrameLayout.LayoutParams(420, 300)
                activity.requestedOrientation = orientation
            }
            InstrumentationRegistry.getInstrumentation().waitForIdleSync()
            ui { host.probe("rotate-$orientation") }
            assertEquals("rotate-$orientation", event(events, "probe")["nonce"])
        }
        assertFalse(activity.isFinishing)
    }
}
