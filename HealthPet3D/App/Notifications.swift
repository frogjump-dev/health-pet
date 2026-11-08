import Foundation
import UserNotifications

/// The only two notifications (PRD v0.2), both opt-in and each at most once a day:
/// 30 minutes before the bedtime target, the pet is getting sleepy; at the wake-up target,
/// last night's result is waiting (the morning reveal happens when the app opens).
/// Weekend targets apply to Friday and Saturday nights and to Saturday and Sunday mornings.
@MainActor
enum PetNotifications {
    private static let bedtimePrefix = "hp3d.bedtime."
    private static let morningPrefix = "hp3d.morning."

    /// Asks for permission the first time a switch is turned on. False = the user said no.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Replaces every pending reminder with what the settings say now.
    static func reschedule(bedtime: Bool, morning: Bool, schedule: SleepSchedule, petName: String) {
        let center = UNUserNotificationCenter.current()
        let ids = (1...7).flatMap { ["\(bedtimePrefix)\($0)", "\(morningPrefix)\($0)"] }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard bedtime || morning else { return }

        let calendar = Calendar(identifier: .gregorian)
        // One request per weekday the night ends on (1 = Sunday … 7 = Saturday), repeating weekly.
        for weekday in 1...7 {
            let weekend = weekday == 1 || weekday == 7
            let bed = (weekend ? schedule.weekendBedtimeMinutes : nil) ?? schedule.bedtimeMinutes
            let wake = (weekend ? schedule.weekendWakeMinutes : nil) ?? schedule.wakeMinutes

            if bedtime {
                // minutes from the midnight that starts the morning's day; a bedtime in the evening is negative
                var minutes = (bed >= 12 * 60 ? bed - 24 * 60 : bed) - 30
                var day = weekday
                if minutes < 0 {
                    minutes += 24 * 60
                    day = weekday == 1 ? 7 : weekday - 1
                }
                let content = UNMutableNotificationContent()
                content.title = "\(petName) is getting sleepy"
                content.body = "Bedtime in 30 minutes."
                content.sound = .default
                add(center, id: "\(bedtimePrefix)\(weekday)", content: content,
                    when: DateComponents(calendar: calendar, hour: minutes / 60, minute: minutes % 60, weekday: day))
            }
            if morning {
                let content = UNMutableNotificationContent()
                content.title = "\(petName) is awake"
                content.body = "See how last night went."
                add(center, id: "\(morningPrefix)\(weekday)", content: content,
                    when: DateComponents(calendar: calendar, hour: wake / 60, minute: wake % 60, weekday: weekday))
            }
        }
    }

    private static func add(_ center: UNUserNotificationCenter, id: String, content: UNNotificationContent, when: DateComponents) {
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { _ in }
    }
}
