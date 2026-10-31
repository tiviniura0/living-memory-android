package com.tivini.livingworld.godot

import android.content.pm.ActivityInfo
import android.view.View
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
    private fun captureScene(name: String, view: View) {
        val point = IntArray(2)
        ui {
            view.getLocationOnScreen(point)
            point[0] += view.width / 2
            point[1] += view.height / 2
        }
        val automation = InstrumentationRegistry.getInstrumentation().uiAutomation
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(10)
        var visible = false
        while (System.nanoTime() < deadline) {
            val image = automation.takeScreenshot()
            assertNotNull(image)
            if (point[0] in 0 until image!!.width && point[1] in 0 until image.height) {
                val color = image.getPixel(point[0], point[1])
                visible = android.graphics.Color.red(color) > 240 &&
                    android.graphics.Color.blue(color) > 240 && android.graphics.Color.green(color) < 20
            }
            image.recycle()
            if (visible) break
            android.os.SystemClock.sleep(100)
        }
        // Keep the last image even when the marker assertion fails.
        val capture = automation.executeShellCommand("screencap -p /data/local/tmp/living-world-godot-$name.png")
        android.os.ParcelFileDescriptor.AutoCloseInputStream(capture).use { it.readBytes() }
        assertTrue("Real Godot Canvas marker missing; clear-color-only is not a rendered scene", visible)
    }
    private fun tapNativeView(view: View) {
        val point = IntArray(2)
        ui {
            view.getLocationOnScreen(point)
            point[0] += view.width / 2
            point[1] += view.height / 2
        }
        val automation = InstrumentationRegistry.getInstrumentation().uiAutomation
        val down = android.os.SystemClock.uptimeMillis()
        for (action in listOf(android.view.MotionEvent.ACTION_DOWN, android.view.MotionEvent.ACTION_UP)) {
            val event = android.view.MotionEvent.obtain(down, android.os.SystemClock.uptimeMillis(), action, point[0].toFloat(), point[1].toFloat(), 0)
            event.source = android.view.InputDevice.SOURCE_TOUCHSCREEN
            try { assertTrue("Real native touch injection failed", automation.injectInputEvent(event, true)) }
            finally { event.recycle() }
        }
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
        captureScene("ready", host.getView())
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
            if (n == 19) captureScene("reopened", host.getView())
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
            val expected = if (orientation == ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE) android.content.res.Configuration.ORIENTATION_LANDSCAPE else android.content.res.Configuration.ORIENTATION_PORTRAIT
            val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(10)
            var changed = false
            while (System.nanoTime() < deadline) {
                ui { changed = activity.resources.configuration.orientation == expected && host.getView().width == 420 && host.getView().height == 300 }
                if (changed) break
                android.os.SystemClock.sleep(50)
            }
            assertTrue("Actual orientation and layout did not settle", changed)
            ui { host.probe("rotate-$orientation") }
            assertEquals("rotate-$orientation", event(events, "probe")["nonce"])
        }
        assertFalse(activity.isFinishing)
    }

    private fun registeredChannel(activity: MainActivity, id: Int, events: LinkedBlockingQueue<Map<String, Any>>): GodotPlatformView {
        val flutter = activity.supportFragmentManager.fragments.filterIsInstance<io.flutter.embedding.android.FlutterFragment>().single()
        val channel = io.flutter.plugin.platform.RegistryTestAccess.create(flutter.flutterEngine!!, activity, id) as GodotPlatformView
        activity.addContentView(channel.getView(), FrameLayout.LayoutParams(600, 600))
        channel.onListen(null, object : io.flutter.plugin.common.EventChannel.EventSink {
            override fun success(value: Any?) { @Suppress("UNCHECKED_CAST") events.offer(value as Map<String, Any>) }
            override fun error(code: String, message: String?, details: Any?) { throw AssertionError(code) }
            override fun endOfStream() {}
        })
        channel.onMethodCall(io.flutter.plugin.common.MethodCall("open", null), channelResult)
        return channel
    }
    private val channelResult = object : io.flutter.plugin.common.MethodChannel.Result {
        override fun success(value: Any?) {}
        override fun error(code: String, message: String?, details: Any?) { throw AssertionError(code) }
        override fun notImplemented() { throw AssertionError("Missing channel handler") }
    }
    @Test fun realChannelReadyAndProbe() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            lateinit var channel: GodotPlatformView
            val events = LinkedBlockingQueue<Map<String, Any>>()
            scenario.onActivity { channel = registeredChannel(it, 900, events) }
            try {
                assertTrue((event(events, "ready")["version"] as String).startsWith("4.5.1"))
                ui { channel.onMethodCall(io.flutter.plugin.common.MethodCall("probe", mapOf("nonce" to "method-gdscript-event")), channelResult) }
                assertEquals("method-gdscript-event", event(events, "probe")["nonce"])
            } finally { ui { channel.dispose() } }
        }
    }
    @Test fun activityFinishAndRelaunchKeepsHostAlive() {
        lateinit var original: MainActivity
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            lateinit var first: GodotPlatformView
            val events = LinkedBlockingQueue<Map<String, Any>>()
            scenario.onActivity { original = it; first = registeredChannel(it, 903, events) }
            try { event(events, "ready") } finally { ui { first.dispose() } }
        }
        assertTrue("First Activity must really be destroyed", original.isDestroyed)
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            lateinit var next: GodotPlatformView
            val events = LinkedBlockingQueue<Map<String, Any>>()
            scenario.onActivity {
                assertNotSame(original, it)
                next = registeredChannel(it, 904, events)
            }
            try {
                event(events, "ready")
                ui { next.onMethodCall(io.flutter.plugin.common.MethodCall("probe", mapOf("nonce" to "same-process-relaunch")), channelResult) }
                assertEquals("same-process-relaunch", event(events, "probe")["nonce"])
                tapNativeView(next.getView())
                assertEquals("native-touch", event(events, "probe")["nonce"])
                captureScene("relaunched", next.getView())
            } finally { ui { next.dispose() } }
        }
    }
    @Test fun backgroundAndForegroundKeepsHostAlive() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            lateinit var channel: GodotPlatformView
            val events = LinkedBlockingQueue<Map<String, Any>>()
            scenario.onActivity { channel = registeredChannel(it, 905, events) }
            try {
                event(events, "ready")
                scenario.moveToState(androidx.lifecycle.Lifecycle.State.CREATED)
                scenario.moveToState(androidx.lifecycle.Lifecycle.State.RESUMED)
                ui { channel.onMethodCall(io.flutter.plugin.common.MethodCall("probe", mapOf("nonce" to "foreground")), channelResult) }
                assertEquals("foreground", event(events, "probe")["nonce"])
            } finally { ui { channel.dispose() } }
        }
    }

    @Test fun touchAfterRecreationReachesGodotScene() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            lateinit var initial: GodotPlatformView
            var restored: GodotPlatformView? = null
            val before = LinkedBlockingQueue<Map<String, Any>>()
            val after = LinkedBlockingQueue<Map<String, Any>>()
            scenario.onActivity { initial = registeredChannel(it, 906, before) }
            try {
                event(before, "ready")
                scenario.recreate()
                scenario.onActivity { restored = registeredChannel(it, 907, after) }
                event(after, "ready")
                tapNativeView(restored!!.getView())
                assertEquals("native-touch", event(after, "probe")["nonce"])
                captureScene("touched", restored!!.getView())
            } finally { ui { restored?.dispose(); initial.dispose() } }
        }
    }

    @Test fun activityRecreationKeepsHostAlive() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            lateinit var original: MainActivity
            lateinit var initial: GodotPlatformView
            var restored: GodotPlatformView? = null
            val initialEvents = LinkedBlockingQueue<Map<String, Any>>()
            val restoredEvents = LinkedBlockingQueue<Map<String, Any>>()
            scenario.onActivity { activity ->
                original = activity
                initial = registeredChannel(activity, 901, initialEvents)
            }
            try {
                event(initialEvents, "ready")
                scenario.recreate()
                scenario.onActivity { activity ->
                    assertNotSame("Activity recreation must be real", original, activity)
                    assertFalse("Flutter Activity must remain alive", activity.isFinishing)
                    // Both views belong to the actual plugin registry, so ActivityAware
                    // owns old-view cleanup, exactly as in the Flutter application.
                    restored = registeredChannel(activity, 902, restoredEvents)
                }
                assertTrue((event(restoredEvents, "ready")["version"] as String).startsWith("4.5.1"))
                ui { restored!!.onMethodCall(io.flutter.plugin.common.MethodCall("probe", mapOf("nonce" to "after-real-recreation")), channelResult) }
                assertEquals("after-real-recreation", event(restoredEvents, "probe")["nonce"])
                captureScene("recreated", restored!!.getView())
            } finally { ui { restored?.dispose(); initial.dispose() } }
        }
    }
}
