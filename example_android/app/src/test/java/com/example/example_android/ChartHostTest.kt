package com.example.example_android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

class ChartHostTest {

    @Test
    fun theHostIsBuiltOnceAcrossActivityRecreation() {
        var built = 0
        val holder = OncePerProcess<String, Any> { built++; Any() }
        // Each MainActivity.onCreate (first launch, rotation, dark-mode switch) asks again.
        val first = holder.get("first activity")
        val afterRotation = holder.get("recreated activity")
        assertSame(first, afterRotation)
        assertEquals(1, built)
    }

    @Test
    fun leavingTheChartUnmountsOncePerChartActivity() {
        var unmounts = 0
        val screens = ChartScreens<String>(unmount = { unmounts++ })

        // Back or onClose: finishing at pause, then again at destroy.
        screens.resumed("chart 1")
        screens.paused("chart 1", finishing = true)
        screens.destroyed("chart 1", finishing = true)
        assertEquals(1, unmounts)

        // Rotation recreates the chart activity without finishing it.
        screens.resumed("chart 2")
        screens.paused("chart 2", finishing = false)
        screens.destroyed("chart 2", finishing = false)
        screens.resumed("chart 2b")
        assertEquals(1, unmounts)
        assertEquals("chart 2b", screens.active)

        // Paused by Home, later destroyed while finishing (removed from recents).
        screens.paused("chart 2b", finishing = false)
        screens.destroyed("chart 2b", finishing = true)
        assertEquals(2, unmounts)
        assertEquals(null, screens.active)
    }
}
