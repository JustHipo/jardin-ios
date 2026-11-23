/// The widget's `kind` identifier, shared so the app (reloading timelines after a watering
/// or a cycle recompute) and the extension (defining and reloading its own widget) never
/// drift into two different strings.
enum GardenWidgetKind {
    static let identifier = "com.ipo.newGardenNew.garden"
}
