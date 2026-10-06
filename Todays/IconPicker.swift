import SwiftUI
import UIKit

// MARK: - 아이콘 목록과 검사
enum IconCatalog {
    // 기본 목록 (전체 목록 파일이 없을 때 사용)
    static let basic: [String] = [
        "drop.fill", "figure.run", "figure.walk", "figure.yoga", "dumbbell.fill", "bicycle",
        "heart.fill", "pills.fill", "cross.case.fill", "bed.double.fill", "moon.fill", "sun.max.fill",
        "alarm.fill", "cup.and.saucer.fill", "fork.knife", "carrot.fill", "leaf.fill", "book.fill",
        "books.vertical.fill", "pencil", "highlighter", "graduationcap.fill", "laptopcomputer", "desktopcomputer",
        "keyboard", "brain.head.profile", "music.note", "headphones", "paintbrush.fill", "camera.fill",
        "gamecontroller.fill", "film.fill", "house.fill", "sparkles", "star.fill", "flame.fill",
        "bolt.fill", "clock.fill", "calendar", "checkmark.seal.fill", "target", "flag.fill",
        "bell.fill", "phone.fill", "message.fill", "envelope.fill", "cart.fill", "creditcard.fill",
        "banknote.fill", "pawprint.fill", "tree.fill", "car.fill", "airplane", "globe.asia.australia.fill",
        "sunrise.fill", "sunset.fill", "cloud.rain.fill", "snowflake", "hands.sparkles.fill", "face.smiling",
        "lightbulb.fill", "trash.fill", "washer.fill", "shower.fill", "figure.mind.and.body", "figure.hiking",
        "figure.swimming", "sportscourt.fill", "soccerball", "basketball.fill", "tennis.racket", "mug.fill",
        "wineglass.fill", "pencil.and.list.clipboard", "list.bullet.clipboard.fill", "doc.text.fill", "folder.fill", "paperplane.fill"
    ]

    // SF Symbols 앱에서 가져온 전체 이름 목록 (name_availability.plist 파일을 프로젝트에 넣으면 사용)
    static let all: [String] = {
        guard let url = Bundle.main.url(forResource: "name_availability", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let symbols = plist["symbols"] as? [String: Any],
              !symbols.isEmpty
        else {
            return basic
        }
        return symbols.keys.sorted()
    }()

    // 이 기기에서 보이는 SF Symbols 이름인지
    static func isSymbol(_ name: String) -> Bool {
        UIImage(systemName: name) != nil
    }

    // 이모지 한 글자인지
    static func isEmoji(_ text: String) -> Bool {
        guard text.count == 1, let scalar = text.unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && scalar.value > 0x238C
    }

    static func isValid(_ text: String) -> Bool {
        isSymbol(text) || isEmoji(text)
    }
}

// MARK: - 아이콘 선택 화면
// MARK: - 색상 + 아이콘 선택 화면
struct AppearanceScreen: View {
    @Binding var icon: String?
    @Binding var colorName: String?

    @State private var search = ""
    @State private var custom = ""

    private var tint: Color {
        RoutineColor(rawValue: colorName ?? "")?.color ?? .accentColor
    }

    private var customTrimmed: String {
        custom.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // 검색어에 맞는 아이콘 (너무 많으면 앞쪽 300개만)
    private var shown: [String] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let filtered = q.isEmpty ? IconCatalog.all : IconCatalog.all.filter { $0.contains(q) }
        return Array(filtered.prefix(600).filter { IconCatalog.isSymbol($0) }.prefix(300))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 미리보기
                Group {
                    if icon != nil {
                        RoutineIconView(name: icon, size: 84, color: tint)
                    } else {
                        Circle()
                            .fill(tint.opacity(0.15))
                            .frame(width: 84, height: 84)
                            .overlay(
                                Text("없음")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            )
                    }
                }
                .padding(.top, 8)

                // 색상
                VStack(alignment: .leading, spacing: 12) {
                    Text("색상")
                        .font(.headline)
                    HStack(spacing: 10) {
                        ForEach(RoutineColor.allCases, id: \.self) { c in
                            let on = colorName == c.rawValue
                            Button {
                                colorName = on ? nil : c.rawValue
                            } label: {
                                Circle()
                                    .fill(c.color)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                            .opacity(on ? 1 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .cardStyle()

                // 직접 입력
                VStack(alignment: .leading, spacing: 8) {
                    Text("직접 입력 (이모지 또는 SF Symbols 이름)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        TextField("예: 🏃 또는 figure.run", text: $custom)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(10)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                        if IconCatalog.isValid(customTrimmed) {
                            RoutineIconView(name: customTrimmed, size: 40, color: tint)
                            Button("선택") {
                                icon = customTrimmed
                                custom = ""
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .cardStyle()

                // 아이콘 목록
                VStack(alignment: .leading, spacing: 12) {
                    Text("아이콘")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 10)], spacing: 10) {
                        ForEach(shown, id: \.self) { name in
                            Button {
                                icon = name
                            } label: {
                                Image(systemName: name)
                                    .font(.title3)
                                    .frame(width: 52, height: 52)
                                    .background(
                                        icon == name ? tint : Color.secondary.opacity(0.15),
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                                    .foregroundStyle(icon == name ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .cardStyle()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $search, prompt: "영문 이름으로 검색 (예: heart)")
        .navigationTitle("아이콘")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("아이콘 없음") {
                    icon = nil
                }
            }
        }
    }
}
