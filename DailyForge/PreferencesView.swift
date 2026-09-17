import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            RemindersPreferences()
                .tabItem { Label("Reminders", systemImage: "bell.badge") }
            EnforcementPreferences()
                .tabItem { Label("Enforcement", systemImage: "lock.shield") }
            DataManagementView()
                .tabItem { Label("Data", systemImage: "externaldrive") }
        }
        .frame(width: 680, height: 720)
        .background(Theme.surfaceBase)
    }
}

struct RemindersPreferences: View {
    @AppStorage(PreferenceKeys.showNotifications) private var showNotifications = true
    @AppStorage(PreferenceKeys.playSounds) private var playSounds = false
    @AppStorage(PreferenceKeys.fallbackAlertEnabled) private var fallbackAlertEnabled = true

    @ObservedObject private var notif = NotificationManager.shared

    var body: some View {
        ScrollView {
            Form {
                Section("Reminder alerts") {
                    Toggle("Show system notifications", isOn: $showNotifications)
                    Toggle("Play a sound with the reminder", isOn: $playSounds)
                    Toggle("Show an in-app alert if notifications fail", isOn: $fallbackAlertEnabled)
                }

                Section("Notification status") {
                    HStack {
                        Circle()
                            .fill(notif.isWorking ? Theme.success : Theme.warning)
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
                            .foregroundStyle(Theme.textSecondary)
                        Text(notif.lastDeliveryResult)
                            .font(.caption.monospaced())
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }

                    if let error = notif.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Theme.danger)
                            .lineLimit(3)
                    }

                    HStack {
                        Button("Request Permission") { notif.requestPermission() }
                            .controlSize(.small)
                        Button("Open System Settings") { notif.openSystemNotificationSettings() }
                            .controlSize(.small)
                    }
                }
            }
            .padding()
        }
        .onAppear { notif.refreshStatus() }
    }
}

struct EnforcementPreferences: View {
    @AppStorage(PreferenceKeys.reminderEnabled) private var reminderEnabled = false
    @AppStorage(PreferenceKeys.reminderTimeSeconds) private var reminderTimeSeconds = 19 * 3600
    @AppStorage(PreferenceKeys.graceMinutes) private var graceMinutes = 15
    @AppStorage(PreferenceKeys.enforceKiosk) private var enforceKiosk = true

    @AppStorage(PreferenceKeys.overlayColorHex) private var overlayColorHex = "#FF6B35"
    @AppStorage(PreferenceKeys.overlayMinOpacity) private var overlayMinOpacity: Double = 0.12
    @AppStorage(PreferenceKeys.overlayMaxOpacity) private var overlayMaxOpacity: Double = 0.30
    @AppStorage(PreferenceKeys.overlayPulseSeconds) private var overlayPulseSeconds: Double = 1.4

    @AppStorage(PreferenceKeys.swearPhrase) private var swearPhrase: String = Preferences.defaultSwearPhrase
    @State private var phraseDraft: String = ""
    @State private var phraseError: String?

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
                        Text("\(graceMinutes) min").monospacedDigit().frame(width: 60, alignment: .trailing)
                    }
                }

                Section("Enforcement") {
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
                    Button("Preview Overlay (3s)") {
                        OverlayEnforcer.shared.preview(duration: 3)
                    }
                    .controlSize(.small)
                }

                Section("Swear phrase") {
                    Text("The phrase you must say out loud to seal a completed day.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    TextField("Phrase", text: $phraseDraft, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                        .onAppear { phraseDraft = swearPhrase }
                    if let phraseError {
                        Text(phraseError).font(.caption).foregroundStyle(Theme.danger)
                    }
                    HStack {
                        Button("Reset to Default") {
                            phraseDraft = Preferences.defaultSwearPhrase
                            phraseError = nil
                        }
                        .controlSize(.small)
                        Spacer()
                        Button("Save Phrase") { savePhrase() }
                            .controlSize(.small)
                            .disabled(phraseDraft.trimmingCharacters(in: .whitespaces).isEmpty
                                      || phraseDraft == swearPhrase)
                    }
                }
            }
            .padding()
        }
    }

    private func savePhrase() {
        let trimmed = phraseDraft
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .joined(separator: " ")
        let wordCount = trimmed.split(separator: " ").count
        guard wordCount >= 3 else { phraseError = "Phrase must be at least 3 words."; return }
        guard wordCount <= 40 else { phraseError = "Phrase must be 40 words or fewer."; return }
        phraseError = nil
        swearPhrase = trimmed
    }
}
