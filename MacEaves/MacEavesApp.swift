import SwiftUI
import TranscriptionKit

@main
struct MacEavesApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                SimpleTranscriptionView()
                    .tabItem {
                        Image(systemName: "waveform")
                        Text("Transcription")
                    }
                
                VUMeterView()
                    .tabItem {
                        Image(systemName: "chart.bar")
                        Text("Audio Monitor")
                    }
            }
        }
        .windowResizability(.contentSize)
    }
}
