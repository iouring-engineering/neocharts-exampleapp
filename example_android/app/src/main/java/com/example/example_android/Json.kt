package com.example.example_android

import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener

/**
 * JSON over the platform's org.json: objects are mutable Map<String, Any?>,
 * arrays mutable List<Any?>, so callers can edit nested rows in place. JVM
 * tests use the org.json:json artifact, since android.jar's is a stub.
 */
object Json {

    @Suppress("UNCHECKED_CAST")
    fun parseObject(text: String): Map<String, Any?> = plain(JSONTokener(text).nextValue()) as Map<String, Any?>

    fun stringify(value: Any?): String = checkNotNull(JSONObject.wrap(value)) { "not JSON: $value" }.toString()

    private fun plain(value: Any?): Any? = when (value) {
        is JSONObject -> value.keys().asSequence().associateWithTo(LinkedHashMap()) { plain(value.get(it)) }
        is JSONArray -> MutableList(value.length()) { plain(value.get(it)) }
        JSONObject.NULL -> null
        else -> value
    }
}
