import SwiftUI

@main
struct ZenHabitApp: App {
    /// One store for the whole app, so every iPad window shows the same habits.
    @State private var store = HabitStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
