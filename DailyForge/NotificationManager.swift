import Foundation
import AppKit
import UserNotifications
import Combine

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var lastError: String?
    @Published var lastDeliveryResult: String = "—"

    private override init() {
        super.init()
    }

    /// Call this once at app launch, before any notification is sent.
    /// Registers this object as the center's delegate so we can intercept
    /// `willPresent` and force banners to show even when we're frontmost.
    func bootstrap() {
        UNUserNotificationCenter.current().delegate = self
        refreshStatus()
    }

    func refreshStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.lastError = error.localizedDescription
                }
                self.lastDeliveryResult = "Permission granted: \(granted)"
                self.refreshStatus()
            }
        }
    }

    @discardableResult
    func send(title: String, body: String, isCritical: Bool = false) -> Bool {
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            DispatchQueue.main.async {
                self.lastDeliveryResult = "Skipped — status is \(self.statusLabel)"
            }
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = isCritical ? .defaultCritical : .default
        // Force the notification to appear as a banner and stay on screen
        content.interruptionLevel = isCritical ? .critical : .timeSensitive

        let request = UNNotificationRequest(
            identifier: "dailyforge.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.lastError = error.localizedDescription
                    self.lastDeliveryResult = "Delivery error: \(error.localizedDescription)"
                } else {
                    self.lastDeliveryResult = "Queued at \(Date().formatted(date: .omitted, time: .standard))"
                }
            }
        }
        return true
    }

    func sendTest() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .notDetermined {
                    self.requestPermission()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.deliverTest()
                    }
                } else {
                    self.deliverTest()
                }
            }
        }
    }

    private func deliverTest() {
        let content = UNMutableNotificationContent()
        content.title = "DailyForge Test"
        content.body = "Notifications are working. This is what a reminder looks like."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "dailyforge.test.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.lastError = error.localizedDescription
                    self.lastDeliveryResult = "Test failed: \(error.localizedDescription)"
                } else {
                    self.lastDeliveryResult = "Test queued at \(Date().formatted(date: .omitted, time: .standard))"
                }
            }
        }
    }

    func openSystemNotificationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!
        NSWorkspace.shared.open(url)
    }

    var statusLabel: String {
        switch authorizationStatus {
        case .authorized: return "Allowed"
        case .denied: return "Denied — enable in System Settings"
        case .notDetermined: return "Not yet requested"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default: return "Unknown"
        }
    }

    var isWorking: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when a notification is about to be shown while the app is
    /// running. Returning `[.banner, .sound]` forces macOS to display it
    /// even when DailyForge is the frontmost app (which is normally
    /// suppressed by default).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
