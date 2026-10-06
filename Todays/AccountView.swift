import SwiftUI

struct AccountView: View {
    @Binding var barCompact: Bool
    @AppStorage("profileName") private var name = ""
    @AppStorage("appearance") private var appearance = 0   // 0 시스템, 1 라이트, 2 다크
    @AppStorage("notifyOn") private var notifyOn = false
    @AppStorage("todos") private var savedTodos = "[]"
    @State private var showReset = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            List {
                // 프로필
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("이름을 입력하세요", text: $name)
                                .font(.title3.bold())
                            Text("로그인하지 않음")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // 동기화 (자리만 잡아 둠)
                Section("동기화") {
                    HStack(spacing: 12) {
                        Image(systemName: "icloud")
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("기기 간 동기화")
                            Text("로그인하면 다른 기기에서도 볼 수 있어요")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("준비 중")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("화면") {
                    Picker("화면 모드", selection: $appearance) {
                        Text("시스템").tag(0)
                        Text("라이트").tag(1)
                        Text("다크").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                Section("알림") {
                    Toggle("알림 받기", isOn: $notifyOn)
                        .onChange(of: notifyOn) {
                            if notifyOn {
                                NotificationManager.requestPermission { granted in
                                    if granted {
                                        NotificationManager.syncFromStorage()
                                    } else {
                                        notifyOn = false
                                    }
                                }
                            } else {
                                NotificationManager.syncFromStorage()
                            }
                        }
                }

                Section("데이터") {
                    Button("체크리스트 전체 초기화", role: .destructive) {
                        showReset = true
                    }
                }

                Section("앱 정보") {
                    LabeledContent("버전", value: appVersion)
                }
            }
            .navigationTitle("계정")
            .shrinkBarOnScroll($barCompact)
            .confirmationDialog(
                "체크리스트를 전부 삭제할까요?",
                isPresented: $showReset,
                titleVisibility: .visible
            ) {
                Button("전부 삭제", role: .destructive) {
                    savedTodos = "[]"
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("삭제한 내용은 되돌릴 수 없어요.")
            }
        }
    }
}
