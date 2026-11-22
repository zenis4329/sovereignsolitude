import SwiftUI
import UIKit
import AudioToolbox

// ==========================================================
// MARK: - BACKGROUND (ẢNH NỀN APP + TỐI ĐEN)
// ==========================================================
struct AppBackground: View {
    let urlString: String

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                // ẢNH NỀN APP HIỆN RÕ
                if !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    SecureRemoteImage(urlString: urlString, placeholder: Image(systemName: "photo"))
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .opacity(0.55)
                }

                // Gradient đen phủ dần xuống
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.2),
                        Color.black.opacity(0.6),
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }
}

// ==========================================================
// MARK: - NEON WHITE STYLES
// ==========================================================
extension View {
    /// Viền trắng neon phát sáng
    func neonWhiteBorder(cornerRadius: CGFloat = 20, lineWidth: CGFloat = 1.2) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.85), lineWidth: lineWidth)
                .shadow(color: .white.opacity(0.8), radius: 4)
                .shadow(color: .white.opacity(0.4), radius: 10)
                .shadow(color: .white.opacity(0.15), radius: 20)
        )
    }

    /// Card đen + viền trắng neon
    func neonCard(cornerRadius: CGFloat = 20) -> some View {
        self
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.72))
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.2)
                    .shadow(color: .white.opacity(0.9), radius: 4)
                    .shadow(color: .white.opacity(0.5), radius: 12)
                    .shadow(color: .white.opacity(0.2), radius: 22)
            )
            .shadow(color: .black.opacity(0.6), radius: 15, y: 8)
    }
}

// ==========================================================
// MARK: - CONTENT VIEW
// ==========================================================
struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @State private var tabNavigation: AppTabNavigationState
    @StateObject private var gameCatalog = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var isTabBarHidden = false

    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    @AppStorage(AppThemePreferences.accentStorageKey) private var accentRaw = AppThemePreferences.defaultAccent.rawValue

    @Namespace private var tabAnimation

    init() {
        let initialTab = AppSection.home.rawValue
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground(urlString: authManager.publicBackgroundURL)

            Group {
                if tabNavigation.selectedTab == AppSection.home.rawValue {
                    DashboardView(cleanerEnabled: $cleanerEnabled)
                } else {
                    GameCatalogView(isTabBarHidden: $isTabBarHidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !isTabBarHidden {
                floatingTabBar
                    .padding(.bottom, 25)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .tint((AppAccentSpectrum(rawValue: accentRaw) ?? .azure).color)
        .imageScale(.small)
    }

    // MARK: TAB BAR — NEON WHITE
    private var floatingTabBar: some View {
        HStack(spacing: 6) {
            tabButton(icon: "house.fill", title: "Trang chủ", tag: AppSection.home.rawValue)
            tabButton(icon: "lock.shield.fill", title: "Chức năng", tag: AppSection.games.rawValue)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.9), lineWidth: 1.2)
                        .shadow(color: .white.opacity(0.9), radius: 5)
                        .shadow(color: .white.opacity(0.5), radius: 14)
                        .shadow(color: .white.opacity(0.2), radius: 24)
                )
                .shadow(color: .black.opacity(0.8), radius: 20, y: 8)
        )
    }

    private func tabButton(icon: String, title: String, tag: Int) -> some View {
        let isSelected = tabNavigation.selectedTab == tag

        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                tabNavigation.select(tag)
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .medium))

                if isSelected {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .foregroundColor(isSelected ? .black : .white.opacity(0.55))
            .padding(.horizontal, isSelected ? 22 : 16)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Color.white)
                            .matchedGeometryEffect(id: "TAB_BG", in: tabAnimation)
                            .shadow(color: .white.opacity(0.8), radius: 8)
                            .shadow(color: .white.opacity(0.4), radius: 16)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// ==========================================================
