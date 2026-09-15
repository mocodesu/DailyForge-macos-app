import Foundation
import SwiftUI
import AppKit

enum PreferenceKeys {
    static let flashDuration = "flashDuration"
    static let borderWidth = "borderWidth"
    static let connectedColorHex = "connectedColorHex"
    static let disconnectedColorHex = "disconnectedColorHex"
    static let captivePortalColorHex = "captivePortalColorHex"
    static let showNotifications = "showNotifications"
    static let playSounds = "playSounds"
    static let showOnAllScreens = "showOnAllScreens"
    static let gracePeriod = "gracePeriod"
    static let checkCaptivePortal = "checkCaptivePortal"

    // Enforcement
    static let reminderEnabled = "reminderEnabled"
    static let reminderTimeSeconds = "reminderTimeSeconds"
    static let graceMinutes = "graceMinutes"
    static let enforceKiosk = "enforceKiosk"
    static let fallbackAlertEnabled = "fallbackAlertEnabled"

    // Overlay appearance
    static let overlayColorHex = "overlayColorHex"
    static let overlayMinOpacity = "overlayMinOpacity"
    static let overlayMaxOpacity = "overlayMaxOpacity"
    static let overlayPulseSeconds = "overlayPulseSeconds"
}

struct Preferences {
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            PreferenceKeys.flashDuration: 2.0,
            PreferenceKeys.borderWidth: 12.0,
            PreferenceKeys.connectedColorHex: "#34C759",
            PreferenceKeys.disconnectedColorHex: "#FF3B30",
            PreferenceKeys.captivePortalColorHex: "#FF9500",
            PreferenceKeys.showNotifications: true,
            PreferenceKeys.playSounds: false,
            PreferenceKeys.showOnAllScreens: true,
            PreferenceKeys.gracePeriod: 2.5,
            PreferenceKeys.checkCaptivePortal: true,

            PreferenceKeys.reminderEnabled: false,
            PreferenceKeys.reminderTimeSeconds: 19 * 3600,
            PreferenceKeys.graceMinutes: 15,
            PreferenceKeys.enforceKiosk: true,
            PreferenceKeys.fallbackAlertEnabled: true,

            PreferenceKeys.overlayColorHex: "#FF3B30",
            PreferenceKeys.overlayMinOpacity: 0.12,
            PreferenceKeys.overlayMaxOpacity: 0.30,
            PreferenceKeys.overlayPulseSeconds: 1.4
        ])
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3: (r, g, b) = ((int >> 8) * 17, ((int >> 4) & 0xF) * 17, (int & 0xF) * 17)
        case 6: (r, g, b) = (int >> 16, (int >> 8) & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }

    var hexString: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.black
        return String(
            format: "#%02X%02X%02X",
            Int(nsColor.redComponent * 255),
            Int(nsColor.greenComponent * 255),
            Int(nsColor.blueComponent * 255)
        )
    }
}
