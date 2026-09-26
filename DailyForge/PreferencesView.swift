import SwiftUI
import AppKit

// MARK: - Tab Model

enum PreferencesTab: String, CaseIterable, Identifiable {
    case reminders
    case training
    case enforcement
    case focus
    case data

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reminders:   return "Reminders"
        case .training:    return "Training"
        case .enforcement: return "Enforcement"
        case .focus:       return "Focus"
        case .data:        return "Data"
        }
    }

    var icon: String {
        switch self {
        case .reminders:   return "bell.badge.fill"
        case .training:    return "figure.run"
        case .enforcement: return "lock.shield.fill"
        case .focus:       return "moon.stars.fill"
        case .data:        return "externaldrive.fill"
        }
    }

    var tint: Color {
        switch self {
        case .reminders:   return Color(hex: "#FF6B35")
        case .training:    return Color(hex: "#06D6A0")
        case .enforcement: return Color(hex: "#9B5DE5")
        case .focus:       return Color(hex: "#118AB2")
        case .data:        return Color(hex: "#118AB2")
        }
    }

    var subtitle: String {
        switch self {
        case .reminders:   return "Alerts and permissions"
        case .training:    return "Daily minimum and rest days"
        case .enforcement: return "Reminder, kiosk, overlay, and oath"
        case .focus:       return "Session focus and Focus mode"
        case .data:        return "Backups, export, and store"
        }
    }
}

// MARK: - Root

struct PreferencesView: View {
    @State private var selection: PreferencesTab = .reminders

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 720, height: 760)
        .background(Theme.surfaceBase)
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Preferences")
                        .font(.title2.bold())
                    Text(selection.subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)

            PreferenceTabBar(selection: $selection)
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .reminders:
            RemindersPreferences()
        case .training:
            TrainingPreferences()
        case .enforcement:
            EnforcementPreferences()
        case .focus:
            FocusPreferences()
        case .data:
            DataManagementView()
        }
    }
}

// MARK: - Tab Bar

struct PreferenceTabBar: View {
    @Binding var selection: PreferencesTab
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PreferencesTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.surfaceSunken)
        )
    }

    private func tabButton(_ tab: PreferencesTab) -> some View {
        let isSelected = selection == tab
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                selection = tab
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isSelected ? Color.white : Theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(
                                LinearGradient(
                                    colors: [tab.tint, tab.tint.opacity(0.85)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .matchedGeometryEffect(id: "selectedTabPill", in: pill)
                            .shadow(color: tab.tint.opacity(0.35), radius: 6, y: 2)
                    }
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scroll wrapper

struct PreferencesScroll<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

// MARK: - Card

struct PreferenceCard<Content: View>: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String?
    let content: Content

    init(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Setting row

struct SettingRow<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            trailing
        }
    }
}

struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.border.opacity(0.6))
            .frame(height: 0.5)
    }
}

struct SliderRow: View {
    let title: String
    let valueLabel: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var tint: Color = Theme.accentFill

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.callout.weight(.medium))
                Spacer()
                Text(valueLabel)
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(tint)
                    .frame(minWidth: 52, alignment: .trailing)
            }
            Slider(value: $value, in: range, step: step)
                .tint(tint)
        }
    }
}

// MARK: - Reminders

struct RemindersPreferences: View {
    @AppStorage(PreferenceKeys.showNotifications) private var showNotifications = true
    @AppStorage(PreferenceKeys.playSounds) private var playSounds = false
    @AppStorage(PreferenceKeys.fallbackAlertEnabled) private var fallbackAlertEnabled = true

    @ObservedObject private var notif = NotificationManager.shared

    private var tint: Color { PreferencesTab.reminders.tint }

