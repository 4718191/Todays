import Foundation
import UserNotifications

enum NotificationManager {
    // 알림 권한 요청 (처음 한 번만 팝업이 떠요)
    static func requestPermission(_ completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // 루틴 목록에 맞춰 알림을 전부 새로 등록
    static func sync(_ routines: [Routine]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        // 계정 화면의 전체 스위치가 꺼져 있으면 등록하지 않음
        guard UserDefaults.standard.bool(forKey: "notifyOn") else { return }

        for r in routines {
            guard let minutes = r.remindMinutes else { continue }
            for day in (r.frequency == .daily ? r.days : Array(1...7)) {
                let content = UNMutableNotificationContent()
                content.title = r.name
                content.body = "오늘의 루틴을 할 시간이에요"
                content.sound = .default

                var comps = DateComponents()
                comps.weekday = day
                comps.hour = minutes / 60
                comps.minute = minutes % 60

                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "routine-\(r.id.uuidString)-\(day)",
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        }
    }

    // 저장된 루틴을 읽어서 등록 (계정 화면에서 스위치를 바꿀 때 사용)
    static func syncFromStorage() {
        let text = UserDefaults.standard.string(forKey: "routines") ?? "[]"
        if let data = text.data(using: .utf8),
           let items = try? JSONDecoder().decode([Routine].self, from: data) {
            sync(items)
        }
    }
}
