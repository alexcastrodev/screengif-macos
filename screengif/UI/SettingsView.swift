import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Recording") {
                Picker("Frame Rate", selection: $settings.fps) {
                    Text("5 FPS").tag(5)
                    Text("10 FPS").tag(10)
                    Text("15 FPS").tag(15)
                    Text("24 FPS").tag(24)
                    Text("30 FPS").tag(30)
                    Text("60 FPS").tag(60)
                }
                .pickerStyle(.menu)

                Picker("Max Width", selection: $settings.maxGIFWidth) {
                    Text("Small (640px)").tag(640)
                    Text("Medium (1080px)").tag(1080)
                    Text("Original / 4K (3840px)").tag(3840)
                }
                .pickerStyle(.menu)

                Toggle("Show Mouse Cursor", isOn: $settings.showCursor)
            }
            
            Section("Storage") {
                LabeledContent("Output Directory") {
                    HStack {
                        Text(settings.outputDirectory.path)
                            .truncationMode(.middle)
                            .lineLimit(1)
                            .help(settings.outputDirectory.path)
                        
                        Button("Choose...") {
                            chooseOutputDirectory()
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                settings.outputDirectory = url
            }
        }
    }
}
