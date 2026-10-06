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



