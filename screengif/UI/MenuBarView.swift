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

            Menu("Frame Rate") {
                Button {
                    coordinator.settings.fps = 5
                } label: {
                    if coordinator.settings.fps == 5 {
                        Label("5 FPS", systemImage: "checkmark")
                    } else {
                        Text("5 FPS")
                    }
                }
                
                Button {
                    coordinator.settings.fps = 10
                } label: {
                    if coordinator.settings.fps == 10 {
                        Label("10 FPS", systemImage: "checkmark")
                    } else {
                        Text("10 FPS")
                    }
                }

                Button {
                    coordinator.settings.fps = 15
                } label: {
                    if coordinator.settings.fps == 15 {
                        Label("15 FPS", systemImage: "checkmark")
                    } else {
                        Text("15 FPS")
                    }
                }

                Button {
                    coordinator.settings.fps = 30
                } label: {
                    if coordinator.settings.fps == 30 {
                        Label("30 FPS", systemImage: "checkmark")
                    } else {
                        Text("30 FPS")
                    }
                }
                
                Button {
                    coordinator.settings.fps = 60
                } label: {
                    if coordinator.settings.fps == 60 {
                        Label("60 FPS", systemImage: "checkmark")
                    } else {
                        Text("60 FPS")
                    }
                }
            }
            
            Menu("Size Limit") {
                Button {
                    coordinator.settings.maxGIFWidth = 640
                } label: {
                    if coordinator.settings.maxGIFWidth == 640 {
                        Label("Small (640px)", systemImage: "checkmark")
                    } else {
                        Text("Small (640px)")
                    }
                }
                
                Button {
                    coordinator.settings.maxGIFWidth = 1080
                } label: {
                    if coordinator.settings.maxGIFWidth == 1080 {
                        Label("Medium (1080px)", systemImage: "checkmark")
                    } else {
                        Text("Medium (1080px)")
                    }
                }

                Button {
                    coordinator.settings.maxGIFWidth = 3840
                } label: {
                    if coordinator.settings.maxGIFWidth == 3840 {
                        Label("Original / 4K (3840px)", systemImage: "checkmark")
                    } else {
                        Text("Original / 4K (3840px)")
                    }
                }
            }

            Divider()

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
