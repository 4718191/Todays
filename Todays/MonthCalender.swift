import SwiftUI

// MARK: - 펼쳐진 한 달 달력
struct MonthCalendar: View {
    @Binding var monthIndex: Int
    @Binding var selected: Date
    let routines: [Routine]
    let today: Date
    var onPick: () -> Void

    private var cal: Calendar { Calendar.current }

    private func thisMonthStart() -> Date {
        cal.dateInterval(of: .month, for: today)?.start ?? today
    }

    var body: some View {
        VStack(spacing: 8) {
            // 요일 줄
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { k in
                    Text(Routine.dayNames[(cal.firstWeekday - 1 + k) % 7])
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)

            // 달 단위 페이지 (좌우로 넘기기)
            TabView(selection: $monthIndex) {
                ForEach(-24...24, id: \.self) { off in
                    MonthGrid(
                        start: cal.date(byAdding: .month, value: off, to: thisMonthStart()) ?? today,
                        selected: $selected,
                        routines: routines,
                        today: today,
                        onPick: onPick
                    )
                    .tag(off)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 6 * 52)

            Text("점이 진하면 모두 완료, 연하면 일부 완료")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }
}

// MARK: - 한 달 날짜 칸
struct MonthGrid: View {
    let start: Date
    @Binding var selected: Date
    let routines: [Routine]
    let today: Date
    var onPick: () -> Void

    var body: some View {
        let cal = Calendar.current
        let daysInMonth = cal.range(of: .day, in: .month, for: start)?.count ?? 30
        let offset = (cal.component(.weekday, from: start) - cal.firstWeekday + 7) % 7

        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let number = row * 7 + col - offset + 1
                        if number >= 1 && number <= daysInMonth,
                           let day = cal.date(byAdding: .day, value: number - 1, to: start) {
                            cell(day, number)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func cell(_ day: Date, _ number: Int) -> some View {
        let cal = Calendar.current
        let isSelected = cal.isDate(day, inSameDayAs: selected)
        let isToday = cal.isDate(day, inSameDayAs: today)
        let status = progress(on: day)

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selected = cal.startOfDay(for: day)
            }
            onPick()
        } label: {
            VStack(spacing: 4) {
                Text("\(number)")
                    .font(.callout.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(isSelected ? Color.accentColor : Color.clear, in: Circle())
                    .overlay(
                        Circle().strokeBorder(
                            Color.accentColor,
                            lineWidth: (isToday && !isSelected) ? 1.5 : 0
                        )
                    )
                    .foregroundStyle(isSelected ? Color.white : Color.primary)

                Circle()
                    .fill(status == 0 ? Color.clear : Color.accentColor.opacity(status == 2 ? 1 : 0.4))
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.plain)
    }

    // 0 = 없음, 1 = 일부 완료, 2 = 모두 완료
    private func progress(on day: Date) -> Int {
        if day > today { return 0 }
        var total = 0
        var done = 0
        for r in routines where r.isScheduled(on: day) {
            total += 1
            if r.isDone(on: day) { done += 1 }
        }
        if total == 0 || done == 0 { return 0 }
        return done == total ? 2 : 1
    }
}
