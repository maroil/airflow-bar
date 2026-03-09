import SwiftUI

@main
struct AirflowBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar apps don't need a window scene — everything is driven
        // by AppDelegate and the NSStatusItem. We use a Settings scene
        // so ⌘, can open settings via the standard mechanism.
        Settings {
            EmptyView()
        }
    }
}
