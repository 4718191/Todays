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
    @State private var isAdding = false
    @State private var newText = ""
    @FocusState private var focused: Bool

    private var today: Date { Date() }

    var body: some View {
        VStack(spacing: 0) {
            // 상단: 오늘 날짜 + 추가 버튼
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(today, format: .dateTime.weekday(.wide))
                        .font(.title2.bold())
                    Text(today, format: .dateTime.month().day())
                        .foregroundStyle(.secondary)
                }
                .environment(\.locale, Locale(identifier: "ko_KR"))

                Spacer()

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

                            Text(item.text)
                                .strikethrough(item.done)
                                .foregroundStyle(item.done ? .secondary : .primary)
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
    }

    // MARK: - 추가 동작
    func startAdding() {
        isAdding = true
        focused = true
    }

    // 엔터를 눌렀을 때: 내용이 있으면 추가하고 계속 입력, 비어 있으면 입력 종료
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
            Text("아직 내용이 없어요.\n체크리스트를 만들어주세요!")
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

#Preview {
    ChecklistView(barCompact: .constant(false))
}
