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
    @AppStorage("appearance") private var appearance = 0

    private var colorScheme: ColorScheme? {
        switch appearance {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    var body: some View {
        Group {
            switch selected {
            case .checklist: ChecklistView(barCompact: $barCompact)
            case .todo: TodoView()
            case .routine: RoutineView(barCompact: $barCompact)
            case .account: AccountView(barCompact: $barCompact)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom) {
            FloatingTabBar(selected: $selected, compact: barCompact)
                .id(appearance)
        }
        .onChange(of: selected) {
            barCompact = false
        }
        .preferredColorScheme(colorScheme)
    }
}

struct FloatingTabBar: View {
    @Binding var selected: AppTab
    var compact: Bool

    @Namespace private var pillNS
    @State private var ticks: [AppTab: Int] = [:]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let isOn = selected == tab

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        selected = tab
                    }
                    ticks[tab, default: 0] += 1
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: compact ? 16 : 20, weight: isOn ? .semibold : .regular))
                            .symbolEffect(.bounce, value: ticks[tab, default: 0])
                            .scaleEffect(isOn ? 1.12 : 1.0)
                        if !compact {
                            Text(tab.rawValue)
                                .font(.caption2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, compact ? 8 : 10)
                    .foregroundStyle(isOn ? Color.accentColor : .secondary)
                    .background {
                        if isOn {
                            Capsule()
                                .fill(Color.accentColor.opacity(0.16))
                                .matchedGeometryEffect(id: "pill", in: pillNS)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassBarBackground()
        .padding(.horizontal, compact ? 80 : 24)
        .padding(.bottom, 4)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: compact)
        .sensoryFeedback(.selection, trigger: selected)
    }
}

// 유리 같은 바 배경: iOS 26 이상은 리퀴드 글래스, 그보다 낮으면 반투명 블러
extension View {
    @ViewBuilder
    func glassBarBackground() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
        }
    }
}

#Preview {
    ContentView()
}
