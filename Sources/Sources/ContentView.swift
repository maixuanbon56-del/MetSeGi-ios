import SwiftUI
import WebKit
import UserNotifications

struct ContentView: View {
    private let appURL = "https://maixuanbon56-del.github.io/M-t-s-gi/"

    var body: some View {
        ChatWebView(urlString: appURL)
            .ignoresSafeArea()
            .onAppear {
                ScheduleNotificationManager.shared.setupAndSchedule()
            }
    }
}

struct ChatWebView: UIViewRepresentable {
    let urlString: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .white

        if let url = URL(string: urlString) {
            let request = URLRequest(
                url: url,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: 30
            )
            webView.load(request)
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        @available(iOS 15.0, *)
        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            MetSeGiApp.activateVoiceAudioSession()
            decisionHandler(.grant)
        }

        private func topViewController() -> UIViewController? {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            var top = windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            while let presented = top?.presentedViewController {
                top = presented
            }
            return top
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: "Mét sê gi", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
            if let vc = topViewController() { vc.present(alert, animated: true) } else { completionHandler() }
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = UIAlertController(title: "Xác nhận", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "Đồng ý", style: .destructive) { _ in completionHandler(true) })
            if let vc = topViewController() { vc.present(alert, animated: true) } else { completionHandler(false) }
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            let alert = UIAlertController(title: prompt, message: nil, preferredStyle: .alert)
            alert.addTextField { $0.text = defaultText }
            alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in completionHandler(nil) })
            alert.addAction(UIAlertAction(title: "Lưu", style: .default) { _ in
                completionHandler(alert.textFields?.first?.text)
            })
            if let vc = topViewController() { vc.present(alert, animated: true) } else { completionHandler(nil) }
        }
    }
}

struct RemoteTKB: Codable {
    let anh: PersonTKB
    let em: PersonTKB
}

struct PersonTKB: Codable {
    let name: String
    let days: [String: [String]]
}

class ScheduleNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ScheduleNotificationManager()
    private let tkbURLString = "https://maixuanbon56-del.github.io/M-t-s-gi/tkb.json"

    private let defaultTKB = RemoteTKB(
        anh: PersonTKB(
            name: "Mai Xuân Anh",
            days: [
                "2": [
                    "Tiết 1 (09:20–10:50): CAD実習II (Phòng 241)",
                    "Tiết 2 (11:00–12:30): CAD実習II (Phòng 241)",
                    "Tiết 3 (13:20–14:50): CD系ゼミII (Phòng 311)",
                    "Tiết 4 (15:00–16:30): 業界研究I (Phòng 311)"
                ],
                "3": [
                    "Tiết 1 (09:20–10:50): グラフィックデザインB (Phòng 311)",
                    "Tiết 2 (11:00–12:30): グラフィックデザインB (Phòng 311)",
                    "Tiết 3 (13:20–14:50): MOS Word B (Phòng 261)",
                    "Tiết 4 (15:00–16:30): Unity開発実習B (Phòng 341)"
                ],
                "4": [
                    "Tiết 1 (09:20–10:50): Photoshop II (Phòng 343)",
                    "Tiết 2 (11:00–12:30): Photoshop II (Phòng 343)",
                    "Tiết 3 (13:20–14:50): C#実習基礎B (Phòng 262)",
                    "Tiết 4 (15:00–16:30): C#実習基礎B (Phòng 262)"
                ],
                "5": [
                    "Tiết 1 (09:20–10:50): Illustrator II (Phòng 343)",
                    "Tiết 2 (11:00–12:30): Illustrator II (Phòng 343)",
                    "Tiết 3 (13:20–14:50): CD系ゼミII (Phòng 311)",
                    "Tiết 4 (15:00–16:30): 商業デザインI (Phòng 311)"
                ],
                "6": [
                    "Tiết 3 (13:20–14:50): CD系ゼミII (Phòng 311)"
                ],
                "7": [],
                "1": []
            ]
        ),
        em: PersonTKB(
            name: "Trần Phương Em",
            days: ["1": [], "2": [], "3": [], "4": [], "5": [], "6": [], "7": []]
        )
    )

    func setupAndSchedule() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted { self.fetchTKBAndSchedule() }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private func fetchTKBAndSchedule() {
        guard let url = URL(string: "\(tkbURLString)?t=\(Int(Date().timeIntervalSince1970))") else {
            self.scheduleNext30Days(tkb: self.defaultTKB)
            return
        }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let data = data, error == nil,
               let tkb = try? JSONDecoder().decode(RemoteTKB.self, from: data) {
                self.scheduleNext30Days(tkb: tkb)
            } else {
                self.scheduleNext30Days(tkb: self.defaultTKB)
            }
        }.resume()
    }

    private func scheduleNext30Days(tkb: RemoteTKB) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        let weekdayNames = [1: "Chủ Nhật", 2: "Thứ 2", 3: "Thứ 3", 4: "Thứ 4", 5: "Thứ 5", 6: "Thứ 6", 7: "Thứ 7"]

        for offset in 0..<30 {
            guard let targetDay = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            var triggerComps = calendar.dateComponents([.year, .month, .day], from: targetDay)
            triggerComps.hour = 23
            triggerComps.minute = 0
            triggerComps.second = 0

            guard let fireDate = calendar.date(from: triggerComps), fireDate > now,
                  let tomorrow = calendar.date(byAdding: .day, value: 1, to: fireDate) else { continue }

            let weekday = calendar.component(.weekday, from: tomorrow)
            let dayKey = String(weekday)
            let dayName = weekdayNames[weekday] ?? ""
            let dateStr = formatter.string(from: tomorrow)

            let anhList = tkb.anh.days[dayKey] ?? []
            let emList = tkb.em.days[dayKey] ?? []

            var lines: [String] = []
            lines.append("👤 \(tkb.anh.name): Có \(anhList.count) tiết")
            anhList.forEach { lines.append("• \($0)") }
            lines.append("")
            lines.append("👤 \(tkb.em.name): Có \(emList.count) tiết")
            emList.forEach { lines.append("• \($0)") }

            let content = UNMutableNotificationContent()
            content.title = "📅 Lịch học ngày mai (\(dayName), \(dateStr))"
            content.body = lines.joined(separator: "\n")
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)
            center.add(UNNotificationRequest(identifier: "tkb-\(dateStr)", content: content, trigger: trigger))
        }
    }
}
