package com.example.example_android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class JsonTest {

    @Test
    @Suppress("UNCHECKED_CAST")
    fun nestedRowsParseMutable() {
        val row = Json.parseObject("""{"leg":{"price":1.5},"list":[1,null,"a\"b"]}""")
        (row["leg"] as MutableMap<String, Any?>)["price"] = 2.0
        (row["list"] as MutableList<Any?>).add(3)

        assertEquals(2.0, (row["leg"] as Map<*, *>)["price"])
        assertEquals(listOf(1, null, "a\"b", 3), row["list"])
    }

    @Test
    fun stringifyRoundTrips() {
        val text = Json.stringify(mapOf("time" to 1_700_000_000_000L, "ltp" to -0.5, "rows" to listOf(mapOf("id" to "é 😀"))))
        val back = Json.parseObject(text)

        assertEquals(1_700_000_000_000L, (back["time"] as Number).toLong())
        assertEquals(-0.5, (back["ltp"] as Number).toDouble(), 0.0)
        assertEquals("é 😀", ((back["rows"] as List<*>).single() as Map<*, *>)["id"])
        assertNull(Json.parseObject("""{"a":null}""")["a"])
    }
}
