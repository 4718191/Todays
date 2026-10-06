import SwiftUI

struct RoutineEditor: View {
    @State var routine: Routine
    var isNew: Bool
    var onSave: (Routine) -> Void
    var onDelete: () -> Void

    @AppStorage("notifyOn") private var notifyOn = false
    @State private var showDenied = false
    @State private var showMore = false
    @Environment(\.dismiss) private var dismiss

    private var canSave: Bool {
        let hasName = !routine.name.trimmingCharacters(in: .whitespaces).isEmpty
        let hasDays = routine.frequency != .daily || !routine.days.isEmpty
        return hasName && hasDays
    }

    // 목표 입력 범위와 간격
    private var goalRange: ClosedRange<Int> {
        routine.goalKind == .count ? 1...999 : 5...1440
    }

    private var goalStep: Int {
        routine.goalKind == .count ? 1 : 5
    }
    
    // 시작 날짜 선택기와 연결 (정하지 않았으면 루틴을 만든 날, 새 루틴이면 오늘)
    private var startBinding: Binding<Date> {
        Binding(
            get: {
                let key = routine.startOn ?? routine.createdKey ?? Routine.key(for: Date())
                return Routine.date(fromKey: key) ?? Date()
            },
            set: { date in
                routine.startOn = Routine.key(for: date)
            }
        )
    }
    
    // 탭 한 번에 늘어나는 양의 범위와 설명
    private var tapRange: ClosedRange<Int> {
        routine.goalKind == .count ? 1...99 : 1...60
    }

    private var tapTitle: String {
        routine.goalKind == .count
            ? "한 번 누를 때마다 +\(routine.tapStep)회"
            : "시간을 누를 때마다 +\(routine.tapStep)분"
    }
    
    // 시간 목표는 분으로 보여 주고 초로 저장
    private var goalBinding: Binding<Int> {
        Binding(
            get: { routine.goalKind == .time ? routine.goalValue / 60 : routine.goalValue },
            set: { routine.goalValue = routine.goalKind == .time ? $0 * 60 : $0 }
        )
    }

    private var goalTitle: String {
        switch routine.frequency {
        case .daily: return "나의 일일 목표"
        case .weekly: return "나의 주간 목표"
        case .monthly: return "나의 월간 목표"
        }
    }

    // 알림 시간 선택기와 연결
    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                let m = routine.remindMinutes ?? 540
                return Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                routine.remindMinutes = (c.hour ?? 9) * 60 + (c.minute ?? 0)
            }
        )
    }

    // 알림 스위치: 켤 때 권한을 확인
    private var remindBinding: Binding<Bool> {
        Binding(
            get: { routine.remindMinutes != nil },
            set: { on in
                if on {
                    NotificationManager.requestPermission { granted in
                        if granted {
                            notifyOn = true
                            if routine.remindMinutes == nil {
                                routine.remindMinutes = 9 * 60
                            }
                        } else {
                            showDenied = true
                        }
                    }
                } else {
                    routine.remindMinutes = nil
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                // 1. 이름 + 아이콘
                Section {
                    TextField("이름", text: $routine.name)

                    NavigationLink {
                        AppearanceScreen(icon: $routine.icon, colorName: $routine.colorName)
                    } label: {
                        HStack {
                            Text("아이콘")
                            Spacer()
                            if routine.icon != nil {
                                RoutineIconView(name: routine.icon, size: 30, color: routine.tint)
                            } else {
                                Circle()
                                    .fill(routine.tint)
                                    .frame(width: 22, height: 22)
                            }
                        }
                    }
                }

                // 2. 빈도 설정
                Section("빈도 설정") {
                    Picker("빈도", selection: $routine.frequency) {
                        ForEach(Frequency.allCases, id: \.self) { f in
                            Text(f.title).tag(f)
                        }
                    }

                    // 일일 목표일 때만 반복 요일 선택
                    if routine.frequency == .daily {
                        HStack(spacing: 8) {
                            ForEach(1...7, id: \.self) { d in
                                let on = routine.days.contains(d)
                                Button {
                                    if on {
                                        routine.days.removeAll { $0 == d }
                                    } else {
                                        routine.days.append(d)
                                    }
                                } label: {
                                    Text(Routine.dayNames[d - 1])
                                        .font(.subheadline.bold())
                                        .frame(width: 38, height: 38)
                                        .background(on ? Color.accentColor : Color.secondary.opacity(0.15), in: Circle())
                                        .foregroundStyle(on ? Color.white : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // 3. 알림 설정
                Section("알림 설정") {
                    Toggle("알림 받기", isOn: remindBinding)
                    if routine.remindMinutes != nil {
                        DatePicker("시간", selection: timeBinding, displayedComponents: .hourAndMinute)
                    }
                }

                // 4. 횟수 또는 시간 목표
                Section {
                    Picker("단위", selection: $routine.goalKind) {
                        ForEach(GoalKind.allCases, id: \.self) { k in
                            Text(k.title).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)

                    Stepper(value: goalBinding, in: goalRange, step: goalStep) {
                        Text(Routine.format(routine.goalValue, kind: routine.goalKind))
                            .font(.title3.bold())
                    }

                    // 더 보기: 추가 설정
                    if showMore {
                        Toggle("목표 초과 기록 허용", isOn: $routine.allowExtra)
                        Stepper(value: $routine.tapStep, in: tapRange) {
                            Text(tapTitle)
                        }
                        DatePicker("시작 날짜", selection: startBinding, displayedComponents: .date)
                    }
                } header: {
                    HStack {
                        Text(goalTitle)
                        Spacer()
                        Button(showMore ? "접기" : "더 보기") {
                            withAnimation {
                                showMore.toggle()
                            }
                        }
                        .font(.footnote)
                    }
                    .textCase(nil)
                } footer: {
                    if showMore {
                        Text("초과 기록을 끄면 목표까지만 기록돼요. 시간 목표는 동그라미를 누를 때마다 설정한 분만큼 늘어나고, 타이머는 루틴 이름을 눌러 열리는 상세 화면에서 쓸 수 있어요. 시작 날짜 전에는 목록에 나오지 않아요.")
                    }
                }

                if !isNew {
                    Section {
                        Button("루틴 삭제", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .onChange(of: routine.goalKind) {
                // 횟수 ↔ 시간을 바꾸면 기본 목표로 되돌림
                routine.goalValue = routine.goalKind == .count ? 1 : 30 * 60
                routine.tapStep = 1
            }
            .navigationTitle(isNew ? "새 루틴" : "루틴 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        var r = routine
                        r.name = r.name.trimmingCharacters(in: .whitespaces)
                        onSave(r)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .alert("알림이 꺼져 있어요", isPresented: $showDenied) {
                Button("확인", role: .cancel) {}
            } message: {
                Text("iPhone 설정에서 이 앱의 알림을 허용해 주세요.")
            }
        }
    }
}
