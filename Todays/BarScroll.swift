import SwiftUI

extension View {
    // 스크롤 방향에 따라 하단 메뉴바를 줄이고 키우는 기능
    func shrinkBarOnScroll(_ compact: Binding<Bool>) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 15)
                .onChanged { value in
                    if value.translation.height < -15 {
                        compact.wrappedValue = true
                    } else if value.translation.height > 15 {
                        compact.wrappedValue = false
                    }
                }
        )
    }
}
