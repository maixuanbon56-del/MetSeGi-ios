import SwiftUI
import AVFoundation
import UIKit

final class AudioSessionManager {
    static let shared = AudioSessionManager()

    func activate() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers]
            )
            try session.setActive(true)
        } catch {
            print("AudioSession error:", error)
        }
    }

    func startObserving() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo,
                  let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw),
                  type == .ended else { return }
            self?.activate()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.activate()
        }
    }
}

@main
struct MetSeGiApp: App {
    init() {
        AudioSessionManager.shared.activate()
        AudioSessionManager.shared.startObserving()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
