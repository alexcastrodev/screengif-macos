import SwiftUI

struct MenuBarView: View {
    @ObservedObject var coordinator: RecordingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch coordinator.state {
            case .idle:
                Label("Ready to record", systemImage: "circle")
                    .foregroundStyle(.secondary)
            case .selectingRegion:
                Label("Select a region...", systemImage: "rectangle.dashed")
                    .foregroundStyle(.orange)
            case .recording:
                HStack {
                    Label("Recording", systemImage: "record.circle.fill")
                        .foregroundStyle(.red)
                    Spacer()
                    Text(formatDuration(coordinator.recordingDuration))
                        .monospacedDigit()
                        .foregroundStyle(.red)
                }
            case .encoding:
                Label("Generating GIF...", systemImage: "gearshape.2.fill")
                    .foregroundStyle(.blue)
            }

            Divider()

            if coordinator.state == .recording {
                Button {
                    coordinator.stopRecording()
                } label: {
                    Label("Stop Recording", systemImage: "stop.fill")
                }
                .keyboardShortcut("6", modifiers: [.command, .shift])
            } else if coordinator.state == .idle {
                Button {
                    coordinator.startRegionSelection()
                } label: {
                    Label("Select Region", systemImage: "rectangle.dashed")
                }
                .keyboardShortcut("6", modifiers: [.command, .shift])

                Button {
                    coordinator.recordFullScreen()
                } label: {
                    Label("Full Screen", systemImage: "desktopcomputer")
                }
            } else if coordinator.state == .selectingRegion {
                Button {
                    coordinator.cancelSelection()
                } label: {
                    Label("Cancel Selection", systemImage: "xmark.circle")
                }
                .keyboardShortcut(.escape, modifiers: [])
            }

            if let error = coordinator.errorMessage {
                Divider()
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            if let url = coordinator.lastSavedURL {
                Divider()
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Label(url.lastPathComponent, systemImage: "doc.fill")
                }
                .help("Open in Finder")
            }

            Divider()

            HStack {
                Text("Shortcut: ⌘⇧6")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(4)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int(duration * 10) % 10
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}
