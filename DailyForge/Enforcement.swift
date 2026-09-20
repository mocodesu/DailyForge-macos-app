import Foundation
import AppKit
import SwiftUI
import Combine
import UserNotifications
import SwiftData

// MARK: - DayState

class DayState: ObservableObject {
    static let shared = DayState()

    @Published var allDone: Bool = false
    @Published var isLocked: Bool = false
    @Published var exerciseCount: Int = 0
    @Published var dayKey: String = DayLogic.dayKey()

    private init() {}
}

// MARK: - EnforcementController

class EnforcementController: ObservableObject {
    static let shared = EnforcementController()

    private var checkTimer: Timer?
    private var graceTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var defaultsObserver: NSObjectProtocol?

    /// Stores "dayKey:reminderSeconds" so changing the reminder time mid-day
    /// produces a new fingerprint and the new time can fire.
    private let lastReminderKey = "lastReminderFingerprint"

    private init() {
        DayState.shared.$allDone
            .receive(on: DispatchQueue.main)
            .sink { allDone in
                if allDone && OverlayEnforcer.shared.isActive {
                    OverlayEnforcer.shared.stop()
                }
            }
            .store(in: &cancellables)

        // Watch for preference changes so updates are picked up immediately
        // rather than waiting for the 30-second tick.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            self?.tick()
        }
    }

    deinit {
        if let observer = defaultsObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func start() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.tick()
        }
        tick()
    }

    func stop() {
        checkTimer?.invalidate()
        checkTimer = nil
        graceTimer?.invalidate()
        graceTimer = nil
    }

    /// Public entry point for external callers (e.g. PreferencesWindowController)
    /// to force an immediate re-evaluation.
    func refresh() {
        tick()
    }

    // MARK: - Launch evaluation (today only)

    func handleLaunch(container: ModelContainer) {
        guard UserDefaults.standard.bool(forKey: PreferenceKeys.reminderEnabled),
              UserDefaults.standard.bool(forKey: PreferenceKeys.enforceKiosk) else { return }

        let context = ModelContext(container)
        guard let exercises = try? context.fetch(FetchDescriptor<Exercise>()),
              let records = try? context.fetch(FetchDescriptor<CompletionRecord>()) else { return }

        let dailyExercises = exercises.filter { $0.isDaily }
        guard !dailyExercises.isEmpty else {
            print("✅ Launch: no daily exercises.")
            return
        }

        let reminderSeconds = UserDefaults.standard.integer(forKey: PreferenceKeys.reminderTimeSeconds)
        let startOfDay = Calendar.current.startOfDay(for: Date())
        guard let reminderDate = Calendar.current.date(
            byAdding: .second, value: reminderSeconds, to: startOfDay
        ) else { return }

        if Date() < reminderDate {
            print("⏳ Launch: reminder hasn't fired yet today. Waiting.")
            return
        }

        let dueToday = dailyExercises.filter { $0.createdAt <= reminderDate }
        guard !dueToday.isEmpty else {
            print("✅ Launch: no exercises due today.")
            return
        }

        let key = DayLogic.dayKey()
        let completed = Set(records.filter { $0.dayKey == key }.map(\.exerciseID))
        let remaining = dueToday.filter { !completed.contains($0.id) }

        guard !remaining.isEmpty else {
            print("✅ Launch: everything due today is done.")
            return
        }

        print("🛡️ Launch: engaging overlay — \(remaining.count) exercise(s) remaining today.")
        DayState.shared.exerciseCount = remaining.count
        fireLaunchNotification()
        OverlayEnforcer.shared.start()
    }

    // MARK: - Timer tick

    private func tick() {
        guard UserDefaults.standard.bool(forKey: PreferenceKeys.reminderEnabled) else { return }
        guard let reminderDate = todayReminderDate() else { return }
        guard Date() >= reminderDate else { return }

        let today = DayLogic.dayKey()
        let reminderSeconds = UserDefaults.standard.integer(forKey: PreferenceKeys.reminderTimeSeconds)
        let fingerprint = "\(today):\(reminderSeconds)"

        // Fire only when the (day, time) combination hasn't been fired yet.
        // Changing the reminder time mid-day changes the fingerprint and
        // therefore allows a new reminder to fire.
        if UserDefaults.standard.string(forKey: lastReminderKey) != fingerprint {
            UserDefaults.standard.set(fingerprint, forKey: lastReminderKey)
            fireReminder()
        } else {
            let graceSeconds = UserDefaults.standard.integer(forKey: PreferenceKeys.graceMinutes) * 60
            let graceDeadline = reminderDate.addingTimeInterval(Double(graceSeconds))
            if Date() >= graceDeadline {
                engageIfNeeded()
            }
        }
    }

    private func todayReminderDate() -> Date? {
        let seconds = UserDefaults.standard.integer(forKey: PreferenceKeys.reminderTimeSeconds)
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(byAdding: .second, value: seconds, to: startOfDay)
    }

    private func fireReminder() {
        guard !DayState.shared.allDone else { return }

        let title = "Time to work out"
        let body = "Your DailyForge exercises are waiting. You have \(UserDefaults.standard.integer(forKey: PreferenceKeys.graceMinutes)) minutes."

        var delivered = false
        if UserDefaults.standard.bool(forKey: PreferenceKeys.showNotifications) {
            delivered = NotificationManager.shared.send(title: title, body: body, isCritical: true)
        }
        if !delivered && UserDefaults.standard.bool(forKey: PreferenceKeys.fallbackAlertEnabled) {
            showFallbackAlert(title: title, body: body)
        }
        if UserDefaults.standard.bool(forKey: PreferenceKeys.playSounds) {
            NSSound(named: "Ping")?.play()
        }

        graceTimer?.invalidate()
        let graceSeconds = Double(UserDefaults.standard.integer(forKey: PreferenceKeys.graceMinutes) * 60)
        graceTimer = Timer.scheduledTimer(withTimeInterval: graceSeconds, repeats: false) { [weak self] _ in
            self?.engageIfNeeded()
        }
    }

    private func fireLaunchNotification() {
        let title = "Time to work out"
        let body = "The reminder time has passed and your exercises aren't done."

        var delivered = false
        if UserDefaults.standard.bool(forKey: PreferenceKeys.showNotifications) {
            delivered = NotificationManager.shared.send(title: title, body: body, isCritical: true)
        }
        if !delivered && UserDefaults.standard.bool(forKey: PreferenceKeys.fallbackAlertEnabled) {
            showFallbackAlert(title: title, body: body)
        }
        if UserDefaults.standard.bool(forKey: PreferenceKeys.playSounds) {
            NSSound(named: "Funk")?.play()
        }
    }

    private func showFallbackAlert(title: String, body: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = body
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: {
                $0.isVisible && $0.canBecomeKey && $0.styleMask.contains(.titled)
            }) {
                alert.beginSheetModal(for: window) { _ in }
            } else {
                alert.runModal()
            }
        }
    }

    private func engageIfNeeded() {
        guard UserDefaults.standard.bool(forKey: PreferenceKeys.enforceKiosk) else { return }
        guard !DayState.shared.allDone else { return }
        guard DayState.shared.exerciseCount > 0 else { return }
        OverlayEnforcer.shared.start()
    }
}

