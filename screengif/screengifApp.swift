import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct screengifApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var recorder = ScreenRecorder()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(recorder: recorder)
        } label: {
            Label(
                recorder.state == .recording ? "Gravando..." : "ScreenGif",
                systemImage: recorder.state == .recording ? "record.circle.fill" : "record.circle"
            )
        }
    }
}
