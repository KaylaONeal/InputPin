import SwiftUI

/// Store artwork around the actual native panel. Preview-only; never starts the pinning engine.
struct StorePresentation: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            HStack(spacing: 0) {
                Color(red: 0.81, green: 0.88, blue: 0.92)
                Color(red: 0.91, green: 0.86, blue: 0.80)
            }.opacity(0.6)
            HStack(spacing: 100) {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 12) {
                        PinMark().frame(width: 44, height: 44)
                        Text("InputPin").font(.system(size: 25, weight: .semibold, design: .rounded))
                    }
                    Text(Copy.text("Your input.\nRight where you left it.", "你的输入法，\n始终如你所选。"))
                        .font(.system(size: 46, weight: .semibold)).tracking(-1.5)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(Copy.text("Choose it. Pin it. Keep typing.", "选好，固定，安心打字。"))
                        .font(.system(size: 22)).foregroundStyle(.secondary)
                    Text(Copy.text("A quiet native menu bar utility.", "轻巧、通透的原生菜单栏工具。"))
                        .font(.system(size: 16)).foregroundStyle(.secondary).padding(.top, 28)
                }.frame(width: 550, alignment: .leading)
                PinPanel(model: model).fixedSize()
                    .shadow(color: .black.opacity(0.12), radius: 28, y: 12)
            }.padding(80)
        }.frame(width: 1280, height: 800)
    }
}
