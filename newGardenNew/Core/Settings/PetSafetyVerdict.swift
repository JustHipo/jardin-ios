import Foundation

/// Whether a plant is safe around pets. A plain `Bool?` invites `?? false`, which silently
/// renders "not yet known" as "safe" — exactly the failure mode the old app was one typo
/// away from. This type makes "unknown" a real case the caller must handle.
enum PetSafetyVerdict: Sendable, Equatable {
    case safe
    case toxic(notes: String?)
    case unknown

    init(isToxic: Bool?, notes: String?) {
        switch isToxic {
        case true: self = .toxic(notes: notes)
        case false: self = .safe
        case nil: self = .unknown
        }
    }

    var isToxic: Bool {
        if case .toxic = self { return true }
        return false
    }
}
