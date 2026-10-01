import SwiftUI

struct TodoView: View {
    var body: some View {
        NavigationStack {
            Text("할 일 화면")
                .foregroundStyle(.secondary)
                .navigationTitle("할 일")
        }
    }
}

struct RoutineView: View {
    var body: some View {
        NavigationStack {
            Text("루틴 화면")
                .foregroundStyle(.secondary)
                .navigationTitle("루틴")
        }
    }
}

struct AccountView: View {
    var body: some View {
        NavigationStack {
            Text("계정 화면")
                .foregroundStyle(.secondary)
                .navigationTitle("계정")
        }
    }
}
