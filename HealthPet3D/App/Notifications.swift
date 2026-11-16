import UIKit
import UserNotifications

/// The only two notifications (PRD v0.2), both opt-in and each at most once a day:
/// 30 minutes before the bedtime target, the pet is getting sleepy; at the wake-up target,
/// last night's result is waiting (the morning reveal happens when the app opens).
/// Weekend targets apply to Friday and Saturday nights and to Saturday and Sunday mornings.
/// Each carries a small picture of the main pet on a card-coloured square (bubble-settings-v1),
/// its ^^ face in the morning.
@MainActor
enum PetNotifications {
    private static let bedtimePrefix = "hp3d.bedtime."
    private static let morningPrefix = "hp3d.morning."

    /// Asks for permission the first time a switch is turned on. False = the user said no.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Replaces every pending reminder with what the settings say now.
    static func reschedule(bedtime: Bool, morning: Bool, schedule: SleepSchedule, pet: Pet3D) {
        let center = UNUserNotificationCenter.current()
        let ids = (1...7).flatMap { ["\(bedtimePrefix)\($0)", "\(morningPrefix)\($0)"] }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard bedtime || morning else { return }
        let petName = pet.name
        let sleepy = bedtime ? picture(pet.still) : nil
        let happy = morning ? picture(pet.happyStill) : nil

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
                content.attachments = attachment(sleepy, id: "\(bedtimePrefix)\(weekday)")
                add(center, id: "\(bedtimePrefix)\(weekday)", content: content,
                    when: DateComponents(calendar: calendar, hour: minutes / 60, minute: minutes % 60, weekday: day))
            }
            if morning {
                let content = UNMutableNotificationContent()
                content.title = "\(petName) is awake"
                content.body = "See how last night went."
                content.attachments = attachment(happy, id: "\(morningPrefix)\(weekday)")
                add(center, id: "\(morningPrefix)\(weekday)", content: content,
                    when: DateComponents(calendar: calendar, hour: wake / 60, minute: wake % 60, weekday: weekday))
            }
        }
    }

    /// The pet's still on a rounded card-coloured square, as PNG data.
    private static func picture(_ name: String) -> Data? {
        guard let still = UIImage(named: name) else { return nil }
        let side: CGFloat = 240
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            UIColor(hex: 0xF8F6F3).setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: side, height: side), cornerRadius: side * 0.22).fill()
            let inset = side * 0.12
            still.draw(in: CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2))
        }
        return image.pngData()
    }

    /// The system moves an attachment's file into its own store, so every request gets a copy.
    private static func attachment(_ data: Data?, id: String) -> [UNNotificationAttachment] {
        guard let data else { return [] }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(id).png")
        guard (try? data.write(to: url, options: .atomic)) != nil,
              let attachment = try? UNNotificationAttachment(identifier: "pet", url: url, options: nil) else { return [] }
        return [attachment]
    }

    private static func add(_ center: UNUserNotificationCenter, id: String, content: UNNotificationContent, when: DateComponents) {
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { _ in }
    }
}
