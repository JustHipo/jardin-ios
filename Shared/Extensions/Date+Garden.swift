import Foundation

extension Date {
    /// Fractional days elapsed since `earlier`. Negative if `earlier` is in the future.
    nonisolated func daysSince(_ earlier: Date) -> Double {
        timeIntervalSince(earlier) / 86_400
    }

    /// Whole calendar days elapsed since `earlier`, in the current calendar.
    ///
    /// Prefer this over `daysSince` for anything the user reads: a watering at 23:00 and a
    /// check at 01:00 is one day ago to a person, and 0.08 days to `timeIntervalSince`.
    nonisolated func calendarDaysSince(_ earlier: Date, calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: earlier)
        let to = calendar.startOfDay(for: self)
        return calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// Meteorological season name for the hemisphere the user is in.
    nonisolated func seasonForHemisphere(isNorthern: Bool) -> String {
        let month = Calendar.current.component(.month, from: self)
        switch month {
        case 3...5: return isNorthern ? "spring" : "autumn"
        case 6...8: return isNorthern ? "summer" : "winter"
        case 9...11: return isNorthern ? "autumn" : "spring"
        default: return isNorthern ? "winter" : "summer"
        }
    }
}

extension Date {
    /// Human-relative time, e.g. "hace 2 días". Used in history lists (M03).
    var timeAgoDescription: String {
        let seconds = Date.now.timeIntervalSince(self)
        if seconds < 60 {
            return String(localized: "time.justNow", defaultValue: "Justo ahora")
        } else if seconds < 3_600 {
            let minutes = Int(seconds / 60)
            return "Hace \(minutes) min"
        } else if seconds < 86_400 {
            let hours = Int(seconds / 3_600)
            return "Hace \(hours) h"
        } else {
            let days = Int(seconds / 86_400)
            return days == 1
                ? String(localized: "time.oneDayAgo", defaultValue: "Hace 1 día")
                : "Hace \(days) días"
        }
    }
}