    var body: some View {
        PreferencesScroll {
            PreferenceCard(
                icon: "bell.badge.fill",
                tint: tint,
                title: "Alerts",
                subtitle: "How DailyForge nudges you when it's time."
            ) {
                SettingRow(title: "Show system notifications") {
                    Toggle("", isOn: $showNotifications)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(tint)
                }
                RowDivider()
                SettingRow(title: "Play a sound with the reminder") {
                    Toggle("", isOn: $playSounds)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(tint)
                }
                RowDivider()
                SettingRow(
                    title: "In-app fallback alert",
                    subtitle: "Shown if the system notification can't be delivered."
                ) {
                    Toggle("", isOn: $fallbackAlertEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(tint)
                }
            }

            PreferenceCard(
                icon: "checkmark.shield.fill",
                tint: tint,
                title: "Notification status",
                subtitle: "macOS is the gatekeeper here."
            ) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(notif.isWorking ? Theme.success : Theme.warning)
                        .frame(width: 9, height: 9)
                        .shadow(color: (notif.isWorking ? Theme.success : Theme.warning).opacity(0.6), radius: 4)
                    Text(notif.statusLabel)
                        .font(.callout.weight(.medium))
                    Spacer()
                    Button {
                        notif.sendTest()
                    } label: {
                        Label("Send Test", systemImage: "paperplane.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                RowDivider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Last delivery")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                    Text(notif.lastDeliveryResult)
                        .font(.caption.monospaced())
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }

                if let error = notif.lastError {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.warning)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.warningSoft)
                    )
                }

                HStack(spacing: 8) {
                    Button {
                        notif.requestPermission()
                    } label: {
                        Label("Request Permission", systemImage: "hand.raised.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        notif.openSystemNotificationSettings()
                    } label: {
                        Label("System Settings", systemImage: "gear")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()
                }
            }
        }
        .onAppear { notif.refreshStatus() }
    }
}

// MARK: - Training

struct TrainingPreferences: View {
    @AppStorage(PreferenceKeys.minimumExercises) private var minimumExercises: Int = Preferences.defaultMinimumExercises
    @AppStorage(PreferenceKeys.restDaysRaw) private var restDaysRaw: String = Preferences.defaultRestDaysRaw

    private var tint: Color { PreferencesTab.training.tint }

    private var restDays: Set<Int> {
        let parsed = restDaysRaw
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { (1...7).contains($0) }
        return Set(parsed.prefix(Preferences.maxRestDays))
    }

    private var atMaxRestDays: Bool {
        restDays.count >= Preferences.maxRestDays
    }

    var body: some View {
        PreferencesScroll {
            PreferenceCard(
                icon: "list.number",
                tint: tint,
                title: "Daily commitment",
                subtitle: "The minimum number of exercises a full day requires."
            ) {
                HStack(alignment: .center, spacing: 16) {
                    Text("\(minimumExercises)")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(tint)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: minimumExercises)
                        .frame(minWidth: 72, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("exercise\(minimumExercises == 1 ? "" : "s") per day")
                            .font(.callout.weight(.medium))
                        Text("Range \(Preferences.minimumExercisesRange.lowerBound)–\(Preferences.minimumExercisesRange.upperBound).")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Spacer()

                    Stepper(
                        "",
                        value: $minimumExercises,
                        in: Preferences.minimumExercisesRange
                    )
                    .labelsHidden()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.surfaceSunken)
                )
            }

            PreferenceCard(
                icon: "moon.zzz.fill",
                tint: tint,
                title: "Rest days",
                subtitle: "Up to \(Preferences.maxRestDays) days a week where your streak pauses instead of breaking."
            ) {
                HStack {
                    Text("Selected")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                    Spacer()
                    Text("\(restDays.count) of \(Preferences.maxRestDays)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(atMaxRestDays ? tint : Theme.textSecondary)
                }

                WeekdayChipRow(
                    selection: restDays,
                    max: Preferences.maxRestDays,
                    accent: tint
                ) { next in
                    restDaysRaw = DayLogic.restDaysRaw(from: next)
                }

                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                    Text("Rest days don't add to or subtract from your streak — they pause it.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Weekday chips

struct WeekdayChipRow: View {
    let selection: Set<Int>
    let max: Int
    let accent: Color
    let onChange: (Set<Int>) -> Void

    private var atMax: Bool { selection.count >= max }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { weekday in
                chip(for: weekday)
            }
        }
    }

    private func chip(for weekday: Int) -> some View {
        let isSelected = selection.contains(weekday)
        let isDisabled = !isSelected && atMax
        let letter = WeekdayNames.letters[weekday - 1]
        let label = WeekdayNames.full[weekday - 1]

        return Button {
            guard !isDisabled else { return }
            var next = selection
            if isSelected {
                next.remove(weekday)
            } else {
                next.insert(weekday)
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                onChange(next)
            }
        } label: {
            VStack(spacing: 2) {
                Text(letter)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isSelected ? Color.white : Theme.textPrimary)
                Text(String(label.prefix(3)))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? accent : Theme.surfaceSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.clear : Theme.border, lineWidth: 0.5)
            )
            .shadow(color: isSelected ? accent.opacity(0.35) : .clear, radius: 6, y: 2)
            .opacity(isDisabled ? 0.35 : 1.0)
        }
        .buttonStyle(.plain)
        .help(isDisabled ? "Maximum \(max) rest days" : label)
    }
}

// MARK: - Enforcement

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

