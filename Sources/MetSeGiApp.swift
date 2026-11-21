import SwiftUI
import AVFoundation

@main
struct MetSeGiApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Self.activateVoiceAudioSession()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background || newPhase == .active {
                Self.activateVoiceAudioSession()
            }
        }
    }

    static func activateVoiceAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers]
            )
            try session.setActive(true)
        } catch {
            print("AudioSession error: \(error)")
        }
    }
}
