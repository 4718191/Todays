import SwiftUI

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var done = false
}

struct ChecklistView: View {
    @Binding var barCompact: Bool
    @AppStorage("todos") private var saved = "[]"
    @State private var todos: [TodoItem] = []

    // 새 항목 추가
    @State private var isAdding = false
    @State private var newText = ""
    @FocusState private var focused: Bool

    // 항목 수정
    @State private var editingID: UUID? = nil
    @State private var editText = ""
    @FocusState private var editFocused: Bool

    // 체크한 항목 삭제 확인창
    @State private var showClearConfirm = false

    private var today: Date { Date() }
    private var doneCount: Int { todos.filter { $0.done }.count }

    var body: some View {
        VStack(spacing: 0) {
            // 상단: 오늘 날짜 + 버튼들
            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(today, format: .dateTime.weekday(.wide))
                        .font(.title2.bold())
                    Text(today, format: .dateTime.month().day())
                        .foregroundStyle(.secondary)
                }
                .environment(\.locale, Locale(identifier: "ko_KR"))

                Spacer()

                // 체크한 항목이 있을 때만 보이는 전체 삭제 버튼
                if doneCount > 0 {
                    Button {
                        showClearConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                    }
                }

                Button {
                    startAdding()
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor, in: Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)

            if todos.isEmpty && !isAdding {
                EmptyHint()
                Spacer()
            } else {
                List {
                    ForEach($todos) { $item in
                        HStack(spacing: 12) {
                            Button {
                                item.done.toggle()
                            } label: {
                                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)

                            if editingID == item.id {
                                // 수정 중: 입력창으로 바뀜
                                TextField("할 일", text: $editText)
                                    .focused($editFocused)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        finishEditing()
                                    }
                                    .onAppear {
                                        editFocused = true
                                    }
                            } else {
                                // 평소: 글자를 누르면 수정 시작
                                Text(item.text)
                                    .strikethrough(item.done)
                                    .foregroundStyle(item.done ? .secondary : .primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        startEditing(item)
                                    }
                            }
                        }
                    }
                    .onDelete { offsets in
                        todos.remove(atOffsets: offsets)
                    }

                    // 새 항목 입력 줄
                    if isAdding {
                        HStack(spacing: 12) {
                            Image(systemName: "circle")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            TextField("할 일을 입력하세요", text: $newText)
                                .focused($focused)
                                .submitLabel(.done)
                                .onSubmit {
                                    commit()
                                }
                                .onAppear {
                                    focused = true
                                }
                        }
                    }
                }
                .listStyle(.plain)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { value in
                            if todos.isEmpty { return }
                            if value.translation.height < -15 {
                                barCompact = true
                            } else if value.translation.height > 15 {
                                barCompact = false
                            }
                        }
                )
            }
        }
        .confirmationDialog(
            "체크한 항목 \(doneCount)개를 삭제할까요?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                todos.removeAll { $0.done }
            }
            Button("취소", role: .cancel) {}
        }
        .onAppear {
            load()
        }
        .onChange(of: todos) {
            save()
            if todos.isEmpty {
                barCompact = false
            }
        }
        .onChange(of: focused) {
            if !focused && isAdding {
                finishAdding()
            }
        }
        .onChange(of: editFocused) {
            if !editFocused && editingID != nil {
                finishEditing()
            }
        }
    }

    // MARK: - 추가
    func startAdding() {
        isAdding = true
        focused = true
    }

    // 엔터: 내용이 있으면 추가하고 계속 입력, 비어 있으면 입력 종료
    func commit() {
        let text = newText.trimmingCharacters(in: .whitespaces)
        if text.isEmpty {
            isAdding = false
            return
        }
        todos.append(TodoItem(text: text))
        newText = ""
        focused = true
    }

    // 입력창 밖을 눌러 포커스가 사라졌을 때
    func finishAdding() {
        let text = newText.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty {
            todos.append(TodoItem(text: text))
        }
        newText = ""
        isAdding = false
    }

    // MARK: - 수정
    func startEditing(_ item: TodoItem) {
        editText = item.text
        editingID = item.id
    }

    func finishEditing() {
        guard let id = editingID else { return }
        let text = editText.trimmingCharacters(in: .whitespaces)
        // 비워 두면 원래 내용을 그대로 유지
        if !text.isEmpty, let i = todos.firstIndex(where: { $0.id == id }) {
            todos[i].text = text
        }
        editingID = nil
    }

    // MARK: - 저장 / 불러오기
    func save() {
        if let data = try? JSONEncoder().encode(todos),
           let text = String(data: data, encoding: .utf8) {
            saved = text
        }
    }

    func load() {
        if let data = saved.data(using: .utf8),
           let items = try? JSONDecoder().decode([TodoItem].self, from: data) {
            todos = items
        }
    }
}

// 항목이 없을 때 보이는 안내
struct EmptyHint: View {
    var message: String = "아직 내용이 없어요.\n체크리스트를 만들어주세요"
    @State private var up = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Image(systemName: "arrow.up")
                    .font(.title2.bold())
                    .foregroundStyle(Color.accentColor)
                    .offset(y: up ? -6 : 0)
                    .padding(.trailing, 28)
            }
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                up = true
            }
        }
    }
}
