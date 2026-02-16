import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct screengifApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var coordinator = RecordingCoordinator()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(coordinator: coordinator)
        } label: {
            Label(
                coordinator.state == .recording ? "Recording..." : "ScreenGif",
                systemImage: coordinator.state == .recording ? "record.circle.fill" : "record.circle"
            )
        }
    }
}
