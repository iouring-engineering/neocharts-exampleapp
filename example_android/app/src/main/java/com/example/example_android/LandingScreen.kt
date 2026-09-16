package com.example.example_android

import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CandlestickChart
import androidx.compose.material.icons.rounded.DarkMode
import androidx.compose.material.icons.rounded.LightMode
import androidx.compose.material.icons.rounded.ShowChart
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val DarkBackground = Color(0xFF090B10)
private val LightBackground = Color(0xFFF5F7FB)
private val LogoGradientStart = Color(0xFF7C5CFF)
private val LogoGradientEnd = Color(0xFF4B8BFF)
private val CardGradientStart = Color(0xFF00A884)
private val CardGradientEnd = Color(0xFF00C6A2)

// Flutter's `Material(color: theme.cardColor, ...)` on the theme-toggle chip
// resolves through Material3's `ColorScheme.fromSeed(...).surface` (tonalSpot
// scheme variant) for the seeds in app.dart -- these are that algorithm's
// exact output for #6C63FF (light) / #8B7CFF (dark), not app-specific literals.
private val LightCardColor = Color(0xFFFCF8FF)
private val DarkCardColor = Color(0xFF141318)

@Composable
fun LandingScreen(onOpenChart: () -> Unit) {
    var isDark by remember { mutableStateOf(true) }
    val textColor = if (isDark) Color.White else Color(0xFF0A0A12)
    val background = if (isDark) DarkBackground else LightBackground

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(background)
            .safeDrawingPadding(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .widthIn(max = 1200.dp)
                .padding(horizontal = 24.dp, vertical = 24.dp),
        ) {
            TopBar(isDark = isDark, textColor = textColor, onToggleTheme = { isDark = !isDark })

            Spacer(modifier = Modifier.height(70.dp))

            Text(
                text = "Choose your\nchart workspace.",
                color = textColor,
                fontSize = 34.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = (-1.5).sp,
                lineHeight = 36.sp,
            )

            Spacer(modifier = Modifier.height(18.dp))

            Text(
                text = "Explore powerful charting tools designed for analysis, strategy and precision trading.",
                color = textColor.copy(alpha = 0.6f),
                fontSize = 16.sp,
                lineHeight = 26.sp,
            )

            Spacer(modifier = Modifier.height(44.dp))

            NeoChartsCard(onTap = onOpenChart)

            Spacer(modifier = Modifier.height(60.dp))
        }

        Text(
            text = "BUILT BY IOURING",
            color = textColor.copy(alpha = 0.35f),
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 2.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 24.dp, end = 24.dp, bottom = 20.dp),
        )
    }
}

@Composable
private fun TopBar(isDark: Boolean, textColor: Color, onToggleTheme: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            modifier = Modifier
                .size(46.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(Brush.horizontalGradient(listOf(LogoGradientStart, LogoGradientEnd))),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Rounded.CandlestickChart, contentDescription = null, tint = Color.White, modifier = Modifier.size(25.dp))
        }

        Spacer(modifier = Modifier.width(14.dp))

        Column {
            Text(
                text = "NeoCharts",
                color = textColor,
                fontSize = 20.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = (-0.5).sp,
            )
            Text(
                text = "Trading intelligence",
                color = textColor.copy(alpha = 0.55f),
                fontSize = 12.sp,
            )
        }

        Spacer(modifier = Modifier.weight(1f))

        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(14.dp))
                .background(if (isDark) DarkCardColor else LightCardColor)
                .clickable(onClick = onToggleTheme)
                .padding(12.dp),
        ) {
            // Glyph shows the action tapping performs (matches
            // home_page.dart's `isDarkMode ? light_mode : dark_mode`), not
            // the current mode.
            AnimatedContent(targetState = isDark, label = "theme-toggle-icon") { dark ->
                Icon(
                    imageVector = if (dark) Icons.Rounded.LightMode else Icons.Rounded.DarkMode,
                    contentDescription = null,
                    tint = textColor,
                    modifier = Modifier.size(22.dp),
                )
            }
        }
    }
}

@Composable
private fun NeoChartsCard(onTap: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(230.dp)
            // API 28+ only -- spotColor/ambientColor tinting is a no-op on
            // this app's minSdk 24, which renders a neutral grey shadow
            // instead of a green-tinted one there. Accepted approximation.
            .shadow(
                elevation = 15.dp,
                shape = RoundedCornerShape(28.dp),
                spotColor = CardGradientStart,
                ambientColor = CardGradientStart,
            )
            .clip(RoundedCornerShape(28.dp))
            .background(
                Brush.linearGradient(
                    colors = listOf(CardGradientStart, CardGradientEnd),
                    start = Offset(0f, 0f),
                    end = Offset(Float.POSITIVE_INFINITY, Float.POSITIVE_INFINITY),
                )
            )
            .clickable(onClick = onTap),
    ) {
        Box(
            modifier = Modifier
                .size(170.dp)
                .align(Alignment.TopEnd)
                .offset(x = 50.dp, y = (-50).dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.08f)),
        )
        Box(
            modifier = Modifier
                .size(180.dp)
                .align(Alignment.BottomEnd)
                .offset(x = (-45).dp, y = 80.dp)
                .clip(CircleShape)
                .background(Color.White.copy(alpha = 0.05f)),
        )

        Column(modifier = Modifier.fillMaxSize().padding(28.dp)) {
            Box(
                modifier = Modifier
                    .size(52.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(Color.White.copy(alpha = 0.15f))
                    .border(1.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(16.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Rounded.ShowChart, contentDescription = null, tint = Color.White, modifier = Modifier.size(27.dp))
            }

            Spacer(modifier = Modifier.weight(1f))

            Text(
                text = "NeoCharts",
                color = Color.White,
                fontSize = 22.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = (-0.5).sp,
            )
            Spacer(modifier = Modifier.height(7.dp))
            Text(
                text = "Fast charts for precision entries",
                color = Color.White.copy(alpha = 0.72f),
                fontSize = 14.sp,
            )
            Spacer(modifier = Modifier.height(18.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(text = "Open workspace", color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.width(8.dp))
                Text(text = "→", color = Color.White, fontSize = 15.sp) // →
            }
        }
    }
}