// MARK: - DASHBOARD
// ==========================================================
private struct DashboardView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var showSettings = false
    @State private var licenseKeyCopied = false
    @StateObject private var catalogStore = GameCatalogStore.shared
    @Binding var cleanerEnabled: Bool
    @AppStorage(AppThemePreferences.accentStorageKey) private var accentRaw = AppThemePreferences.defaultAccent.rawValue

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        return formatter
    }()

    @State private var isBreathing = false
    @State private var ringRotation: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    heroSection
                    licenseCard

                    HStack(alignment: .top, spacing: 12) {
                        deviceCard.frame(maxWidth: .infinity)
                        socialGrid.frame(maxWidth: .infinity)
                    }

                    Spacer().frame(height: 110)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.9), radius: 6)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().environmentObject(appState)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                    ringRotation = 360
                }
            }
        }
    }

    // MARK: 1. HERO — AVATAR NEON TRẮNG
    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                // Glow trắng neon nhiều lớp (breathing)
                Circle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 130, height: 130)
                    .blur(radius: 30)
                    .scaleEffect(isBreathing ? 1.15 : 0.88)
                    .opacity(isBreathing ? 1.0 : 0.5)

                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 110, height: 110)
                    .blur(radius: 18)
                    .scaleEffect(isBreathing ? 1.1 : 0.92)

                // Vòng viền trắng NEON xoay nhẹ
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 2)
                    .frame(width: 108, height: 108)
                    .shadow(color: .white.opacity(1.0), radius: 6)
                    .shadow(color: .white.opacity(0.6), radius: 16)
                    .shadow(color: .white.opacity(0.3), radius: 28)

                // Vòng viền ngoài mảnh (gạch đứt)
                Circle()
                    .stroke(
                        Color.white.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 6])
                    )
                    .frame(width: 124, height: 124)
                    .rotationEffect(.degrees(ringRotation))
                    .shadow(color: .white.opacity(0.5), radius: 8)

                // Ảnh Avatar
                CachedRemoteImage(url: catalogStore.catalog.brandAvatarURL.flatMap(URL.init(string:))) {
                    AppLogo(size: 92)
                }
                .scaledToFill()
                .frame(width: 92, height: 92)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                        .shadow(color: .white.opacity(0.9), radius: 5)
                )
            }
            .frame(height: 145)

            VStack(spacing: 6) {
                Text(catalogStore.catalog.brandTitle ?? "Sovereign Solitude")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .tracking(1.5)
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.8), radius: 6)
                    .shadow(color: .white.opacity(0.4), radius: 14)

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 5, height: 5)
                        .shadow(color: .white, radius: 4)
                    Text(catalogStore.catalog.brandSubtitle ?? language.text("dashboard.tagline"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .tracking(1.2)
                }
            }
        }
        .padding(.top, 10)
    }

    // MARK: 2. LICENSE CARD
    private var licenseCard: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let remainingTime = calculateRemainingTime(from: authManager.expireDate, currentDate: context.date)

            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "hourglass")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .shadow(color: .white.opacity(0.6), radius: 3)
                    Text("LICENSE")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(2)
                    Spacer()
                    if remainingTime != "Hết Hạn" {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 5, height: 5)
                                .shadow(color: .white, radius: 4)
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .tracking(1)
                        }
                    } else {
                        Text("EXPIRED")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                            .shadow(color: .red.opacity(0.8), radius: 4)
                            .tracking(1)
                    }
                }

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Thời gian còn lại")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.45))
                        Text(remainingTime)
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundColor(remainingTime == "Hết Hạn" ? .red : .white)
                            .shadow(color: remainingTime == "Hết Hạn" ? .red.opacity(0.8) : .white.opacity(0.7), radius: 5)
                    }

                    Spacer()

                    Button {
                        UIPasteboard.general.string = authManager.savedKey
                        withAnimation { licenseKeyCopied = true }
                        AudioServicesPlaySystemSound(1104)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { licenseKeyCopied = false }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: licenseKeyCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 16, weight: .semibold))
                            Text(licenseKeyCopied ? "Đã chép" : "Copy")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.5)
                        }
                        .foregroundColor(licenseKeyCopied ? .black : .white)
                        .frame(width: 56, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(licenseKeyCopied ? Color.white : Color.black.opacity(0.6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.9), lineWidth: 1.2)
                                .shadow(color: .white.opacity(0.9), radius: 5)
                                .shadow(color: .white.opacity(0.5), radius: 12)
                        )
                    }
                    .buttonStyle(ClassicScaleButtonStyle())
                }
            }
            .neonCard()
        }
    }

    private func calculateRemainingTime(from dateStr: String, currentDate: Date) -> String {
        guard let expDate = Self.dateFormatter.date(from: dateStr) else { return "Không xác định" }
        let diff = Int(expDate.timeIntervalSince(currentDate))
        if diff <= 0 { return "Hết Hạn" }
        let days = diff / 86400
        let hrs = (diff % 86400) / 3600
        let mins = (diff % 3600) / 60
        return days > 0
            ? "\(days)N \(hrs)H"
            : String(format: "%02d:%02d:%02d", hrs, mins, diff % 60)
    }

    // MARK: 3. DEVICE CARD
    private var deviceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "iphone")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.8), radius: 4)
                Text("THIẾT BỊ")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(1.5)
            }

            VStack(alignment: .leading, spacing: 12) {
                deviceRow(label: "Máy", value: AppInfo.hardwareDisplayName)
                Divider().background(Color.white.opacity(0.15))
                deviceRow(label: "iOS", value: AppInfo.osVersion)
                Divider().background(Color.white.opacity(0.15))
                deviceRow(
                    label: "Hỗ trợ",
                    value: appState.isSupported ? "Có" : "Không",
                    valueColor: appState.isSupported ? .white : .red
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .neonCard()
    }

    private func deviceRow(label: String, value: String, valueColor: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .tracking(0.5)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(valueColor)
                .shadow(color: valueColor.opacity(0.5), radius: 3)
                .lineLimit(1)
        }
    }

    // MARK: 4. SOCIAL GRID
    private var socialGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.8), radius: 4)
                Text("LIÊN KẾT")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(1.5)
            }

            VStack(spacing: 8) {
                ForEach(catalogStore.catalog.resolvedSocialLinks.prefix(3), id: \.url) { link in
                    Button {
                        if let url = URL(string: link.url) { UIApplication.shared.open(url) }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .shadow(color: .white.opacity(0.6), radius: 3)
                            Text(link.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.95))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.7), lineWidth: 1)
                                .shadow(color: .white.opacity(0.6), radius: 3)
                                .shadow(color: .white.opacity(0.3), radius: 8)
                        )
                    }
                    .buttonStyle(ClassicScaleButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .neonCard()
    }
}

