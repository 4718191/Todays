import SwiftUI

// MARK: - 통계 계산
extension Routine {
    // 이 루틴을 시작한 날 (정한 시작 날짜, 없으면 만든 날과 가장 이른 기록 중 빠른 쪽)
    var startKey: String {
        if let s = startOn { return s }
        let created = createdKey ?? Routine.key(for: Date())
        return min(created, progress.keys.min() ?? created)
    }

    // 일일 목표 루틴만: 그 날 해야 하는 날인지
    func isScheduled(on date: Date) -> Bool {
        guard frequency == .daily else { return false }
        if isSkipped(on: date) { return false }
        let weekday = Calendar.current.component(.weekday, from: date)
        return days.contains(weekday) && Routine.key(for: date) >= startKey
    }

    // 일일 목표 기준: 그 날 목표를 채웠는지
    func isDone(on date: Date) -> Bool {
        amount(on: date) >= goalValue
    }

    // 최근 n일 동안 해야 했던 횟수와 채운 횟수 (일일 목표)
    func recent(_ n: Int) -> (done: Int, total: Int) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var done = 0
        var total = 0
        for i in 0..<n {
            guard let d = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            if !isScheduled(on: d) { continue }
            total += 1
            if isDone(on: d) { done += 1 }
        }
        return (done, total)
    }

    // 일일 목표 연속 달성 일수: 해야 하는 날만 세고, 오늘 아직 안 했으면 끊지 않음
    var streak: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var count = 0
        for i in 0..<365 {
            guard let d = cal.date(byAdding: .day, value: -i, to: today) else { break }
            if Routine.key(for: d) < startKey { break }
            if !isScheduled(on: d) { continue }
            if isDone(on: d) {
                count += 1
            } else if i == 0 {
                continue
            } else {
                break
            }
        }
        return count
    }

    // 주간·월간 목표 연속 달성 기간 수 (이번 기간을 아직 못 채웠어도 끊지 않음)
    var periodStreak: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let component: Calendar.Component = frequency == .weekly ? .weekOfYear : .month
        var count = 0
        for k in 0..<120 {
            guard let d = cal.date(byAdding: component, value: -k, to: today),
                  let interval = cal.dateInterval(of: component, for: d) else { break }
            // 이 기간이 루틴을 시작하기 전에 끝났으면 중단
            if Routine.key(for: interval.end.addingTimeInterval(-1)) < startKey { break }
            if isSkipped(on: d) { continue }
            if periodAmount(containing: d) >= goalValue {
                count += 1
            } else if k == 0 {
                continue
            } else {
                break
            }
        }
        return count
    }

    // 빈도에 맞는 연속 기록
    var streakCount: Int {
        frequency == .daily ? streak : periodStreak
    }
}

// MARK: - 통계 화면
struct RoutineStatsView: View {
    let routines: [Routine]
    let weekStart: Date
    @Binding var barCompact: Bool

    private var cal: Calendar { Calendar.current }
    private var today: Date { cal.startOfDay(for: Date()) }

    var body: some View {
        if routines.isEmpty {
            VStack {
                Text("루틴을 만들면 통계가 보여요")
                    .foregroundStyle(.secondary)
                    .padding(.top, 40)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    summaryRow
                    weekCard
                    routineCard
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .shrinkBarOnScroll($barCompact)
        }
    }

    // MARK: 상단 두 칸
    private var summaryRow: some View {
        var done30 = 0
        var total30 = 0
        for r in routines {
            let rec = r.recent(30)
            done30 += rec.done
            total30 += rec.total
        }

        var doneWeek = 0
        var totalWeek = 0
        for i in 0..<7 {
            let d = day(i)
            if d > today { continue }
            let c = counts(on: d)
            doneWeek += c.done
            totalWeek += c.total
        }

        return HStack(spacing: 12) {
            tile("최근 30일 달성률", percent(done30, total30))
            tile("선택한 주 달성률", percent(doneWeek, totalWeek))
        }
    }

    private func tile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title.bold())
        }
        .cardStyle()
    }

    // MARK: 주간 달성 현황
    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("주간 달성 현황")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    let d = day(i)
                    let c = counts(on: d)
                    let isFuture = d > today
                    let progress: Double = (c.total == 0 || isFuture) ? 0 : Double(c.done) / Double(c.total)
                    let isToday = cal.isDate(d, inSameDayAs: today)

                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(width: 22, height: 90)
                            Capsule()
                                .fill(Color.accentColor)
                                .frame(width: 22, height: 90 * progress)
                        }
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)

                        Text(Routine.dayNames[cal.component(.weekday, from: d) - 1])
                            .font(.caption.weight(isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? Color.accentColor : Color.secondary)

                        Text(c.total == 0 ? "-" : "\(isFuture ? 0 : c.done)/\(c.total)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .cardStyle()
    }

    // MARK: 루틴별 현황
    // MARK: 루틴별 현황
    private var routineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("루틴별 현황")
                .font(.headline)

            ForEach(routines) { r in
                let isDaily = r.frequency == .daily
                let rec = r.recent(30)
                let rate: Double = isDaily
                    ? (rec.total == 0 ? 0 : Double(rec.done) / Double(rec.total))
                    : r.ratio(on: today)
                let streak = r.streakCount
                let periodName = r.frequency == .weekly ? "이번 주" : "이번 달"

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 8) {
                            RoutineIconView(name: r.icon, size: 26, color: r.tint)
                            Text(r.name)
                                .font(.subheadline.weight(.semibold))
                        }
                        Spacer()
                        Label("\(streak)\(r.frequency.streakUnit) 연속", systemImage: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(streak > 0 ? Color.orange : Color.secondary)
                    }
                    ProgressView(value: rate)
                        .tint(r.tint)
                    Text(isDaily
                         ? "최근 30일 \(percent(rec.done, rec.total)) (\(rec.done)/\(rec.total))"
                         : "\(periodName) \(r.progressText(on: today, withPrefix: false))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if r.id != routines.last?.id {
                    Divider()
                }
            }
        }
        .cardStyle()
    }

    // MARK: 도우미
    private func day(_ i: Int) -> Date {
        cal.date(byAdding: .day, value: i, to: weekStart) ?? weekStart
    }

    // 그 날 해야 하는 루틴 수와 한 루틴 수
    private func counts(on date: Date) -> (done: Int, total: Int) {
        var done = 0
        var total = 0
        for r in routines where r.isScheduled(on: date) {
            total += 1
            if r.isDone(on: date) { done += 1 }
        }
        return (done, total)
    }

    private func percent(_ done: Int, _ total: Int) -> String {
        if total == 0 { return "-" }
        return "\(Int((Double(done) / Double(total)) * 100))%"
    }
}

// 둥근 카드 모양
extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
