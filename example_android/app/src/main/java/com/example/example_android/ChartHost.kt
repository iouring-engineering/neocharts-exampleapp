package com.example.example_android

import android.app.Activity
import android.app.Application
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor

internal const val ENGINE_ID = "chart_engine"

/**
 * The process's one chart: engine, bridge and lifecycle callback. MainActivity
 * is recreated on rotation and dark-mode switches; [get] builds this on the
 * first call only, so a recreated MainActivity keeps the mounted chart.
 */
class ChartHost private constructor(app: Application) : Application.ActivityLifecycleCallbacks {

    private val screens = ChartScreens<Activity>(unmount = { bridge.unmount() })

    // A tap while a mount is in flight is ignored.
    private var opening = false

    /** Runs the SDK's `main()` (NativeChartRoot) early and wires the bridge to it. */
    private val bridge: NeoChartsBridge = FlutterEngineGroup(app)
        .createAndRunEngine(app, DartExecutor.DartEntrypoint.createDefault())
        .let { engine ->
            FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
            NeoChartsBridge(
                engine.dartExecutor.binaryMessenger,
                MockDataSource.fromRawResources(app),
                BuildConfig.NEOCHARTS_HOME_KEY,
                // `onClose` arrives on the engine, not an Activity.
                onClose = { screens.active?.finish() },
            )
        }

    init {
        // Registered once for the process, like the engine, so there is no
        // per-MainActivity callback to unregister.
        app.registerActivityLifecycleCallbacks(this)
    }

    /** Mounts the chart (retrying while the engine starts), then shows it from [from]. */
    fun open(from: Activity, themeJson: String) {
        if (opening) return
        opening = true
        bridge.mount(themeJson) {
            opening = false
            // Shown even when the mount failed: a failed init shows the SDK error view.
            from.startActivity(FlutterActivity.withCachedEngine(ENGINE_ID).build(from))
        }
    }

    override fun onActivityResumed(activity: Activity) {
        if (activity is FlutterActivity) screens.resumed(activity)
    }

    override fun onActivityPaused(activity: Activity) {
        if (activity is FlutterActivity) screens.paused(activity, activity.isFinishing)
    }

    override fun onActivityDestroyed(activity: Activity) {
        if (activity is FlutterActivity) screens.destroyed(activity, activity.isFinishing)
    }

    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {}
    override fun onActivityStarted(activity: Activity) {}
    override fun onActivityStopped(activity: Activity) {}
    override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}

    companion object {
        private val host = OncePerProcess(::ChartHost)

        fun get(app: Application): ChartHost = host.get(app)
    }
}

/** [build]'s value from the first [get]; every later call returns that same value. */
internal class OncePerProcess<A, T : Any>(private val build: (A) -> T) {
    private var value: T? = null

    fun get(arg: A): T = value ?: build(arg).also { value = it }
}

/**
 * Which chart activity is showing. Leaving it (finished at pause, or at
 * destroy, e.g. removed from recents after Home) unmounts once per activity;
 * a pause before the next tap means a re-mount is never unmounted.
 */
internal class ChartScreens<A : Any>(private val unmount: () -> Unit) {
    var active: A? = null
        private set
    private var left: A? = null

    fun resumed(activity: A) {
        active = activity
    }

    fun paused(activity: A, finishing: Boolean) {
        if (finishing) leave(activity)
    }

    fun destroyed(activity: A, finishing: Boolean) {
        // A late destroy of an older chart must not unmount the newest one.
        if (finishing && activity === active) leave(activity)
        if (activity === active) active = null
    }

    private fun leave(activity: A) {
        if (activity === left) return
        left = activity
        unmount()
    }
}