// ==========================================================
// MARK: - NOTICE POPUP (NEON WHITE)
// ==========================================================
struct NoticeBannerView: View {
    let onDismiss: () -> Void
    let onSnoozeOneHour: () -> Void

    @StateObject private var authManager = CustomAuthManager.shared
    @StateObject private var store = GameCatalogStore.shared
    @State private var showContent = false

    private var noticeMessage: String {
        let msg = store.catalog.noticeMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return msg.isEmpty ? "Chúc Anh Em Chơi Game Vui Vẻ 🥰" : msg
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 20) {
                VStack(spacing: 14) {
                    ZStack {
                        // Neon glow
                        Circle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 110, height: 110)
                            .blur(radius: 22)

                        Circle()
                            .stroke(Color.white.opacity(0.9), lineWidth: 2)
                            .frame(width: 88, height: 88)
                            .shadow(color: .white.opacity(1.0), radius: 6)
                            .shadow(color: .white.opacity(0.6), radius: 14)
                            .shadow(color: .white.opacity(0.3), radius: 24)

                        SecureRemoteImage(
                            urlString: authManager.publicAvatarURL,
                            placeholder: Image(systemName: "person.crop.circle.fill")
                        )
                        .frame(width: 76, height: 76)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.6), lineWidth: 1)
                                .shadow(color: .white.opacity(0.8), radius: 4)
                        )
                    }

                    Text("Sovereign Solitude")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .tracking(1.5)
                        .shadow(color: .white.opacity(0.8), radius: 6)
                        .shadow(color: .white.opacity(0.4), radius: 14)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 5, height: 5)
                            .shadow(color: .white, radius: 4)
                        Text("THÔNG BÁO")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(2)
                    }
                }
                .padding(.top, 10)

                ScrollView(.vertical, showsIndicators: false) {
                    Text(noticeMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: 150)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                .shadow(color: .white.opacity(0.4), radius: 4)
                        )
                )

                VStack(spacing: 10) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onDismiss()
                    } label: {
                        Text("OK")
                            .font(.system(size: 15, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: .white.opacity(0.9), radius: 8)
                            .shadow(color: .white.opacity(0.4), radius: 18)
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSnoozeOneHour()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 12, weight: .semibold))
                            Text("ẨN 1 GIỜ")
                                .font(.system(size: 13, weight: .bold))
                                .tracking(1)
                        }
                        .foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.7), lineWidth: 1)
                                .shadow(color: .white.opacity(0.5), radius: 4)
                                .shadow(color: .white.opacity(0.25), radius: 10)
                        )
                    }
                }
                .padding(.bottom, 6)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.black.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.9), lineWidth: 1.3)
                            .shadow(color: .white.opacity(0.9), radius: 6)
                            .shadow(color: .white.opacity(0.5), radius: 16)
                            .shadow(color: .white.opacity(0.2), radius: 30)
                    )
            )
            .shadow(color: .black.opacity(0.9), radius: 30, y: 15)
            .padding(.horizontal, 24)
            .scaleEffect(showContent ? 1 : 0.85)
            .opacity(showContent ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }
}
