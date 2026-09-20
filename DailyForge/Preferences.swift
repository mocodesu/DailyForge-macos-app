import Foundation
import SwiftUI
import AppKit

enum PreferenceKeys {
    static let showNotifications = "showNotifications"
    static let playSounds = "playSounds"
    static let fallbackAlertEnabled = "fallbackAlertEnabled"

    static let reminderEnabled = "reminderEnabled"
    static let reminderTimeSeconds = "reminderTimeSeconds"
    static let graceMinutes = "graceMinutes"
    static let enforceKiosk = "enforceKiosk"

    static let overlayColorHex = "overlayColorHex"
    static let overlayMinOpacity = "overlayMinOpacity"
    static let overlayMaxOpacity = "overlayMaxOpacity"
    static let overlayPulseSeconds = "overlayPulseSeconds"

    static let unitSystem = "unitSystem"

    static let swearPhrase = "swearPhrase"
    static let swearPhraseIsDefault = "swearPhraseIsDefault"
}

struct Preferences {
    static let defaultSwearPhrase = "I swear by God that I completed all my daily exercises today"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            PreferenceKeys.showNotifications: true,
            PreferenceKeys.playSounds: false,
            PreferenceKeys.fallbackAlertEnabled: true,

            PreferenceKeys.reminderEnabled: false,
            PreferenceKeys.reminderTimeSeconds: 19 * 3600,
            PreferenceKeys.graceMinutes: 15,
            PreferenceKeys.enforceKiosk: true,

            PreferenceKeys.overlayColorHex: "#FF6B35",
            PreferenceKeys.overlayMinOpacity: 0.12,
            PreferenceKeys.overlayMaxOpacity: 0.30,
            PreferenceKeys.overlayPulseSeconds: 1.4,

            PreferenceKeys.unitSystem: UnitSystem.metric.rawValue,

            PreferenceKeys.swearPhrase: defaultSwearPhrase,
            PreferenceKeys.swearPhraseIsDefault: true
        ])
    }

}

// MARK: - Unit System

enum UnitSystem: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }

    var label: String {
        switch self {
        case .metric: return "Metric"
        case .imperial: return "Imperial"
        }
    }

    var pickerLabel: String {
        switch self {
        case .metric: return "Metric (kg, cm)"
        case .imperial: return "Imperial (lb, ft/in)"
        }
    }

    var weightUnitLabel: String {
        switch self {
        case .metric: return "kg"
        case .imperial: return "lb"
        }
    }

    var heightUnitLabel: String {
        switch self {
        case .metric: return "cm"
        case .imperial: return "ft/in"
        }
    }
}

enum UnitConversion {
    static let lbPerKg = 2.2046226218
    static let cmPerInch = 2.54
    static let inchesPerFoot = 12.0

    static func kgToDisplay(_ kg: Double, unit: UnitSystem) -> Double {
        unit == .metric ? kg : kg * lbPerKg
    }
    static func displayToKg(_ value: Double, unit: UnitSystem) -> Double {
        unit == .metric ? value : value / lbPerKg
    }
    static func cmToFeetInches(_ cm: Double) -> (feet: Int, inches: Double) {
        let totalInches = cm / cmPerInch
        let feet = Int(floor(totalInches / inchesPerFoot))
        let inches = totalInches - Double(feet) * inchesPerFoot
        return (feet, inches)
    }
    static func feetInchesToCm(feet: Int, inches: Double) -> Double {
        (Double(feet) * inchesPerFoot + inches) * cmPerInch
    }
    static func formatWeight(_ kg: Double, unit: UnitSystem) -> String {
        String(format: "%.1f", kgToDisplay(kg, unit: unit))
    }
    static func formatHeight(_ cm: Double, unit: UnitSystem) -> String {
        switch unit {
        case .metric: return String(format: "%.0f cm", cm)
        case .imperial:
            let (feet, inches) = cmToFeetInches(cm)
            return String(format: "%d'%.0f\"", feet, inches.rounded())
        }
    }

    static let weightRangeKg: ClosedRange<Double> = 30...300
    static let heightRangeCm: ClosedRange<Double> = 120...250

    static func displayedWeightRange(unit: UnitSystem) -> (min: Int, max: Int) {
        (Int(kgToDisplay(weightRangeKg.lowerBound, unit: unit).rounded()),
         Int(kgToDisplay(weightRangeKg.upperBound, unit: unit).rounded()))
    }
    static func displayedHeightRange(unit: UnitSystem) -> (min: String, max: String) {
        switch unit {
        case .metric:
            return ("\(Int(heightRangeCm.lowerBound)) cm", "\(Int(heightRangeCm.upperBound)) cm")
        case .imperial:
            return (formatHeight(heightRangeCm.lowerBound, unit: .imperial),
                    formatHeight(heightRangeCm.upperBound, unit: .imperial))
        }
    }
}

extension UserDefaults {
    var unitSystem: UnitSystem {
        get {
            let raw = string(forKey: PreferenceKeys.unitSystem) ?? UnitSystem.metric.rawValue
            return UnitSystem(rawValue: raw) ?? .metric
        }
        set { set(newValue.rawValue, forKey: PreferenceKeys.unitSystem) }
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
