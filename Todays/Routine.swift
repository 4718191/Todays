import SwiftUI

// 목표 종류: 횟수 또는 시간(분)
enum GoalKind: String, Codable, CaseIterable {
    case count, time

    var title: String { self == .count ? "횟수" : "시간" }
}

// 빈도: 일일 / 주간 / 월간 목표
enum Frequency: String, Codable, CaseIterable {
    case daily, weekly, monthly

    var title: String {
        switch self {
        case .daily: return "일일 목표"
        case .weekly: return "주간 목표"
        case .monthly: return "월간 목표"
        }
    }

    var shortPrefix: String {
        switch self {
        case .daily: return ""
        case .weekly: return "주 "
        case .monthly: return "월 "
        }
    }

    var streakUnit: String {
        switch self {
        case .daily: return "일"
        case .weekly: return "주"
        case .monthly: return "개월"
        }
    }
}

// MARK: - 루틴 데이터
struct Routine: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var days: [Int]                     // 1=일 2=월 ... 7=토 (일일 목표일 때만 사용)
    var doneDates: [String] = []        // 예전 방식의 완료 기록 (불러올 때 progress로 옮겨짐)
    var remindMinutes: Int? = nil       // 알림 시간 (0시부터 흐른 분)
    var createdKey: String? = nil       // 루틴을 만든 날
    var icon: String? = nil             // 아이콘 (SF Symbols 이름 또는 이모지)
    var colorName: String? = nil        // 색상 이름 (RoutineColor)
    var frequency: Frequency = .daily   // 일일/주간/월간
    var goalKind: GoalKind = .count     // 횟수/시간
    var goalValue: Int = 1              // 목표량 (횟수 또는 분)
    var progress: [String: Int] = [:]   // 날짜별 기록량 ("2026-10-04": 3)
    var allowExtra: Bool = false        // 목표를 넘겨서 더 기록할 수 있는지
    var tapStep: Int = 1                // 한 번 누를 때 늘어나는 양 (횟수 또는 분)
    var secondsBased: Bool = true       // 시간 목표·기록이 초 단위인지 (예전 데이터는 분 단위였음)
    var startOn: String? = nil          // 시작 날짜 ("2026-10-06"), 없으면 루틴을 만든 날
    var skipped: [String] = []          // 건너뛴 기간 (일일은 그 날, 주간은 그 주 첫날, 월간은 그 달 첫날)

    enum CodingKeys: String, CodingKey {
        case id, name, days, doneDates, remindMinutes, createdKey, icon, colorName
        case frequency, goalKind, goalValue, progress, allowExtra, tapStep, secondsBased, startOn, skipped
    }

    static let dayNames = ["일", "월", "화", "수", "목", "금", "토"]

    // 날짜 → "2026-10-04" 같은 글자
    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(for date: Date) -> String {
        keyFormatter.string(from: date)
    }
    
    // "2026-10-06" 글자 → 날짜
    static func date(fromKey key: String) -> Date? {
        keyFormatter.date(from: key)
    }

    // 목표량을 글자로: 3 → "3회", 330 → "5분 30초", 5400 → "1시간 30분" (시간은 초 단위 값)
    static func format(_ value: Int, kind: GoalKind) -> String {
        switch kind {
        case .count:
            return "\(value)회"
        case .time:
            let h = value / 3600
            let m = (value % 3600) / 60
            let s = value % 60
            var parts: [String] = []
            if h > 0 { parts.append("\(h)시간") }
            if m > 0 { parts.append("\(m)분") }
            if s > 0 || parts.isEmpty { parts.append("\(s)초") }
            return parts.joined(separator: " ")
        }
    }

    // 초를 시계 모양으로: 330 → "05:30", 3723 → "1:02:03"
    static func clock(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }
}

// 예전에 저장한 데이터도 문제없이 불러오도록 직접 읽는 부분
extension Routine {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        // 예전 방식("하루 한 번 체크")의 완료 날짜는 1회 달성으로 바꿔서 이어받음
        let legacy = try c.decodeIfPresent([String].self, forKey: .doneDates) ?? []
        var saved = try c.decodeIfPresent([String: Int].self, forKey: .progress) ?? [:]
        for d in legacy where saved[d] == nil {
            saved[d] = 1
        }

        let kind = try c.decodeIfPresent(GoalKind.self, forKey: .goalKind) ?? .count
        var goal = try c.decodeIfPresent(Int.self, forKey: .goalValue) ?? 1

        // 예전에는 시간을 분 단위로 저장했음 → 초 단위로 바꿔서 이어받음
        let alreadySeconds = try c.decodeIfPresent(Bool.self, forKey: .secondsBased) ?? false
        if kind == .time && !alreadySeconds {
            goal *= 60
            saved = saved.mapValues { $0 * 60 }
        }

        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try c.decode(String.self, forKey: .name)
        self.days = try c.decodeIfPresent([Int].self, forKey: .days) ?? Array(1...7)
        self.doneDates = []
        self.remindMinutes = try c.decodeIfPresent(Int.self, forKey: .remindMinutes)
        self.createdKey = try c.decodeIfPresent(String.self, forKey: .createdKey)
        self.icon = try c.decodeIfPresent(String.self, forKey: .icon)
        self.colorName = try c.decodeIfPresent(String.self, forKey: .colorName)
        self.frequency = try c.decodeIfPresent(Frequency.self, forKey: .frequency) ?? .daily
        self.goalKind = kind
        self.goalValue = goal
        self.progress = saved
        self.allowExtra = try c.decodeIfPresent(Bool.self, forKey: .allowExtra) ?? false
        self.tapStep = try c.decodeIfPresent(Int.self, forKey: .tapStep) ?? 1
        self.secondsBased = true
        self.startOn = try c.decodeIfPresent(String.self, forKey: .startOn)
        self.skipped = try c.decodeIfPresent([String].self, forKey: .skipped) ?? []
    }
}

