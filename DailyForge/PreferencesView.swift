import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralPreferences()
                .tabItem { Label("General", systemImage: "gear") }
            AppearancePreferences()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            EnforcementPreferences()
                .tabItem { Label("Enforcement", systemImage: "lock.shield") }
        }
        .frame(width: 560, height: 520)
    }
}

struct GeneralPreferences: View {
    @AppStorage(PreferenceKeys.showNotifications) private var showNotifications = true
    @AppStorage(PreferenceKeys.playSounds) private var playSounds = false
    @AppStorage(PreferenceKeys.showOnAllScreens) private var showOnAllScreens = true
    @AppStorage(PreferenceKeys.checkCaptivePortal) private var checkCaptivePortal = true
    @AppStorage(PreferenceKeys.gracePeriod) private var gracePeriod: Double = 2.5
    @AppStorage(PreferenceKeys.flashDuration) private var flashDuration: Double = 2.0

    var body: some View {
        Form {
            Section("Alerts") {
                Toggle("Show notifications", isOn: $showNotifications)
                Toggle("Play sounds", isOn: $playSounds)
                Toggle("Show overlay on all displays", isOn: $showOnAllScreens)
                Toggle("Detect captive portals", isOn: $checkCaptivePortal)
            }
            Section("Timing") {
                HStack {
                    Text("Grace period")
                    Slider(value: $gracePeriod, in: 0...10, step: 0.5)
                    Text(String(format: "%.1fs", gracePeriod))
                        .monospacedDigit().frame(width: 50, alignment: .trailing)
                }
                HStack {
                    Text("Green flash duration")
                    Slider(value: $flashDuration, in: 0.5...10, step: 0.5)
                    Text(String(format: "%.1fs", flashDuration))
                        .monospacedDigit().frame(width: 50, alignment: .trailing)
                }
            }
        }
        .padding()
    }
}

struct AppearancePreferences: View {
    @AppStorage(PreferenceKeys.connectedColorHex) private var connectedColorHex = "#34C759"
    @AppStorage(PreferenceKeys.disconnectedColorHex) private var disconnectedColorHex = "#FF3B30"
    @AppStorage(PreferenceKeys.captivePortalColorHex) private var captivePortalColorHex = "#FF9500"
    @AppStorage(PreferenceKeys.borderWidth) private var borderWidth: Double = 12.0

    var body: some View {
        Form {
            Section("Colors") {
                ColorPicker("Connected", selection: Binding(
                    get: { Color(hex: connectedColorHex) },
                    set: { connectedColorHex = $0.hexString }
                ))
                ColorPicker("Disconnected", selection: Binding(
                    get: { Color(hex: disconnectedColorHex) },
                    set: { disconnectedColorHex = $0.hexString }
                ))
                ColorPicker("Captive portal", selection: Binding(
                    get: { Color(hex: captivePortalColorHex) },
                    set: { captivePortalColorHex = $0.hexString }
                ))
            }
            Section("Border") {
                HStack {
                    Text("Thickness")
                    Slider(value: $borderWidth, in: 2...40, step: 1)
                    Text(String(format: "%.0fpt", borderWidth))
                        .monospacedDigit().frame(width: 50, alignment: .trailing)
                }
            }
        }
        .padding()
    }
}

struct EnforcementPreferences: View {
    @AppStorage(PreferenceKeys.reminderEnabled) private var reminderEnabled = false
    @AppStorage(PreferenceKeys.reminderTimeSeconds) private var reminderTimeSeconds = 19 * 3600
    @AppStorage(PreferenceKeys.graceMinutes) private var graceMinutes = 15
    @AppStorage(PreferenceKeys.enforceKiosk) private var enforceKiosk = true
    @AppStorage(PreferenceKeys.fallbackAlertEnabled) private var fallbackAlertEnabled = true

