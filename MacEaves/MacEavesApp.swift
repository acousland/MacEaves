import SwiftUI
import TranscriptionKit

@main
struct MacEavesApp: App {
    var body: some Scene {
        WindowGroup {
            SimpleTranscriptionView()
        }
        .windowResizability(.contentSize)
    }
}
