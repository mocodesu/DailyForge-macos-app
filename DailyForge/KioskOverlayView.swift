import SwiftUI
import Combine

struct OverlayEnforcerView: View {
    @ObservedObject private var dayState = DayState.shared

    @AppStorage(PreferenceKeys.overlayColorHex) private var colorHex = "#FF3B30"
    @AppStorage(PreferenceKeys.overlayMinOpacity) private var minOpacity: Double = 0.12
    @AppStorage(PreferenceKeys.overlayMaxOpacity) private var maxOpacity: Double = 0.30
    @AppStorage(PreferenceKeys.overlayPulseSeconds) private var pulseSeconds: Double = 1.4

    @State private var pulse = false

    var body: some View {
        ZStack(alignment: .top) {
            Color(hex: colorHex)
                .opacity(pulse ? maxOpacity : minOpacity)
                .ignoresSafeArea()

            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(labelText)
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(hex: colorHex).opacity(0.85))
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            )
            .opacity(pulse ? 1.0 : 0.65)
            .padding(.top, 70)
        }
        .ignoresSafeArea()
        .onAppear { startPulse() }
        .onChange(of: pulseSeconds) { _, _ in startPulse() }
    }

    private var labelText: String {
        let count = dayState.exerciseCount
        if count == 0 { return "Time to work out" }
        return "Time to work out — \(count) exercise\(count == 1 ? "" : "s") waiting"
    }

    private func startPulse() {
        pulse = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            withAnimation(
                .easeInOut(duration: pulseSeconds)
                .repeatForever(autoreverses: true)
            ) {
                pulse = true
            }
        }
    }
}
