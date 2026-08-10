import SwiftUI

/// Options+ opens a dedicated discovery surface from the recommendation card.
/// MiCoding keeps the same hierarchy while routing every card to a feature that
/// is implemented locally for Xiaomi Remote 2 Pro.
struct ExploreCenterView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 9) {
                    calibrationCard

                    VStack(spacing: 6) {
                        actionsRingCard
                        applicationProfilesCard
                    }
                }

                Button {
                    store.selectSection(.automations)
                } label: {
                    HStack(spacing: 12) {
                        Text("更多玩法")
                            .font(AppTypography.bodyMedium)
                        AppIcon(symbol: "chevron.right", size: 18)
                            .foregroundStyle(AppTheme.accent(for: colorScheme))
                    }
                        .frame(width: 109, height: 46)
                    .background(AppTheme.surface(for: colorScheme))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
                    }
                }
                .buttonStyle(QuietButtonStyle())
                .help("浏览 Smart Actions")
                .frame(width: 406, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 22)
            }
            .frame(width: 764, alignment: .leading)
            .padding(.top, 21)
            // The Options+ discovery campaign begins 190 pt below the native
            // content edge (222 pt including its 32 pt title bar).
            .offset(x: 15.5, y: 57.15)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.canvas(for: colorScheme))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("探索中心")
    }

    private var header: some View {
        HStack(spacing: 0) {
            Button {
                store.dismissExploreCenter()
            } label: {
                AppIcon(symbol: "arrow.left", size: AppIconSize.hero)
                    .frame(width: 46, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(QuietButtonStyle())
            .help("返回")
            .accessibilityLabel("返回设备列表")

            Text("探索中心")
                .font(AppTypography.deviceDisplay)
                .tracking(-0.8)
                .offset(y: -0.5)

            Spacer()
        }
        .padding(.leading, 40)
        .padding(.trailing, 40)
        .padding(.top, 14)
        .frame(height: 112)
        .offset(y: -19)
    }

    private var calibrationCard: some View {
        Button {
            store.showPhysicalKeyTest()
        } label: {
            ZStack(alignment: .topLeading) {
                colorScheme == .dark
                    ? Color.primary.opacity(0.045)
                    : Color(red: 245 / 255, green: 245 / 255, blue: 245 / 255)

                Text("逐键测试并校准 Xiaomi Remote 2 Pro")
                    .font(.custom("AvenirNext-DemiBold", size: 16.35))
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .padding(.leading, 13)
                    .padding(.top, 28)

                ExploreRemoteCalibrationArtwork()
                    .frame(width: 366, height: 210)
                    .position(x: 203, y: 201)

                HStack(spacing: 8) {
                    Text("开始测试")
                        .font(AppTypography.bodyMedium)
                    AppIcon(symbol: "arrow.right", size: 14)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 15)
                .frame(height: 36)
                .background(Color.black.opacity(colorScheme == .dark ? 0.88 : 1))
                .clipShape(Capsule())
                .padding(.leading, 10)
                .padding(.top, 361)
            }
            .frame(width: 406, height: 407)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(ExploreCardButtonStyle())
        .help("逐个测试 Xiaomi Remote 2 Pro 的实体按键")
        .accessibilityLabel("逐键测试并校准 Xiaomi Remote 2 Pro")
    }

    private var actionsRingCard: some View {
        Button {
            store.showActionsRingFromExploreCenter()
        } label: {
            ZStack(alignment: .topLeading) {
                AppTheme.canvas(for: colorScheme)

                Text("使用 Actions Ring 和 Smart Actions，\n减少重复操作。")
                    .font(.custom("AvenirNext-Regular", size: 16.35))
                    .foregroundStyle(Color.primary)
                    .lineSpacing(2)
                    .padding(.leading, 12)
                    .padding(.top, 30)

                ExploreActionsRingArtwork()
                    .frame(width: 170, height: 74)
                    .position(x: 174, y: 139)
            }
            .frame(width: 349, height: 201)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ExploreCardButtonStyle())
        .help("打开 Actions Ring")
        .accessibilityLabel("探索 Actions Ring 和 Smart Actions")
    }

    private var applicationProfilesCard: some View {
        Button {
            store.openDevice(.remote2Pro)
            store.showApplicationPicker()
        } label: {
            ZStack(alignment: .topLeading) {
                AppTheme.canvas(for: colorScheme)

                Text("为常用应用创建专属 Profile，\n自动切换按键配置。")
                    .font(.custom("AvenirNext-Regular", size: 16.35))
                    .foregroundStyle(Color.primary)
                    .lineSpacing(2)
                    .padding(.leading, 12)
                    .padding(.top, 30)

                ExploreApplicationProfilesArtwork()
                    .frame(width: 306, height: 86)
                    .position(x: 174, y: 151)
            }
            .frame(width: 349, height: 201)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(ExploreCardButtonStyle())
        .help("打开应用 Profile 选择器")
        .accessibilityLabel("为常用应用创建专属 Profile")
    }
}

private struct ExploreCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.992 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.10), value: configuration.isPressed)
    }
}

