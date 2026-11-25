import SwiftUI
import WebKit
import UserNotifications
import UIKit

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

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(context.coordinator, name: "alarmBridge")

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

    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "alarmBridge",
                  let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }

            switch action {
            case "syncAlarm":
                let role = (body["role"] as? String) ?? "Anh"
                let wokeDate = (body["wokeDate"] as? String) ?? ""
                ScheduleNotificationManager.shared.updateRoleAndSync(role: role, wokeDate: wokeDate)
            case "confirmWakeUp":
                let role = (body["role"] as? String) ?? "Anh"
                let dateKey = (body["dateKey"] as? String) ?? ""
                ScheduleNotificationManager.shared.confirmWakeUp(role: role, dateKey: dateKey)
            case "testAlarm":
                let role = (body["role"] as? String) ?? ScheduleNotificationManager.shared.savedRole
                ScheduleNotificationManager.shared.scheduleTestAlarm(role: role)
            case "stopTestAlarm":
                ScheduleNotificationManager.shared.stopTestAlarm()
            default:
                break
            }
        }

        @available(iOS 15.0, *)
        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            AudioSessionManager.shared.activate()
            decisionHandler(.grant)
        }

        private func topViewController() -> UIViewController? {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            var top = windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            while let presented = top?.presentedViewController { top = presented }
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
    private let roleKey = "metsegi_saved_role"
    private let wokeDateKey = "metsegi_woke_date"
    private var cachedTKB: RemoteTKB?

    var savedRole: String {
        get { UserDefaults.standard.string(forKey: roleKey) ?? "Anh" }
        set { UserDefaults.standard.set(newValue, forKey: roleKey) }
    }

    var savedWokeDate: String {
        get { UserDefaults.standard.string(forKey: wokeDateKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: wokeDateKey) }
    }

    private let defaultTKB = RemoteTKB(
        anh: PersonTKB(
            name: "Mai Xuân Anh",
            days: [
                "1": [],
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
                "7": []
            ]
        ),
        em: PersonTKB(
            name: "Trần Phương Em",
            days: [
                "1": [],
                "2": [
                    "Tiết 2: 特講42 営業コミュニケーション",
                    "Tiết 3: 災害と防災",
                    "Tiết 4: アルゴリズム論"
                ],
                "3": [
                    "Tiết 1: 日本語口頭表現",
                    "Tiết 2: 生活と経済",
                    "Tiết 3: 会計基礎II",
                    "Tiết 4: データサイエンス"
                ],
                "4": [
                    "Tiết 2: フレッシュマンセミナー",
                    "Tiết 3: トレーニング演習",
                    "Tiết 4: 事業計画論"
                ],
                "5": [
                    "Tiết 1: キャリアデザインI",
                    "Tiết 2: 日本語文章表現",
                    "Tiết 4: マーケティング基礎II"
                ],
                "6": [],
                "7": []
            ]
        )
    )

    func setupAndSchedule() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted { self.fetchTKBAndSchedule() }
        }
    }

    func updateRoleAndSync(role: String, wokeDate: String) {
        savedRole = role
        if !wokeDate.isEmpty { savedWokeDate = wokeDate }
        if let tkb = cachedTKB {
            scheduleAll(tkb: tkb)
        } else {
            fetchTKBAndSchedule()
        }
    }

    func confirmWakeUp(role: String, dateKey: String) {
        savedRole = role
        savedWokeDate = dateKey
        clearDeliveredAlarms()
        scheduleAll(tkb: cachedTKB ?? defaultTKB)
    }

    func scheduleTestAlarm(role: String) {
        stopTestAlarm()
        let center = UNUserNotificationCenter.current()
        let person = role == "Anh" ? (cachedTKB ?? defaultTKB).anh : (cachedTKB ?? defaultTKB).em
        let offsets: [TimeInterval] = [8, 13, 18, 23, 28, 33]
        for (i, sec) in offsets.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "⏰ Báo thức thử (\(person.name))"
            content.body = "Mở app bấm nút 'Đã dậy !' ở giữa màn hình để tắt chuông."
            content.sound = .default
            if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: sec, repeats: false)
            center.add(UNNotificationRequest(identifier: "test-alarm-\(i)", content: content, trigger: trigger))
        }
    }

    func stopTestAlarm() {
        let center = UNUserNotificationCenter.current()
        let ids = (0..<10).map { "test-alarm-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    private func clearDeliveredAlarms() {
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { notes in
            let ids = notes.map { $0.request.identifier }.filter { $0.hasPrefix("alarm-") || $0.hasPrefix("test-alarm-") }
            if !ids.isEmpty { center.removeDeliveredNotifications(withIdentifiers: ids) }
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
            cachedTKB = defaultTKB
            scheduleAll(tkb: defaultTKB)
            return
        }
        let req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        URLSession.shared.dataTask(with: req) { data, _, error in
            if let data = data, error == nil,
               let tkb = try? JSONDecoder().decode(RemoteTKB.self, from: data) {
                self.cachedTKB = tkb
                self.scheduleAll(tkb: tkb)
            } else {
                self.cachedTKB = self.defaultTKB
                self.scheduleAll(tkb: self.defaultTKB)
            }
        }.resume()
    }

    private func dateKey(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    private func periodOneItem(for person: PersonTKB, dayKey: String) -> String? {
        let list = person.days[dayKey] ?? []
        return list.first { item in
            let t = item.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.hasPrefix("Tiết 1 ") || t.hasPrefix("Tiết 1:") || t.hasPrefix("Tiết 1(") || t == "Tiết 1"
        }
    }

    private func scheduleAll(tkb: RemoteTKB) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let toRemove = pending.map { $0.identifier }.filter { $0.hasPrefix("tkb-") || $0.hasPrefix("alarm-") }
            center.removePendingNotificationRequests(withIdentifiers: toRemove)

            let calendar = Calendar.current
            let now = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "dd/MM/yyyy"
            let weekdayNames = [1: "Chủ Nhật", 2: "Thứ 2", 3: "Thứ 3", 4: "Thứ 4", 5: "Thứ 5", 6: "Thứ 6", 7: "Thứ 7"]

            // 1. Nhắc lịch học 23:00 cho 10 ngày tới (10 slots)
            for offset in 0..<10 {
                guard let targetDay = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
                var comps = calendar.dateComponents([.year, .month, .day], from: targetDay)
                comps.hour = 23; comps.minute = 0; comps.second = 0

                guard let fireDate = calendar.date(from: comps), fireDate > now,
                      let tomorrow = calendar.date(byAdding: .day, value: 1, to: fireDate) else { continue }

                let weekday = calendar.component(.weekday, from: tomorrow)
                let dayKey = String(weekday)
                let dayName = weekdayNames[weekday] ?? ""
                let dateStr = formatter.string(from: tomorrow)

                let anhList = tkb.anh.days[dayKey] ?? []
                let emList = tkb.em.days[dayKey] ?? []

                var lines = ["👤 \(tkb.anh.name): Có \(anhList.count) tiết"]
                anhList.forEach { lines.append("• \($0)") }
                lines.append("")
                lines.append("👤 \(tkb.em.name): Có \(emList.count) tiết")
                emList.forEach { lines.append("• \($0)") }

                let content = UNMutableNotificationContent()
                content.title = "📅 Lịch học ngày mai (\(dayName), \(dateStr))"
                content.body = lines.joined(separator: "\n")
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                center.add(UNNotificationRequest(identifier: "tkb-\(dateStr)", content: content, trigger: trigger))
            }

            // 2. Báo thức sáng tiết 1 theo đúng tư cách máy này (Anh 08:10, Em 08:30)
            let role = self.savedRole
            let person = (role == "Anh") ? tkb.anh : tkb.em
            let alarmHour = (role == "Anh") ? 8 : 8
            let alarmMinute = (role == "Anh") ? 10 : 30
            let wokeKey = self.savedWokeDate

            var alarmDaysScheduled = 0
            for offset in 0..<14 {
                if alarmDaysScheduled >= 2 { break }
                guard let targetDay = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
                let dKey = self.dateKey(for: targetDay, calendar: calendar)
                if dKey == wokeKey { continue }

                let weekday = calendar.component(.weekday, from: targetDay)
                guard let firstClass = self.periodOneItem(for: person, dayKey: String(weekday)) else { continue }

                var startComps = calendar.dateComponents([.year, .month, .day], from: targetDay)
                startComps.hour = alarmHour
                startComps.minute = alarmMinute
                startComps.second = 0
                guard var baseDate = calendar.date(from: startComps) else { continue }

                if offset == 0 {
                    var cutoffComps = calendar.dateComponents([.year, .month, .day], from: targetDay)
                    cutoffComps.hour = 11; cutoffComps.minute = 30; cutoffComps.second = 0
                    if let cutoff = calendar.date(from: cutoffComps), now >= cutoff { continue }
                    if now > baseDate { baseDate = now.addingTimeInterval(5) }
                }

                // Ngày gần nhất: 42 chuông liên tiếp (~10.5 phút); ngày kế tiếp: 8 chuông dự phòng
                let secondsList: [TimeInterval]
                if alarmDaysScheduled == 0 {
                    let phase1 = (0..<20).map { TimeInterval($0 * 10) }
                    let phase2 = (1...22).map { TimeInterval(190 + $0 * 20) }
                    secondsList = phase1 + phase2
                } else {
                    secondsList = (0..<8).map { TimeInterval($0 * 30) }
                }

                for (idx, delta) in secondsList.enumerated() {
                    let fire = baseDate.addingTimeInterval(delta)
                    if fire <= now { continue }
                    let fireComps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fire)
                    let content = UNMutableNotificationContent()
                    content.title = "⏰ Dậy đi học tiết 1 thôi! (\(person.name))"
                    content.body = "\(firstClass)\nMở app bấm 'Đã dậy !' để tắt chuông."
                    content.sound = .default
                    if #available(iOS 15.0, *) { content.interruptionLevel = .timeSensitive }
                    let trigger = UNCalendarNotificationTrigger(dateMatching: fireComps, repeats: false)
                    center.add(UNNotificationRequest(identifier: "alarm-\(dKey)-\(idx)", content: content, trigger: trigger))
                }
                alarmDaysScheduled += 1
            }
        }
    }
}
