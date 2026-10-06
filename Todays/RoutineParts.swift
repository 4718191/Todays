import SwiftUI

// MARK: - 한 주 날짜 줄
struct WeekRow: View {
    let start: Date
    @Binding var selected: Date
    let today: Date

    var body: some View {
        let cal = Calendar.current
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                let day = cal.date(byAdding: .day, value: i, to: start) ?? start
                let isSelected = cal.isDate(day, inSameDayAs: selected)
                let isToday = cal.isDate(day, inSameDayAs: today)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selected = cal.startOfDay(for: day)
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(Routine.dayNames[cal.component(.weekday, from: day) - 1])
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(cal.component(.day, from: day))")
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
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - 루틴 아이콘 (둥근 사각형 안의 그림)
struct RoutineIconView: View {
    let name: String?
    var size: CGFloat = 32
    var color: Color = .accentColor

    var body: some View {
        if let name {
            Group {
                if IconCatalog.isSymbol(name) {
                    Image(systemName: name)
                        .font(.system(size: size * 0.5, weight: .semibold))
                        .foregroundStyle(color)
                } else {
                    Text(name)
                        .font(.system(size: size * 0.55))
                }
            }
            .frame(width: size, height: size)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: size * 0.3))
        }
    }
}

// MARK: - 루틴 색상
enum RoutineColor: String, CaseIterable {
    case red, orange, yellow, green, mint, blue, purple, pink

    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .mint: return .mint
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        }
    }
}

extension Routine {
    // 이 루틴의 색 (고르지 않았으면 앱 기본 색)
    var tint: Color {
        RoutineColor(rawValue: colorName ?? "")?.color ?? .accentColor
    }
}