private struct ExploreRemoteCalibrationArtwork: View {
    var body: some View {
        ZStack {
            ForEach(Array([0.35, 0.53, 0.71, 0.89].enumerated()), id: \.offset) { index, scale in
                Ellipse()
                    .stroke(
                        AngularGradient(
                            colors: [
                                AppTheme.mint.opacity(0.22),
                                AppTheme.purple.opacity(0.42),
                                Color.pink.opacity(0.30),
                                AppTheme.mint.opacity(0.22)
                            ],
                            center: .center
                        ),
                        lineWidth: index == 0 ? 8 : 5
                    )
                    .frame(width: 246 * scale, height: 126 * scale)
                    .blur(radius: index == 0 ? 0.4 : 0)
                    .offset(x: 17, y: -29)
            }

            RemoteProductImage()
                .frame(width: 57, height: 187)
                .shadow(color: .black.opacity(0.17), radius: 12, y: 8)
                .offset(x: 3, y: 2)

            Circle()
                .fill(Color.black.opacity(0.86))
                .frame(width: 18, height: 18)
                .overlay {
                    AppIcon(symbol: "checkmark", size: 10)
                        .foregroundStyle(.white)
                }
                .offset(x: 32, y: -36)
        }
        .accessibilityHidden(true)
    }
}

private struct ExploreActionsRingArtwork: View {
    private let symbols = [
        "play.fill", "note.text", "sparkles", "lock.fill",
        "viewfinder", "folder.fill", "magnifyingglass", "gearshape"
    ]

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2 + 5)

            ZStack {
                ForEach(symbols.indices, id: \.self) { index in
                    ExploreActionsRingItem(symbol: symbols[index])
                        .position(itemPosition(at: index, center: center))
                }

                ExploreActionsRingCenter()
                    .position(center)
            }
        }
        .accessibilityHidden(true)
    }

    private func itemPosition(at index: Int, center: CGPoint) -> CGPoint {
        let angle = Double(index) / Double(symbols.count) * Double.pi * 2 - Double.pi / 2
        let radius: CGFloat = 26
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }
}

private struct ExploreActionsRingItem: View {
    let symbol: String

    var body: some View {
        Circle()
            .fill(Color.black.opacity(0.92))
            .frame(width: 17, height: 17)
            .overlay {
                AppIcon(symbol: symbol, size: 9)
                    .foregroundStyle(.white)
            }
    }
}

private struct ExploreActionsRingCenter: View {
    var body: some View {
        Circle()
            .fill(AppTheme.purple)
            .frame(width: 15, height: 15)
            .overlay {
                AppIcon(symbol: "sparkles", size: 8)
                    .foregroundStyle(.white)
            }
    }
}

private struct ExploreApplicationProfilesArtwork: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.035))
                .frame(width: 244, height: 64)

            HStack(spacing: 11) {
                profileIcon("globe", tint: .blue)
                profileIcon("safari.fill", tint: .cyan)
                profileIcon("note.text", tint: AppTheme.purple)
                profileIcon("music.note", tint: .pink)

                VStack(alignment: .leading, spacing: 5) {
                    Capsule()
                        .fill(Color.primary.opacity(0.28))
                        .frame(width: 54, height: 5)
                    Capsule()
                        .fill(AppTheme.purple.opacity(0.72))
                        .frame(width: 36, height: 5)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func profileIcon(_ symbol: String, tint: Color) -> some View {
        AppIcon(symbol: symbol, size: 14)
            .foregroundStyle(tint)
            .frame(width: 28, height: 28)
            .background(AppTheme.surface(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(AppTheme.separator(for: colorScheme), lineWidth: 1)
            }
    }
}
