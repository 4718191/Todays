import SwiftUI

// MARK: - 이 루틴만의 통계 계산
extension Routine {
    // 지금까지 가장 길게 이어 간 연속 달성 (일일은 일, 주간·월간은 기간 수)
    var bestStreak: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var best = 0
        var cur = 0

        if frequency == .daily {
            for i in stride(from: 730, through: 0, by: -1) {
                guard let d = cal.date(byAdding: .day, value: -i, to: today) else { continue }
                if Routine.key(for: d) < startKey { continue }
                if !isScheduled(on: d) { continue }
                if isDone(on: d) {
                    cur += 1
                    best = max(best, cur)
                } else if i == 0 {
                    continue
                } else {
                    cur = 0
                }
            }
        } else {
            let component: Calendar.Component = frequency == .weekly ? .weekOfYear : .month
            for k in stride(from: 120, through: 0, by: -1) {
                guard let d = cal.date(byAdding: component, value: -k, to: today),
                      let interval = cal.dateInterval(of: component, for: d) else { continue }
                if Routine.key(for: interval.end.addingTimeInterval(-1)) < startKey { continue }
                if isSkipped(on: d) { continue }
                if periodAmount(containing: d) >= goalValue {
                    cur += 1
                    best = max(best, cur)
                } else if k == 0 {
                    continue
                } else {
                    cur = 0
                }
            }
        }
        return best
    }

    // 지금까지 기록한 총량
    var totalAmount: Int {
        progress.values.reduce(0, +)
    }
}

// MARK: - 루틴 하나의 통계 화면
struct RoutineStatDetail: View {
    let routineID: UUID
    @Binding var routines: [Routine]

    private var routine: Routine? {
        routines.first { $0.id == routineID }
    }

    private var cal: Calendar { Calendar.current }

    var body: some View {
        ScrollView {
            if let r = routine {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        tile("현재 연속", "\(r.streakCount)\(r.frequency.streakUnit)")
                        tile("최장 연속", "\(r.bestStreak)\(r.frequency.streakUnit)")
                    }
                    HStack(spacing: 12) {
                        tile("누적 기록", Routine.format(r.totalAmount, kind: r.goalKind))
                        tile("기록한 날", "\(r.progress.count)일")
                    }
                    chartCard(r)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("\(routine?.name ?? "루틴") 통계")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .cardStyle()
    }

    // 최근 기록 막대 그래프
    private func chartCard(_ r: Routine) -> some View {
        let pts = points(r)
        let maxValue = max(r.goalValue, pts.map { $0.value }.max() ?? 0, 1)
        let title: String
        switch r.frequency {
        case .daily: title = "최근 7일"
        case .weekly: title = "최근 8주"
        case .monthly: title = "최근 6개월"
        }

        return VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(pts.enumerated()), id: \.offset) { _, p in
                    let ratio = Double(p.value) / Double(maxValue)
                    let met = p.value >= r.goalValue

                    VStack(spacing: 6) {
                        Text(shortValue(p.value, r))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)

                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(width: 22, height: 100)
                            Capsule()
                                .fill(met ? r.tint : r.tint.opacity(0.45))
                                .frame(width: 22, height: max(100 * ratio, p.value > 0 ? 6 : 0))
                        }

                        Text(p.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Text("목표 \(Routine.format(r.goalValue, kind: r.goalKind)) 이상이면 진한 색으로 보여요")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private func points(_ r: Routine) -> [(label: String, value: Int)] {
        let today = cal.startOfDay(for: Date())
        switch r.frequency {
        case .daily:
            return (0..<7).reversed().compactMap { i -> (label: String, value: Int)? in
                guard let d = cal.date(byAdding: .day, value: -i, to: today) else { return nil }
                let label = Routine.dayNames[cal.component(.weekday, from: d) - 1]
                return (label, r.amount(on: d))
            }
        case .weekly:
            return (0..<8).reversed().compactMap { k -> (label: String, value: Int)? in
                guard let d = cal.date(byAdding: .weekOfYear, value: -k, to: today) else { return nil }
                let label = k == 0 ? "이번 주" : "\(k)주 전"
                return (label, r.periodAmount(containing: d))
            }
        case .monthly:
            return (0..<6).reversed().compactMap { k -> (label: String, value: Int)? in
                guard let d = cal.date(byAdding: .month, value: -k, to: today) else { return nil }
                let label = "\(cal.component(.month, from: d))월"
                return (label, r.periodAmount(containing: d))
            }
        }
    }

    // 막대 위에 붙는 짧은 값
    private func shortValue(_ v: Int, _ r: Routine) -> String {
        if r.goalKind == .count { return "\(v)" }
        if v == 0 { return "0" }
        if v >= 3600 { return String(format: "%.1f시간", Double(v) / 3600) }
        if v >= 60 { return "\(v / 60)분" }
        return "\(v)초"
    }
}
