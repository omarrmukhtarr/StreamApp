import SwiftUI

extension Color {
    static let brandPrimary = Color.indigo
    static let brandSecondary = Color.cyan
}

extension LinearGradient {
    static let brand = LinearGradient(
        colors: [.brandPrimary, .brandSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Deep cinematic background used behind every screen.
struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.08)

            RadialGradient(
                colors: [Color.brandPrimary.opacity(0.28), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 500
            )

            RadialGradient(
                colors: [Color.brandSecondary.opacity(0.12), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 600
            )
        }
        .ignoresSafeArea()
    }
}

extension View {
    func appBackground() -> some View {
        background(AppBackground())
    }
}
