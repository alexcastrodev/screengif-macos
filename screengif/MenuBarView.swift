import SwiftUI

struct MenuBarView: View {
    @ObservedObject var recorder: ScreenRecorder

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Status
            switch recorder.state {
            case .idle:
                Label("Pronto para gravar", systemImage: "circle")
                    .foregroundStyle(.secondary)
            case .selectingRegion:
                Label("Selecione uma região...", systemImage: "rectangle.dashed")
                    .foregroundStyle(.orange)
            case .recording:
                HStack {
                    Label("Gravando", systemImage: "record.circle.fill")
                        .foregroundStyle(.red)
                    Spacer()
                    Text(formatDuration(recorder.recordingDuration))
                        .monospacedDigit()
                        .foregroundStyle(.red)
                }
            case .encoding:
                Label("Gerando GIF...", systemImage: "gearshape.2.fill")
                    .foregroundStyle(.blue)
            }

            Divider()

            if recorder.state == .recording {
                Button {
                    recorder.stopRecording()
                } label: {
                    Label("Parar Gravação", systemImage: "stop.fill")
                }
                .keyboardShortcut("6", modifiers: [.command, .shift])
            } else if recorder.state == .idle {
                Button {
                    recorder.startRegionSelection()
                } label: {
                    Label("Selecionar Região", systemImage: "rectangle.dashed")
                }
                .keyboardShortcut("6", modifiers: [.command, .shift])

                Button {
                    recorder.recordFullScreen()
                } label: {
                    Label("Tela Inteira", systemImage: "desktopcomputer")
                }
            }

            if let error = recorder.errorMessage {
                Divider()
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            if let url = recorder.lastSavedURL {
                Divider()
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Label(url.lastPathComponent, systemImage: "doc.fill")
                }
                .help("Abrir no Finder")
            }

            Divider()

            HStack {
                Text("Atalho: ⌘⇧6")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }

            Button("Sair") {
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
