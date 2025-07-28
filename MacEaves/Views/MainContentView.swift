import SwiftUI

enum NavigationTool: String, CaseIterable {
    case transcription = "Transcription"
    case singleDevice = "Single Device"
    case allDevices = "All Devices"
    
    var icon: String {
        switch self {
        case .transcription:
            return "waveform"
        case .singleDevice:
            return "chart.bar"
        case .allDevices:
            return "chart.bar.fill"
        }
    }
    
    var description: String {
        switch self {
        case .transcription:
            return "Speech-to-text transcription"
        case .singleDevice:
            return "Single audio device VU meter"
        case .allDevices:
            return "Multi-device VU monitoring"
        }
    }
}

struct MainContentView: View {
    @State private var selectedTool: NavigationTool = .transcription
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(NavigationTool.allCases, id: \.self, selection: $selectedTool) { tool in
                NavigationLink(value: tool) {
                    HStack {
                        Image(systemName: tool.icon)
                            .foregroundColor(.accentColor)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tool.rawValue)
                                .font(.headline)
                            Text(tool.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("MacEaves")
            .navigationSplitViewColumnWidth(ideal: 250, max: 300)
        } detail: {
            // Main content area
            Group {
                switch selectedTool {
                case .transcription:
                    SimpleTranscriptionView()
                case .singleDevice:
                    VUMeterView()
                case .allDevices:
                    MultiDeviceVUMeterView()
                }
            }
            .navigationTitle(selectedTool.rawValue)
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

#Preview {
    MainContentView()
}
