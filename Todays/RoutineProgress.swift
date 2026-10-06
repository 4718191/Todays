import SwiftUI

// MARK: - 진행률 동그라미 (상세 화면에서 쓰는 단순한 링)
struct ProgressRing: View {
    let progress: Double
    let color: Color
    var size: CGFloat = 26
    var lineWidth: CGFloat = 3
    var showsCheck: Bool = true

    var body: some View {
        ZStack {
            if progress >= 1 && showsCheck {
                Circle().fill(color)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle()
                    .stroke(Color.secondary.opacity(0.25), lineWidth: lineWidth)
                if progress > 0 {
                    Circle()
                        .trim(from: 0, to: min(progress, 1))
                        .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
            }
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.25), value: progress)
    }
}

// MARK: - 목록의 큰 동그라미 (안에 횟수/시간 표시)
struct RoutineRing: View {
    let routine: Routine
    let date: Date
    var size: CGFloat = 56

    private var current: Int { routine.periodAmount(containing: date) }

    // 횟수는 "2회", 시간은 "05:30"
    private var currentLabel: String {
        routine.goalKind == .count ? "\(current)회" : Routine.clock(current)
    }

    private var goalLabel: String {
        routine.goalKind == .count ? "\(routine.goalValue)회" : Routine.clock(routine.goalValue)
    }

    var body: some View {
        let ratio = routine.ratio(on: date)
        let complete = routine.isComplete(on: date)
        let tint = routine.tint

        ZStack {
            if routine.isSkipped(on: date) {
                // 건너뛴 기간: 점선 동그라미
                Circle()
                    .strokeBorder(
                        Color.secondary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 2, dash: [4, 4])
                    )
                Text("건너뜀")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                Circle()
                    .fill(complete ? tint.opacity(0.15) : Color.clear)
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 5)
                if ratio > 0 {
                    Circle()
                        .trim(from: 0, to: ratio)
                        .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                VStack(spacing: 0) {
                    Text(currentLabel)
                        .font(.system(size: routine.goalKind == .count ? 15 : 13, weight: .bold).monospacedDigit())
                        .foregroundStyle(complete ? tint : Color.primary)
                    Text("/" + goalLabel)
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 7)
            }
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.25), value: ratio)
    }
}

// MARK: - 루틴 상세 화면 (기록 창)
struct ProgressSheet: View {
    let routineID: UUID
    @Binding var routines: [Routine]
    let date: Date
    @Environment(\.dismiss) private var dismiss
    @State private var timerStart: Date? = nil
    @State private var showEditor = false
    @State private var showReset = false

    private var index: Int? {
        routines.firstIndex { $0.id == routineID }
    }

    var body: some View {
        NavigationStack {
            if let i = index {
                detail(routines[i], i)
            } else {
                // 편집 화면에서 루틴을 삭제하면 이 화면도 닫음
                Color.clear
                    .onAppear {
                        dismiss()
                    }
            }
        }
    }

