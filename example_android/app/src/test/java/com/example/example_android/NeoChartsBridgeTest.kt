package com.example.example_android

import io.flutter.plugin.common.MethodChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class NeoChartsBridgeTest {

    private val data = MockDataSource { name -> File("../../mock/$name.json").readText() }

    /** Runs a mount whose replies come from [replies], in order; retries run at once. */
    private fun mount(vararg replies: (MethodChannel.Result) -> Unit): Pair<Int, Boolean?> {
        var calls = 0
        var done: Boolean? = null
        mountWithRetry(
            invoke = { result -> replies[minOf(calls++, replies.size - 1)](result) },
            retryLater = { it() },
        ) { mounted, _ -> done = mounted }
        return calls to done
    }

    @Test
    fun mountRetriesWhileTheChannelIsNotReady() {
        val (calls, done) = mount({ it.notImplemented() }, { it.notImplemented() }, { it.success(null) })
        assertEquals(3, calls)
        assertEquals(true, done)
    }

    @Test
    fun mountStopsAtOnceOnInitFailed() {
        val (calls, done) = mount({ it.error("initFailed", "init timed out", null) }, { it.success(null) })
        assertEquals(1, calls)
        assertEquals(false, done)
    }

    @Test
    fun mountGivesUpAfterThirtyRetries() {
        val (calls, done) = mount({ it.notImplemented() })
        assertEquals(31, calls)
        assertEquals(false, done)
    }

    @Test
    fun sessionDeclaresEveryCapabilityAndOnlyASetHomeKey() {
        val session = hostSession(data, " ")
        val exchange = (session["initialSymbol"] as Map<*, *>)["exchange"]
        assertTrue((session["marketTimings"] as Map<*, *>).containsKey(exchange))
        assertTrue((session["storageKey"] as String).isNotBlank())
        assertEquals(7, (session["capabilities"] as List<*>).toSet().size)
        assertEquals(emptyList<Any>(), session["widgetOverrides"])
        assertFalse(session.containsKey("homeKey"))
        assertNull(session["initialSymbolId"])

        assertEquals("key", hostSession(data, "key")["homeKey"])
    }
}
