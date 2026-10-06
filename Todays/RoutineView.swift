import SwiftUI

// MARK: - 루틴 화면
struct RoutineView: View {
    @Binding var barCompact: Bool
    @AppStorage("routines") private var saved = "[]"
    @State private var routines: [Routine] = []
    @State private var editing: Routine? = nil
    @State private var progressTarget: Routine? = nil
    @State private var editMode: EditMode = .inactive
    @State private var showStats = false
    @State private var showMonth = false
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())

    private var cal: Calendar { Calendar.current }
    private var today: Date { cal.startOfDay(for: Date()) }
    private var weekday: Int { cal.component(.weekday, from: selectedDate) }
    private var isFuture: Bool { selectedDate > today }

    // 선택한 날짜에 목록에 나오는 루틴
    private var dayRoutines: [Routine] { routines.filter { $0.appears(on: selectedDate) } }
    private var activeRoutines: [Routine] { dayRoutines.filter { !$0.isSkipped(on: selectedDate) } }
    private var doneCount: Int { activeRoutines.filter { $0.isComplete(on: selectedDate) }.count }

    // 날짜 줄(주 단위 페이지)과 선택한 날짜를 연결
    private var weekBinding: Binding<Int> {
        Binding(
            get: { weekOffset(of: selectedDate) },
            set: { new in
                let diff = new - weekOffset(of: selectedDate)
                selectedDate = cal.date(byAdding: .weekOfYear, value: diff, to: selectedDate) ?? selectedDate
            }
        )
    }

    // 펼친 달력(달 단위 페이지)과 선택한 날짜를 연결
    private var monthBinding: Binding<Int> {
        Binding(
            get: { monthOffset(of: selectedDate) },
            set: { new in
                let diff = new - monthOffset(of: selectedDate)
                selectedDate = cal.date(byAdding: .month, value: diff, to: selectedDate) ?? selectedDate
            }
        )
    }

    private func weekStart(of date: Date) -> Date {
        cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    private func weekOffset(of date: Date) -> Int {
        cal.dateComponents([.weekOfYear], from: weekStart(of: today), to: weekStart(of: date)).weekOfYear ?? 0
    }

    private func monthStart(of date: Date) -> Date {
        cal.dateInterval(of: .month, for: date)?.start ?? date
    }

    private func monthOffset(of date: Date) -> Int {
        cal.dateComponents([.month], from: monthStart(of: today), to: monthStart(of: date)).month ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if showMonth {
                MonthCalendar(
                    monthIndex: monthBinding,
                    selected: $selectedDate,
                    routines: routines,
                    today: today
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        showMonth = false
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                Spacer()
            } else {
                weekStrip
                modeRow
                content
            }
        }
        .sheet(item: $editing) { routine in
            let isNew = !routines.contains { $0.id == routine.id }
            RoutineEditor(
                routine: routine,
                isNew: isNew,
                onSave: { save($0) },
                onDelete: {
                    routines.removeAll { $0.id == routine.id }
                }
            )
        }
        .sheet(item: $progressTarget) { target in
            ProgressSheet(routineID: target.id, routines: $routines, date: selectedDate)
                .presentationDetents([.large])
        }
        .onAppear {
            load()
        }
        .onChange(of: routines) {
            persist()
            if routines.isEmpty {
                barCompact = false
            }
        }
        .onChange(of: dayRoutines.count) {
            if dayRoutines.count < 2 {
                editMode = .inactive
            }
        }
    }

    // MARK: - 화면 조각들
    // 1. 월 표시 (누르면 달력이 펼쳐짐)
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    showMonth.toggle()
                    editMode = .inactive
                    barCompact = false
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(selectedDate, format: .dateTime.month())
                        .font(.largeTitle.bold())
                    Image(systemName: "chevron.down")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showMonth ? 180 : 0))
                }
                .foregroundStyle(Color.primary)
            }
            .buttonStyle(.plain)

            if cal.component(.year, from: selectedDate) != cal.component(.year, from: today) {
                Text(selectedDate, format: .dateTime.year())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if selectedDate != today {
                Button {
                    withAnimation {
                        selectedDate = today
                    }
                } label: {
                    Text("오늘")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
            }
        }
        .environment(\.locale, Locale(identifier: "ko_KR"))
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // 2. 날짜 줄 (좌우로 넘기기)
    private var weekStrip: some View {
        TabView(selection: weekBinding) {
            ForEach(-52...52, id: \.self) { offset in
                WeekRow(
                    start: cal.date(byAdding: .weekOfYear, value: offset, to: weekStart(of: today)) ?? today,
                    selected: $selectedDate,
                    today: today
                )
                .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 76)
    }

    // "루틴" / "통계" 전환 글자 버튼
    private func modeTab(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(isOn ? Color.primary : Color.secondary.opacity(0.6))
        }
        .buttonStyle(.plain)
    }

    // 3. 루틴 | 통계 전환 + 버튼
    private var modeRow: some View {
        HStack(alignment: .center) {
            HStack(spacing: 16) {
                modeTab("루틴", isOn: !showStats) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showStats = false
                        barCompact = false
                    }
                }
                modeTab("통계", isOn: showStats) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showStats = true
                        editMode = .inactive
                        barCompact = false
                    }
                }
            }

            Spacer()

            if !showStats {
                // 순서 변경 버튼 (그 날 루틴이 2개 이상일 때)
                if dayRoutines.count > 1 {
                    Button {
                        withAnimation {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    } label: {
                        if editMode.isEditing {
                            Text("완료")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 6)
                        } else {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .frame(width: 36, height: 36)
                        }
                    }
                }

                Button {
                    editing = Routine(name: "", days: Array(1...7))
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor, in: Circle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .frame(minHeight: 52)
    }

    // 4. 내용: 통계 또는 루틴 목록
    @ViewBuilder
    private var content: some View {
        if showStats {
            RoutineStatsView(
                routines: routines,
                weekStart: weekStart(of: selectedDate),
                barCompact: $barCompact
            )
        } else if routines.isEmpty {
            EmptyHint(message: "아직 루틴이 없어요.\n루틴을 만들어주세요")
            Spacer()
        } else {
            List {
                Section {
                    if dayRoutines.isEmpty {
                        Text("이 날 예정된 루틴이 없어요")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(dayRoutines) { routine in
                        row(routine)
                    }
                    .onDelete { offsets in
                        delete(dayRoutines, at: offsets)
                    }
                    .onMove { from, to in
                        move(dayRoutines, from: from, to: to)
                    }
                } header: {
                    if !dayRoutines.isEmpty {
                        Text("\(doneCount)/\(activeRoutines.count) 완료" + (activeRoutines.count < dayRoutines.count ? " · 건너뜀 \(dayRoutines.count - activeRoutines.count)" : ""))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, $editMode)
            .shrinkBarOnScroll($barCompact)
        }
    }

    // 목록의 한 줄
    @ViewBuilder
    private func row(_ routine: Routine) -> some View {
        let skipped = routine.isSkipped(on: selectedDate)
        let complete = routine.isComplete(on: selectedDate) && !skipped

        HStack(spacing: 14) {
            // 큰 동그라미: 누르면 기록, 꾹 누르면 상세 화면
            RoutineRing(routine: routine, date: selectedDate)
                .contentShape(Circle())
                .onTapGesture {
                    if !isFuture {
                        tapRing(routine)
                    }
                }
                .onLongPressGesture(minimumDuration: 0.4) {
                    if !isFuture {
                        progressTarget = routine
                    }
                }
                .opacity(isFuture ? 0.35 : 1)

            RoutineIconView(name: routine.icon, size: 36, color: routine.tint)
                .opacity(complete || skipped ? 0.5 : 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(routine.name)
                    .font(.body.weight(.medium))
                    .strikethrough(complete)
                    .foregroundStyle(complete || skipped ? .secondary : .primary)
                Text(skipped ? "\(routine.skipText) 건너뜀" : routine.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                progressTarget = routine
            }
        }
        .padding(.vertical, 8)
        .swipeActions(edge: .leading) {
            if !isFuture {
                Button {
                    progressTarget = routine
                } label: {
                    Label("기록", systemImage: "slider.horizontal.3")
                }
                .tint(routine.tint)
            }
        }
    }

    // MARK: - 동작
    // 동그라미를 눌렀을 때 (횟수·시간 모두 설정한 만큼 늘어남)
    func tapRing(_ r: Routine) {
        // 건너뛴 루틴은 상세 화면에서 건너뛰기를 취소
        if r.isSkipped(on: selectedDate) {
            progressTarget = r
            return
        }
        guard let i = routines.firstIndex(where: { $0.id == r.id }) else { return }
        let key = Routine.key(for: selectedDate)
        let room = r.room(on: selectedDate)

        if room > 0 {
            routines[i].progress[key, default: 0] += min(r.tapAmount, room)   // 설정한 양만큼 증가
        } else {
            routines[i].progress[key] = nil   // 목표를 채웠고 초과 기록이 꺼져 있으면 그 날 기록 취소
        }
    }

    func save(_ r: Routine) {
        if let i = routines.firstIndex(where: { $0.id == r.id }) {
            routines[i] = r
        } else {
            var newRoutine = r
            newRoutine.createdKey = Routine.key(for: today)
            routines.append(newRoutine)
        }
    }

    func delete(_ list: [Routine], at offsets: IndexSet) {
        let ids = offsets.map { list[$0].id }
        routines.removeAll { ids.contains($0.id) }
    }

    // 보이는 목록 안에서 순서를 바꾸고, 전체 목록에서 그 자리들에 다시 채워 넣음
    func move(_ list: [Routine], from: IndexSet, to: Int) {
        var reordered = list
        reordered.move(fromOffsets: from, toOffset: to)
        let ids = Set(list.map { $0.id })
        var iterator = reordered.makeIterator()
        routines = routines.map { r in
            ids.contains(r.id) ? (iterator.next() ?? r) : r
        }
    }

    func persist() {
        if let data = try? JSONEncoder().encode(routines),
           let text = String(data: data, encoding: .utf8) {
            saved = text
        }
        NotificationManager.sync(routines)
    }

    func load() {
        if let data = saved.data(using: .utf8),
           let items = try? JSONDecoder().decode([Routine].self, from: data) {
            routines = items
        }
    }
}