    @ViewBuilder
    private func detail(_ r: Routine, _ i: Int) -> some View {
        let skipped = r.isSkipped(on: date)

        VStack(spacing: 24) {
            Spacer(minLength: 0)

            if skipped {
                skippedBody(r, i)
            } else if r.goalKind == .time {
                timeBody(r, i)
            } else {
                countBody(r, i)
            }

            Spacer(minLength: 0)

            // 타이머가 돌아가는 동안에는 숨김
            if timerStart == nil {
                bottomButtons(r, i, skipped: skipped)
            }
        }
        .padding(24)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    RoutineIconView(name: r.icon, size: 26, color: r.tint)
                    Text(r.name)
                        .font(.headline)
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                // 이 루틴의 통계
                NavigationLink {
                    RoutineStatDetail(routineID: routineID, routines: $routines)
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                }
                .disabled(timerStart != nil)

                // 루틴 편집
                Button {
                    showEditor = true
                } label: {
                    Image(systemName: "pencil")
                }
                .disabled(timerStart != nil)
            }
        }
        .confirmationDialog("이 날 기록을 초기화할까요?", isPresented: $showReset, titleVisibility: .visible) {
            Button("초기화", role: .destructive) {
                clear(at: i)
            }
            Button("취소", role: .cancel) {}
        }
        .sheet(isPresented: $showEditor) {
            if let k = index {
                RoutineEditor(
                    routine: routines[k],
                    isNew: false,
                    onSave: { saved in
                        if let j = routines.firstIndex(where: { $0.id == routineID }) {
                            routines[j] = saved
                        }
                    },
                    onDelete: {
                        routines.removeAll { $0.id == routineID }
                    }
                )
            }
        }
        .onDisappear {
            // 타이머를 켠 채로 창을 닫아도 지금까지의 시간은 기록
            if let k = index {
                stopTimer(at: k, save: true)
            }
        }
    }

    @ViewBuilder
    private func bottomButtons(_ r: Routine, _ i: Int, skipped: Bool) -> some View {
        if !skipped {
            HStack(spacing: 10) {
                Button("목표 달성") {
                    fill(at: i)
                }
                .buttonStyle(.bordered)

                Button("초기화", role: .destructive) {
                    showReset = true
                }
                .buttonStyle(.bordered)
            }

            Button {
                toggleSkip(at: i)
            } label: {
                Label("\(r.skipText) 건너뛰기", systemImage: "forward.end.fill")
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }

        Button("완료") {
            dismiss()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    // MARK: 건너뛴 상태
    @ViewBuilder
    private func skippedBody(_ r: Routine, _ i: Int) -> some View {
        ZStack {
            Circle()
                .strokeBorder(
                    Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 6, dash: [10, 10])
                )
                .frame(width: 240, height: 240)

            VStack(spacing: 8) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)
                Text("건너뜀")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("건너뛴 기간은 통계에서 제외돼요")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }

        Button {
            toggleSkip(at: i)
        } label: {
            Label("건너뛰기 취소", systemImage: "arrow.uturn.backward")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(r.tint)
    }

    // MARK: 횟수 목표
    @ViewBuilder
    private func countBody(_ r: Routine, _ i: Int) -> some View {
        let current = r.periodAmount(containing: date)

        ZStack {
            ProgressRing(
                progress: r.ratio(on: date),
                color: r.tint,
                size: 240,
                lineWidth: 18,
                showsCheck: false
            )

            // 가운데를 누르면 설정한 횟수만큼 늘어남
            Button {
                change(r.tapStep, at: i)
            } label: {
                VStack(spacing: 4) {
                    Text("\(current)회")
                        .font(.system(size: 54, weight: .bold, design: .rounded).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("목표 \(r.goalValue)회")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("누르면 +\(r.tapStep)회")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 190, height: 190)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(r.room(on: date) == 0)
        }

        Text("\(r.frequency.title) · 이 날 기록 \(Routine.format(r.amount(on: date), kind: r.goalKind))")
            .font(.footnote)
            .foregroundStyle(.secondary)

        HStack(spacing: 10) {
            Button {
                change(-r.tapStep, at: i)
            } label: {
                Text("−\(r.tapStep)회")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                change(r.tapStep, at: i)
            } label: {
                Text("+\(r.tapStep)회")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(r.room(on: date) == 0)
        }
    }

    // MARK: 시간 목표 (타이머, 초 단위)
    @ViewBuilder
    private func timeBody(_ r: Routine, _ i: Int) -> some View {
        ZStack {
            ProgressRing(
                progress: r.ratio(on: date),
                color: r.tint,
                size: 240,
                lineWidth: 18,
                showsCheck: false
            )

            if let start = timerStart {
                // 타이머가 흐르는 중
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Routine.clock(Int(context.date.timeIntervalSince(start))))
                        .font(.system(size: 54, weight: .bold, design: .rounded).monospacedDigit())
                }
            } else {
                // 시간을 누르면 설정한 분만큼 늘어남
                Button {
                    change(r.tapAmount, at: i)
                } label: {
                    VStack(spacing: 4) {
                        Text(Routine.clock(r.periodAmount(containing: date)))
                            .font(.system(size: 54, weight: .bold, design: .rounded).monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("목표 \(Routine.clock(r.goalValue))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("누르면 +\(r.tapStep)분")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 190, height: 190)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(r.room(on: date) == 0)
            }
        }

        Text("\(r.frequency.title) · 이 날 기록 \(Routine.format(r.amount(on: date), kind: r.goalKind))")
            .font(.footnote)
            .foregroundStyle(.secondary)

        if timerStart != nil {
            Text("정지하면 흐른 시간이 초 단위로 기록돼요")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                stopTimer(at: i, save: true)
            } label: {
                Label("정지하고 기록", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(r.tint)

            Button("기록하지 않고 취소") {
                stopTimer(at: i, save: false)
            }
        } else {
            Button {
                timerStart = Date()
            } label: {
                Label("타이머 시작", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(r.tint)
            .disabled(r.room(on: date) == 0)
        }
    }

    // MARK: 동작
    private func change(_ delta: Int, at i: Int) {
        let key = Routine.key(for: date)
        var d = delta
        if d > 0 {
            d = min(d, routines[i].room(on: date))   // 초과 기록이 꺼져 있으면 목표까지만
        }
        let newValue = max(0, (routines[i].progress[key] ?? 0) + d)
        routines[i].progress[key] = newValue == 0 ? nil : newValue
    }

    // 목표까지 모자란 만큼 채움
    private func fill(at i: Int) {
        let missing = routines[i].goalValue - routines[i].periodAmount(containing: date)
        if missing > 0 {
            change(missing, at: i)
        }
    }

    // 이 날 기록 초기화
    private func clear(at i: Int) {
        routines[i].progress[Routine.key(for: date)] = nil
    }

    // 건너뛰기 / 건너뛰기 취소 (빈도만큼: 하루, 한 주, 한 달)
    private func toggleSkip(at i: Int) {
        let key = routines[i].periodKey(containing: date)
        if let idx = routines[i].skipped.firstIndex(of: key) {
            routines[i].skipped.remove(at: idx)
        } else {
            routines[i].skipped.append(key)
        }
    }

    // 타이머를 멈추고, 흐른 시간을 초 단위로 기록
    private func stopTimer(at i: Int, save: Bool) {
        guard let start = timerStart else { return }
        let seconds = Int(Date().timeIntervalSince(start).rounded())
        timerStart = nil
        if save && seconds > 0 {
            change(seconds, at: i)
        }
    }
}
