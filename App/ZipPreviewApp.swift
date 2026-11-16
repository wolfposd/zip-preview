import SwiftUI

@main
struct ZipPreviewApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(alignment: .leading, spacing: 12) {
                Text("Archive Preview is installed")
                    .font(.title2.bold())
                Text("Select a .zip, .tar.gz, .7z, .rar or other archive in Finder and press Space to see its contents.")
                Text("If the default preview still appears, enable “Archive Preview” in System Settings ▸ General ▸ Login Items & Extensions ▸ Quick Look, then run `qlmanage -r` in Terminal.")
                    .foregroundStyle(.secondary)
                Button("Open Extension Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            .padding(24)
            .frame(width: 460)
        }
        .windowResizability(.contentSize)
    }
}
