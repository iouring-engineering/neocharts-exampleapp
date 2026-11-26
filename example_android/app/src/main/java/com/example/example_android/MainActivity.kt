package com.example.example_android

import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import com.example.example_android.ui.theme.Example_androidTheme

class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)

        // Built on the first launch only; a recreated activity reuses it.
        val host = ChartHost.get(application)

        setContent {
            Example_androidTheme(dynamicColor = false) {
                LandingScreen(onOpenChart = { dark -> host.open(this, themeJson(dark)) })
            }
        }
    }

    /** The landing page's brightness plus demo brand colours; see the theming docs for all tokens. */
    private fun themeJson(dark: Boolean): String {
        val demo = mapOf(
            "primary" to "#7B1FA2", "onPrimary" to "#FFFFFF",
            "bullish" to "#26A69A", "bearish" to "#EF5350",
        )
        return Json.stringify(
            mapOf(
                "brightness" to if (dark) "dark" else "light",
                "colors" to mapOf("light" to demo, "dark" to demo),
            )
        )
    }
}