// MARK: - 화면에 쓰는 계산들
extension Routine {
    var daysText: String {
        let sorted = days.sorted()
        if sorted.count == 7 { return "매일" }
        if sorted == [2, 3, 4, 5, 6] { return "평일" }
        if sorted == [1, 7] { return "주말" }
        return sorted.map { Routine.dayNames[$0 - 1] }.joined(separator: " ")
    }

    // 목록 줄 아래에 보이는 설명 (빈도 + 알림 시간)
    var subtitle: String {
        var parts: [String] = []
        switch frequency {
        case .daily: parts.append(daysText)
        case .weekly: parts.append("주간 목표")
        case .monthly: parts.append("월간 목표")
        }
        if let m = remindMinutes {
            parts.append(String(format: "%02d:%02d", m / 60, m % 60))
        }
        return parts.joined(separator: " · ")
    }

    // "매일 1회" 같은 가장 단순한 루틴인지 (이때는 진행 글자를 숨김)
    var isSimple: Bool {
        frequency == .daily && goalKind == .count && goalValue == 1
    }
    
    // 건너뛰기 기준이 되는 기간의 시작 날짜 글자
    func periodKey(containing date: Date) -> String {
        let cal = Calendar.current
        switch frequency {
        case .daily:
            return Routine.key(for: date)
        case .weekly:
            return Routine.key(for: cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date)
        case .monthly:
            return Routine.key(for: cal.dateInterval(of: .month, for: date)?.start ?? date)
        }
    }

    // 그 날(이 속한 기간)을 건너뛰었는지
    func isSkipped(on date: Date) -> Bool {
        skipped.contains(periodKey(containing: date))
    }

    // 그 날 목록에 나오는지 (시작 날짜 이후부터, 일일 목표는 고른 요일만)
    func appears(on date: Date) -> Bool {
        if Routine.key(for: date) < startKey { return false }
        if frequency == .daily {
            return days.contains(Calendar.current.component(.weekday, from: date))
        }
        return true
    }

    // "이 날 / 이 주 / 이 달"
    var skipText: String {
        switch frequency {
        case .daily: return "이 날"
        case .weekly: return "이 주"
        case .monthly: return "이 달"
        }
    }
    
    // 한 번 누를 때 실제로 늘어나는 양 (시간은 설정한 분을 초로 바꿈)
    var tapAmount: Int {
        goalKind == .time ? tapStep * 60 : tapStep
    }

    // 이 요일에 목록에 나오는지 (주간·월간 목표는 매일 나옴)
    func appears(onWeekday weekday: Int) -> Bool {
        frequency == .daily ? days.contains(weekday) : true
    }

    // 그 날 기록한 양
    func amount(on date: Date) -> Int {
        progress[Routine.key(for: date)] ?? 0
    }

    // 그 날이 속한 기간(일/주/월)의 기록 합계
    func periodAmount(containing date: Date) -> Int {
        let cal = Calendar.current
        switch frequency {
        case .daily:
            return amount(on: date)
        case .weekly:
            guard let start = cal.dateInterval(of: .weekOfYear, for: date)?.start else { return 0 }
            var total = 0
            for i in 0..<7 {
                if let d = cal.date(byAdding: .day, value: i, to: start) {
                    total += amount(on: d)
                }
            }
            return total
        case .monthly:
            guard let start = cal.dateInterval(of: .month, for: date)?.start,
                  let count = cal.range(of: .day, in: .month, for: date)?.count else { return 0 }
            var total = 0
            for i in 0..<count {
                if let d = cal.date(byAdding: .day, value: i, to: start) {
                    total += amount(on: d)
                }
            }
            return total
        }
    }

    func isComplete(on date: Date) -> Bool {
        periodAmount(containing: date) >= goalValue
    }

    // 0.0 ~ 1.0 진행률
    func ratio(on date: Date) -> Double {
        guard goalValue > 0 else { return 0 }
        return min(1, Double(periodAmount(containing: date)) / Double(goalValue))
    }

    // "2/8회", "주 1/3회", "30분/1시간"
    func progressText(on date: Date, withPrefix: Bool = true) -> String {
        let current = periodAmount(containing: date)
        let prefix = withPrefix ? frequency.shortPrefix : ""
        switch goalKind {
        case .count:
            return "\(prefix)\(current)/\(goalValue)회"
        case .time:
            return "\(prefix)\(Routine.format(current, kind: .time))/\(Routine.format(goalValue, kind: .time))"
        }
    }
    
    // 이 날에 더 추가해도 되는 양 (초과 기록을 허용하지 않으면 목표까지만)
    func room(on date: Date) -> Int {
        allowExtra ? Int.max : max(0, goalValue - periodAmount(containing: date))
    }
}
