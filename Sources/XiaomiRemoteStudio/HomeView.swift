import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack(spacing: 0) {
            RootToolbar(title: greeting, showAddDevice: true)

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                Button {
                    store.openDevice(.remote2Pro)
                } label: {
                    VStack(spacing: 17) {
                        RemoteProductImage()
                            .frame(width: 154, height: 414)
                            .shadow(
                                color: .black.opacity(0.10),
                                radius: 16,
                                y: 10
                            )

                        VStack(spacing: 7) {
                            Text(RemoteDevice.remote2Pro.name)
                                .font(AppTypography.title)
                            InlineDeviceStatus(state: store.connectionState)
                        }
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("打开按键配置")
                .accessibilityLabel("Xiaomi Bluetooth Remote 2 Pro")
                .accessibilityValue(store.connectionState.title)
                .accessibilityHint("打开按键配置")

                HStack(spacing: 10) {
                    Button("配置按键") {
                        store.openDevice(.remote2Pro)
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Button("蓝牙设置") {
                        store.openBluetoothSettings()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
                .padding(.top, 16)

                Spacer(minLength: 36)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 6 { return "夜深了" }
        if hour < 12 { return "早上好" }
        if hour < 18 { return "下午好" }
        return "晚上好"
    }

}