    private var tint: Color { PreferencesTab.enforcement.tint }

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
        PreferencesScroll {
            reminderCard
            kioskCard
            overlayCard
            swearCard
        }
    }

    private var reminderCard: some View {
        PreferenceCard(
            icon: "bell.badge.fill",
            tint: tint,
            title: "Daily reminder",
            subtitle: "When the nudge lands and how long you have to respond."
        ) {
            SettingRow(
                title: "Enable daily reminder",
                subtitle: reminderEnabled ? "The app will remind you each workout day." : "Currently off — no reminders will fire."
            ) {
                Toggle("", isOn: $reminderEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(tint)
            }

            RowDivider()

            SettingRow(title: "Remind me at") {
                DatePicker("", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .disabled(!reminderEnabled)
            }

            RowDivider()

            SliderRow(
                title: "Grace period",
                valueLabel: "\(graceMinutes) min",
                value: Binding(
                    get: { Double(graceMinutes) },
                    set: { graceMinutes = Int($0) }
                ),
                range: 1...60,
                step: 1,
                tint: tint
            )
            .disabled(!reminderEnabled)
            .opacity(reminderEnabled ? 1 : 0.5)
        }
    }

    private var kioskCard: some View {
        PreferenceCard(
            icon: "lock.shield.fill",
            tint: tint,
            title: "Kiosk mode",
            subtitle: "What happens if you ignore the reminder."
        ) {
            SettingRow(
                title: "Flash the screen",
                subtitle: "Overlay every display until today's exercises are done."
            ) {
                Toggle("", isOn: $enforceKiosk)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(tint)
                    .disabled(!reminderEnabled)
            }
            .opacity(reminderEnabled ? 1 : 0.5)
        }
    }

    private var overlayCard: some View {
        PreferenceCard(
            icon: "paintpalette.fill",
            tint: tint,
            title: "Overlay appearance",
            subtitle: "Dial in the look of the enforcement overlay."
        ) {
            HStack {
                Text("Tint color")
                    .font(.callout.weight(.medium))
                Spacer()
                ColorPicker("", selection: Binding(
                    get: { Color(hex: overlayColorHex) },
                    set: { overlayColorHex = $0.hexString }
                ))
                .labelsHidden()
                Text(overlayColorHex.uppercased())
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 70, alignment: .trailing)
            }

            RowDivider()

            SliderRow(
                title: "Faint opacity",
                valueLabel: String(format: "%.0f%%", overlayMinOpacity * 100),
                value: $overlayMinOpacity,
                range: 0...1,
                step: 0.02,
                tint: tint
            )

            SliderRow(
                title: "Bright opacity",
                valueLabel: String(format: "%.0f%%", overlayMaxOpacity * 100),
                value: Binding(
                    get: { overlayMaxOpacity },
                    set: { overlayMaxOpacity = max($0, overlayMinOpacity + 0.02) }
                ),
                range: 0.02...1,
                step: 0.02,
                tint: tint
            )

            SliderRow(
                title: "Pulse speed",
                valueLabel: String(format: "%.1fs", overlayPulseSeconds),
                value: $overlayPulseSeconds,
                range: 0.3...3.0,
                step: 0.1,
                tint: tint
            )

            HStack {
                Spacer()
                Button {
                    OverlayEnforcer.shared.preview(duration: 3)
                } label: {
                    Label("Preview (3s)", systemImage: "eye.fill")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var swearCard: some View {
        PreferenceCard(
            icon: "quote.bubble.fill",
            tint: tint,
            title: "Swear phrase",
            subtitle: "What you must say out loud to seal a completed day."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Current phrase")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.4)

                Text("“\(swearPhrase)”")
                    .font(.callout.italic())
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.surfaceSunken)
                    )
            }

            RowDivider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Edit phrase")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.4)

                TextField("", text: $phraseDraft, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                    .onAppear { phraseDraft = swearPhrase }
            }

            if let phraseError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.danger)
                        .font(.caption)
                    Text(phraseError)
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }
            }

            HStack(spacing: 8) {
                Button {
                    phraseDraft = Preferences.defaultSwearPhrase
                    phraseError = nil
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button {
                    savePhrase()
                } label: {
                    Label("Save Phrase", systemImage: "checkmark")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(
                    phraseDraft.trimmingCharacters(in: .whitespaces).isEmpty
                    || phraseDraft == swearPhrase
                )
            }
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

// MARK: - Focus

struct FocusPreferences: View {
    @AppStorage(PreferenceKeys.focusModeEnabled) private var focusEnabled: Bool = false
    @AppStorage(PreferenceKeys.focusHideDockAndMenuBar) private var hideDockAndMenuBar: Bool = true
    @AppStorage(PreferenceKeys.focusShortcutName) private var shortcutName: String = ""

    @State private var shortcutDraft: String = ""
    @State private var testStatus: String?

    private var tint: Color { PreferencesTab.focus.tint }

    var body: some View {
        PreferencesScroll {
            PreferenceCard(
                icon: "moon.stars.fill",
                tint: tint,
                title: "Session focus",
                subtitle: "What happens during a workout session."
            ) {
                SettingRow(
                    title: "Enable Focus mode",
                    subtitle: "The app enters a distraction-free state while a session is running."
                ) {
                    Toggle("", isOn: $focusEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(tint)
                }
                RowDivider()
                SettingRow(
                    title: "Hide Dock & Menu Bar",
                    subtitle: "Removes chrome from the edges of the screen."
                ) {
                    Toggle("", isOn: $hideDockAndMenuBar)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(tint)
                        .disabled(!focusEnabled)
                }
            }

            PreferenceCard(
                icon: "wand.and.stars",
                tint: tint,
                title: "Focus Shortcut",
                subtitle: "Optionally run a macOS Shortcut when a session starts. Create one in the Shortcuts app, then paste its name here."
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shortcut name")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.4)
                    TextField("e.g. Workout Focus", text: $shortcutDraft)
                        .textFieldStyle(.roundedBorder)
                        .onAppear { shortcutDraft = shortcutName }
                }

                HStack(spacing: 8) {
                    Button {
                        saveShortcut()
                    } label: {
                        Label("Save", systemImage: "checkmark")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(shortcutDraft.trimmingCharacters(in: .whitespaces) == shortcutName)

                    Button {
                        shortcutDraft = ""
                        saveShortcut()
                    } label: {
                        Label("Clear", systemImage: "xmark")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(shortcutName.isEmpty && shortcutDraft.isEmpty)

                    Spacer()

                    Button {
                        testFocus()
                    } label: {
                        Label("Test Focus (3s)", systemImage: "play.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!focusEnabled)
                }

                if let testStatus {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.textTertiary)
                        Text(testStatus)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }

            PreferenceCard(
                icon: "questionmark.circle.fill",
                tint: Theme.textSecondary,
                title: "How it works",
                subtitle: nil
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    InfoLine(text: "Focus mode engages when you tap Start Workout and releases when the session ends.")
                    InfoLine(text: "If you have a Shortcut configured, it runs on session start. Focus state is not automatically reverted — add a matching shortcut or manual trigger if you want symmetric Focus toggling.")
                    InfoLine(text: "Dock and Menu Bar are hidden for the duration. Everything is restored on exit.")
                }
            }
        }
    }

    private func saveShortcut() {
        let trimmed = shortcutDraft.trimmingCharacters(in: .whitespaces)
        shortcutName = trimmed
        shortcutDraft = trimmed
        testStatus = trimmed.isEmpty ? "Shortcut cleared." : "Shortcut saved: \(trimmed)"
    }

    private func testFocus() {
        FocusModeManager.shared.engage()
        testStatus = "Focus mode engaged for 3 seconds…"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            FocusModeManager.shared.release()
            testStatus = "Focus mode released."
        }
    }
}

private struct InfoLine: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 4))
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 7)
            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
