import Foundation

/// Turns a `Plant`'s watering state into the DS three-channel presentation (color, shape and
/// text at once — fixes A4, WCAG 1.4.1) and into human copy instead of database vocabulary
/// like "effectiveCycleDays" (H2 in the old audit).
extension Plant {
    var dsWateringState: DSWateringState {
        switch wateringStatus {
        case .ok: .ok
        case .soon: .soon
        case .overdue: .overdue
        case .neverWatered: .unknown
        }
    }

    /// "2 días de retraso", "Riega hoy", "En 3 días", "Sin registro".
    var wateringDetailText: String {
        guard let daysUntilDue else {
            return String(localized: "watering.detail.never", defaultValue: "Sin registro")
        }
        if daysUntilDue < 0 {
            let overdueBy = -daysUntilDue
            return overdueBy == 1
                ? String(localized: "watering.detail.overdueOne", defaultValue: "1 día de retraso")
                : "\(overdueBy) días de retraso"
        }
        if daysUntilDue == 0 {
            return String(localized: "watering.detail.today", defaultValue: "Riega hoy")
        }
        return daysUntilDue == 1
            ? String(localized: "watering.detail.inOneDay", defaultValue: "En 1 día")
            : "En \(daysUntilDue) días"
    }
}