// MARK: - OverlayEnforcer

class OverlayEnforcer: ObservableObject {
    static let shared = OverlayEnforcer()

    @Published private(set) var isActive: Bool = false

    private var overlayWindows: [NSWindow] = []
    private weak var mainWindow: NSWindow?
    private var savedMainWindowLevel: NSWindow.Level?
    private var savedMainWindowStyleMask: NSWindow.StyleMask?
    private var savedPresentationOptions: NSApplication.PresentationOptions?
    private var previewTimer: Timer?
    private var keyMonitor: Any?

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard !isActive else { return }
        isActive = true

        NSApp.activate(ignoringOtherApps: true)

        savedPresentationOptions = NSApp.presentationOptions
        NSApp.presentationOptions = [.hideMenuBar, .hideDock]

        showMainWindowIfNeeded()
        elevateMainWindow(attemptsRemaining: 10)
        rebuildWindows(blockClicks: true)
        installQuitBlocker()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func preview(duration: TimeInterval) {
        guard !isActive else { return }
        isActive = true
        rebuildWindows(blockClicks: false)
        previewTimer?.invalidate()
        previewTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.stop()
        }
    }

    func stop() {
        guard isActive else { return }
        isActive = false

        previewTimer?.invalidate()
        previewTimer = nil

        removeQuitBlocker()

        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        if let saved = savedPresentationOptions {
            NSApp.presentationOptions = saved
            savedPresentationOptions = nil
        }

        if let window = mainWindow {
            if let saved = savedMainWindowLevel { window.level = saved }
            if let savedMask = savedMainWindowStyleMask { window.styleMask = savedMask }
        }
        mainWindow = nil
        savedMainWindowLevel = nil
        savedMainWindowStyleMask = nil

        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }

    @objc private func screensChanged() {
        guard isActive else { return }
        rebuildWindows(blockClicks: true)
    }

    // MARK: - Quit blocking

    private func installQuitBlocker() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isActive else { return event }
            guard event.modifierFlags.contains(.command) else { return event }
            if let chars = event.charactersIgnoringModifiers?.lowercased() {
                if ["q", "w", "h", "m"].contains(chars) { return nil }
            }
            return event
        }
    }

    private func removeQuitBlocker() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // MARK: - Main window

    private func showMainWindowIfNeeded() {
        let hasVisibleMain = NSApp.windows.contains {
            $0.isVisible && $0.canBecomeKey && $0.styleMask.contains(.titled)
        }
        if !hasVisibleMain {
            NSApp.windows.forEach { $0.makeKeyAndOrderFront(nil) }
        }
    }

    private func elevateMainWindow(attemptsRemaining: Int) {
        guard let window = findMainWindow() else {
            guard attemptsRemaining > 0 else {
                print("⚠️ OverlayEnforcer: could not find main window to elevate")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self, self.isActive else { return }
                self.elevateMainWindow(attemptsRemaining: attemptsRemaining - 1)
            }
            return
        }

        mainWindow = window
        savedMainWindowLevel = window.level
        savedMainWindowStyleMask = window.styleMask

        window.level = .modalPanel
        window.styleMask.remove(.closable)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func findMainWindow() -> NSWindow? {
        let overlayIDs = Set(overlayWindows.map(ObjectIdentifier.init))
        let candidates = NSApp.windows.filter { window in
            !overlayIDs.contains(ObjectIdentifier(window))
            && window.canBecomeKey
            && window.isVisible
            && window.styleMask.contains(.titled)
        }
        return candidates.first { $0.isKeyWindow || $0.isMainWindow } ?? candidates.first
    }

    private func rebuildWindows(blockClicks: Bool) {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .floating
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false
            window.ignoresMouseEvents = !blockClicks
            window.collectionBehavior = [
                .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle
            ]
            window.contentView = NSHostingView(rootView: OverlayEnforcerView())
            window.orderFrontRegardless()
            overlayWindows.append(window)
        }

        if let mainWindow = mainWindow {
            mainWindow.orderFrontRegardless()
        }
    }
}
