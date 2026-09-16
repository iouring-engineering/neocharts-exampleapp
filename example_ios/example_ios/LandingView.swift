// apps/example_ios/example_ios/LandingView.swift
import SwiftUI

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

private let darkBackground = Color(hex: 0x090B10)
private let lightBackground = Color(hex: 0xF5F7FB)
private let logoGradientStart = Color(hex: 0x7C5CFF)
private let logoGradientEnd = Color(hex: 0x4B8BFF)
private let cardGradientStart = Color(hex: 0x00A884)
private let cardGradientEnd = Color(hex: 0x00C6A2)

// Flutter's `Material(color: theme.cardColor, ...)` on the theme-toggle chip
// resolves through Material3's `ColorScheme.fromSeed(...).surface` (tonalSpot
// scheme variant) for the seeds in app.dart -- these are that algorithm's
// exact output for #6C63FF (light) / #8B7CFF (dark), not app-specific
// literals, so they transfer directly here (matches the Android port).
private let lightCardColor = Color(hex: 0xFCF8FF)
private let darkCardColor = Color(hex: 0x141318)

struct LandingView: View {
    let onOpenChart: () -> Void
    @State private var isDark = true

    private var textColor: Color { isDark ? .white : Color(hex: 0x0A0A12) }
    private var background: Color { isDark ? darkBackground : lightBackground }
    private var cardColor: Color { isDark ? darkCardColor : lightCardColor }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    topBar

                    Spacer().frame(height: 70)

                    Text("Choose your\nchart workspace.")
                        .font(.system(size: 34, weight: .heavy))
                        .tracking(-1.5)
                        .lineSpacing(2)
                        .foregroundColor(textColor)

                    Spacer().frame(height: 18)

                    Text("Explore powerful charting tools designed for analysis, strategy and precision trading.")
                        .font(.system(size: 16))
                        .foregroundColor(textColor.opacity(0.6))
                        .lineSpacing(8)

                    Spacer().frame(height: 44)

                    neoChartsCard

                    Spacer().frame(height: 60)
                }
                .frame(maxWidth: 1200)
                .padding(24)
            }
            .frame(maxHeight: .infinity)

            Text("BUILT BY IOURING")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundColor(textColor.opacity(0.35))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
        .background(background.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [logoGradientStart, logoGradientEnd], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 46, height: 46)
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("NeoCharts")
                    .font(.system(size: 20, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundColor(textColor)
                Text("Trading intelligence")
                    .font(.system(size: 12))
                    .foregroundColor(textColor.opacity(0.55))
            }

            Spacer()

            Button(action: { isDark.toggle() }) {
                // Glyph shows the action tapping performs (matches
                // home_page.dart's `isDarkMode ? light_mode : dark_mode`),
                // not the current mode.
                Image(systemName: isDark ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 18))
                    .foregroundColor(textColor)
                    .padding(12)
                    .background(cardColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var neoChartsCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28)
                .fill(LinearGradient(colors: [cardGradientStart, cardGradientEnd], startPoint: .topLeading, endPoint: .bottomTrailing))

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 170, height: 170)
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .offset(x: 50, y: -50)

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 180, height: 180)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: -45, y: 80)

            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.15))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.18)))
                        .frame(width: 52, height: 52)
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                Text("NeoCharts")
                    .font(.system(size: 22, weight: .heavy))
                    .tracking(-0.5)
                    .foregroundColor(.white)
                Spacer().frame(height: 7)
                Text("Fast charts for precision entries")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.72))
                Spacer().frame(height: 18)
                HStack(spacing: 8) {
                    Text("Open workspace").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    Text("→").font(.system(size: 15)).foregroundColor(.white)
                }
            }
            .padding(28)
        }
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: cardGradientStart.opacity(0.20), radius: 30, x: 0, y: 15)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenChart)
    }
}
