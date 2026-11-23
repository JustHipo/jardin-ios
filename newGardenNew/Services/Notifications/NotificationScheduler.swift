import Foundation
import os
import UserNotifications

/// Local notifications, redesigned per the reasoning agreed with the design session
/// (docs/ANALISIS_IMPLEMENTACION.md section 4, decision 10):
///
/// - ONE daily digest at the user's preferred hour ("3 plantas necesitan agua hoy"),
///   instead of two `UNTimeIntervalNotificationTrigger` alerts PER PLANT. That old scheme
///   breaks silently past 32 plants (iOS caps pending notifications at 64 per app), and
///   fires at whatever hour the interval happens to lapse, including the middle of the
///   night.
/// - A bounded exception for germination (M08): two alerts a day, only while a plant is in
///   that stage, only for a capped number of plants at once, so the 64-notification ceiling
///   stays out of reach.
enum NotificationScheduler {
    private static let digestIdentifier = "com.ipo.newGardenNew.dailyDigest"
    private static let germinationPrefix = "com.ipo.newGardenNew.germination."
    /// Keeps germination's own notification budget well under the 64 pending-request ceiling.
    static let maxSimultaneousGerminations = 20

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            AppLog.notifications.error("Permission request failed: \(error, privacy: .public)")
            return false
        }
    }

    /// Schedules tomorrow's digest at `hour`. The actual count of pending plants is computed
    /// at fire time via a notification content extension in a future iteration; for now the
    /// body is generic and the app badge carries the count (see `updateBadge`).
    static func scheduleDailyDigest(hour: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [digestIdentifier])

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.digest.title", defaultValue: "Tu jardín")
        content.body = String(localized: "notification.digest.body", defaultValue: "Revisa qué plantas necesitan agua hoy.")
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: digestIdentifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error {
                AppLog.notifications.error("Digest schedule failed: \(error, privacy: .public)")
            }
        }
    }

    static func cancelDailyDigest() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [digestIdentifier])
    }

    /// Two alerts a day for a plant in germination. Caller is responsible for respecting
    /// `maxSimultaneousGerminations` across all plants before calling this.
    static func scheduleGermination(plantId: UUID, plantName: String) {
        let center = UNUserNotificationCenter.current()
        let morningId = germinationPrefix + plantId.uuidString + ".am"
        let eveningId = germinationPrefix + plantId.uuidString + ".pm"
        center.removePendingNotificationRequests(withIdentifiers: [morningId, eveningId])

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.germination.title", defaultValue: "Pulveriza")
        content.body = plantName
        content.sound = .default

        for (id, hour) in [(morningId, 9), (eveningId, 19)] {
            var components = DateComponents()
            components.hour = hour
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request) { error in
                if let error {
                    AppLog.notifications.error("Germination schedule failed: \(error, privacy: .public)")
                }
            }
        }
    }

    static func cancelGermination(plantId: UUID) {
        let ids = [germinationPrefix + plantId.uuidString + ".am", germinationPrefix + plantId.uuidString + ".pm"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func updateBadge(overdueCount: Int) {
        UNUserNotificationCenter.current().setBadgeCount(overdueCount) { error in
            if let error {
                AppLog.notifications.error("Badge update failed: \(error, privacy: .public)")
            }
        }
    }
}
