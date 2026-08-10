import SwiftUI

/// Mirrors the in-app connection chooser used by Options+ while keeping the
/// actual pairing hand-off native to macOS.
struct ConnectionTypePickerView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppTheme.canvas(for: colorScheme)
                    .ignoresSafeArea()

                header
                    .position(x: proxy.size.width / 2, y: 30)

                bluetoothChoice
                    .position(x: proxy.size.width / 2, y: 343)

                Text("要配对您的设备，请通过蓝牙连接 Xiaomi 遥控器")
                    .font(.custom("AvenirNext-Regular", size: 14))
                    .foregroundStyle(Color.primary.opacity(0.88))
                    .position(x: proxy.size.width / 2, y: proxy.size.height - 62)
                    .accessibilityLabel("要配对您的设备，请通过蓝牙连接 Xiaomi 遥控器")
            }
        }
        .task {
            // Match Options+'s background discovery while the system Bluetooth
            // pane is open. A newly paired remote is adopted automatically.
            while !Task.isCancelled, store.showsConnectionTypePicker {
                store.refreshRuntimeState()
                guard store.showsConnectionTypePicker else { return }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private var header: some View {
        ZStack {
            Text("选择连接类型")
                .font(.custom("AvenirNext-Bold", size: 24))
                .foregroundStyle(Color.primary.opacity(0.92))

            HStack {
                Button {
                    store.cancelAddingDevice()
                } label: {
                    AppIcon(symbol: "arrow.left", size: 22)
                        .frame(width: 46, height: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(QuietButtonStyle())
                .keyboardShortcut(.cancelAction)
                .help("返回")
                .accessibilityLabel("返回设备列表")
                .offset(x: 11, y: -8)

                Spacer()
            }
        }
        .frame(width: 1_180, height: 52)
        .padding(.leading, 18)
    }

    private var bluetoothChoice: some View {
        Button {
            store.connectWithBluetooth()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.02, green: 0.49, blue: 0.96))

                    AppIcon(symbol: "wave.3.right", size: 18)
                        .foregroundStyle(.white)
                }
                .frame(width: 26, height: 26)

                Text("蓝牙")
                    .font(.custom("AvenirNext-Bold", size: 16))
                    .foregroundStyle(Color.primary.opacity(0.90))

                Spacer()

                AppIcon(symbol: "chevron.right", size: 17)
                    .foregroundStyle(AppTheme.accent(for: colorScheme))
            }
            .padding(.horizontal, 34)
            .frame(width: 469, height: 93)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(ConnectionTypeCardButtonStyle())
        .help("通过蓝牙连接")
        .accessibilityLabel("蓝牙")
        .accessibilityHint("打开系统蓝牙设置并配对遥控器")
    }
}

private struct ConnectionTypeCardButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                cardBackground
                    .opacity(configuration.isPressed ? 0.82 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(cardBorder, lineWidth: 1)
            }
    }

    private var cardBackground: Color {
        if colorScheme == .dark {
            return AppTheme.accent(for: colorScheme).opacity(0.13)
        }
        // Sampled from the Options+ connection chooser: rgb(249, 246, 255).
        return Color(red: 249.0 / 255.0, green: 246.0 / 255.0, blue: 1)
    }

    private var cardBorder: Color {
        if colorScheme == .dark {
            return AppTheme.accent(for: colorScheme).opacity(0.42)
        }
        // Sampled from the reference's one-pixel outline: rgb(230, 220, 254).
        return Color(red: 230.0 / 255.0, green: 220.0 / 255.0, blue: 254.0 / 255.0)
    }
}
