import SwiftUI

enum AppTab: String, CaseIterable {
    case checklist = "체크리스트"
    case todo = "할 일"
    case routine = "루틴"
    case account = "계정"

    var icon: String {
        switch self {
        case .checklist: return "checklist"
        case .todo: return "list.bullet"
        case .routine: return "repeat"
        case .account: return "person.crop.circle"
        }
    }
}

struct ContentView: View {
    @State private var selected: AppTab = .checklist
    @State private var barCompact = false

    var body: some View {
        Group {
            switch selected {
            case .checklist: ChecklistView(barCompact: $barCompact)
            case .todo: TodoView()
            case .routine: RoutineView()
            case .account: AccountView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            FloatingTabBar(selected: $selected, compact: barCompact)
        }
        .onChange(of: selected) {
            barCompact = false
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selected: AppTab
    var compact: Bool

    var body: some View {
        HStack {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: compact ? 16 : 20))
                        if !compact {
                            Text(tab.rawValue)
                                .font(.caption2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selected == tab ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, compact ? 8 : 12)
        .padding(.horizontal, 8)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        .padding(.horizontal, compact ? 80 : 24)
        .padding(.bottom, 4)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: compact)
    }
}

#Preview {
    ContentView()
}