    @AppStorage(PreferenceKeys.overlayColorHex) private var overlayColorHex = "#FF3B30"
    @AppStorage(PreferenceKeys.overlayMinOpacity) private var overlayMinOpacity: Double = 0.12
    @AppStorage(PreferenceKeys.overlayMaxOpacity) private var overlayMaxOpacity: Double = 0.30
    @AppStorage(PreferenceKeys.overlayPulseSeconds) private var overlayPulseSeconds: Double = 1.4

    @ObservedObject private var notif = NotificationManager.shared

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                let startOfDay = Calendar.current.startOfDay(for: Date())
                return Calendar.current.date(byAdding: .second, value: reminderTimeSeconds, to: startOfDay) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                reminderTimeSeconds = (comps.hour ?? 19) * 3600 + (comps.minute ?? 0) * 60
            }
        )
    }

    var body: some View {
        ScrollView {
            Form {
                Section("Daily reminder") {
                    Toggle("Enable daily reminder", isOn: $reminderEnabled)

                    HStack {
                        Text("Remind me at")
                        Spacer()
                        DatePicker("", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .disabled(!reminderEnabled)
                    }

                    HStack {
                        Text("Grace period")
                        Slider(value: Binding(
                            get: { Double(graceMinutes) },
                            set: { graceMinutes = Int($0) }
                        ), in: 1...60, step: 1)
                        .disabled(!reminderEnabled)
                        Text("\(graceMinutes) min")
                            .monospacedDigit().frame(width: 60, alignment: .trailing)
                    }

                    Toggle("Show in-app alert if notifications fail", isOn: $fallbackAlertEnabled)
                        .disabled(!reminderEnabled)
                }

                Section("Notifications") {
                    HStack {
                        Circle()
                            .fill(notif.isWorking ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text("Status: \(notif.statusLabel)")
                            .font(.callout)
                        Spacer()
                        Button("Test") { notif.sendTest() }
                            .controlSize(.small)
                    }

                    HStack {
                        Text("Last delivery:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(notif.lastDeliveryResult)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }

                    if let error = notif.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(3)
                    }

                    HStack {
                        Button("Request Permission") { notif.requestPermission() }
                            .controlSize(.small)
                        Button("Open System Settings") { notif.openSystemNotificationSettings() }
                            .controlSize(.small)
                    }

                    Text("If the Test button does nothing, check that Focus mode is off and that DailyForge has \"Banners\" or \"Alerts\" selected in System Settings → Notifications.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Lockdown") {
                    Toggle("Flash the screen if I ignore the reminder", isOn: $enforceKiosk)
                        .disabled(!reminderEnabled)
                }

                Section("Overlay appearance") {
                    ColorPicker("Tint color", selection: Binding(
                        get: { Color(hex: overlayColorHex) },
                        set: { overlayColorHex = $0.hexString }
                    ))

                    HStack {
                        Text("Faint opacity")
                        Slider(value: $overlayMinOpacity, in: 0.0...1.0, step: 0.02)
                        Text(String(format: "%.0f%%", overlayMinOpacity * 100))
                            .monospacedDigit().frame(width: 45, alignment: .trailing)
                    }

                    HStack {
                        Text("Bright opacity")
                        Slider(value: Binding(
                            get: { overlayMaxOpacity },
                            set: { overlayMaxOpacity = max($0, overlayMinOpacity + 0.02) }
                        ), in: 0.02...1.0, step: 0.02)
                        Text(String(format: "%.0f%%", overlayMaxOpacity * 100))
                            .monospacedDigit().frame(width: 45, alignment: .trailing)
                    }

                    HStack {
                        Text("Pulse speed")
                        Slider(value: $overlayPulseSeconds, in: 0.3...3.0, step: 0.1)
                        Text(String(format: "%.1fs", overlayPulseSeconds))
                            .monospacedDigit().frame(width: 45, alignment: .trailing)
                    }

                    HStack {
                        Button("Preview Overlay (3s)") {
                            OverlayEnforcer.shared.preview(duration: 3)
                        }
                        .controlSize(.small)
                    }
                }
            }
            .padding()
        }
        .onAppear { notif.refreshStatus() }
    }
}
