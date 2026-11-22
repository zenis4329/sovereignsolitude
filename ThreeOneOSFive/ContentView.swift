import SwiftUI
import UIKit
import AudioToolbox

// ==========================================================
// MARK: - BACKGROUND (HIỂN THỊ RÕ ẢNH NỀN TRONG NAVIGATIONSTACK)
// ==========================================================
struct AppBackground: View {
    let urlString: String

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                if !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    SecureCatalogImage(
                        urlString: urlString,
                        placeholder: Image(systemName: "sparkles")
                    )
                    .id(urlString)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .opacity(0.68)
                }

                // Vignette tối nhẹ để nổi bật chữ & viền trắng neon nhưng vẫn rõ ảnh nền
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.32),
                        Color.black.opacity(0.58),
                        Color.black.opacity(0.88)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// ==========================================================
// MARK: - STYLES (NEON WHITE - TỐI GIẢN, NHẸ GPU)
// ==========================================================
extension View {
    func neonCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.74))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color.white.opacity(0.32),
                                Color.white.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: .white.opacity(0.18), radius: 8)
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
            Color.black.ignoresSafeArea()

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
                    .padding(.bottom, 22)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .tint((AppAccentSpectrum(rawValue: accentRaw) ?? .azure).color)
        .imageScale(.small)
    }

    // MARK: TAB BAR (ĐEN TUYỀN + VIỀN TRẮNG NEON)
    private var floatingTabBar: some View {
        HStack(spacing: 6) {
            tabButton(icon: "house.fill", title: "Trang chủ", tag: AppSection.home.rawValue)
            tabButton(icon: "lock.shield.fill", title: "Chức năng", tag: AppSection.games.rawValue)
        }
        .padding(7)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.9))
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white, Color.white.opacity(0.4), .white],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: .white.opacity(0.28), radius: 10)
        )
    }

    private func tabButton(icon: String, title: String, tag: Int) -> some View {
        let isSelected = tabNavigation.selectedTab == tag

        return Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
                tabNavigation.select(tag)
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium))

                if isSelected {
                    Text(title)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
            }
            .foregroundColor(isSelected ? .black : .white.opacity(0.6))
            .padding(.horizontal, isSelected ? 20 : 16)
            .padding(.vertical, 11)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Color.white)
                            .matchedGeometryEffect(id: "TAB_BG", in: tabAnimation)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// ==========================================================
// MARK: - DASHBOARD (BỐ CỤC BENTO MỚI)
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

    private var maskedKeyPreview: String {
        let raw = authManager.savedKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.count > 6 else { return raw.isEmpty ? "CHƯA KÍCH HOẠT" : raw }
        return "\(raw.prefix(4)) •••• \(raw.suffix(4))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Đặt AppBackground trực tiếp bên trong NavigationStack để không bị che
                AppBackground(urlString: authManager.publicBackgroundURL)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        topHeaderBar
                        heroProfileCard
                        licenseCard
                        deviceTelemetryRow
                        socialLinksSection

                        Spacer().frame(height: 105)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) {
                SettingsView().environmentObject(appState)
            }
        }
    }

    // MARK: 1. TOP HEADER BAR
    private var topHeaderBar: some View {
        HStack {
            HStack(spacing: 7) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .shadow(color: .white, radius: 4)
                Text("SYSTEM DASHBOARD")
                    .font(.system(size: 10.5, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(1.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.black.opacity(0.75)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.45), lineWidth: 1))

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.black.opacity(0.78)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 1.1))
                    .shadow(color: .white.opacity(0.25), radius: 6)
            }
            .buttonStyle(ClassicScaleButtonStyle())
        }
    }

    // MARK: 2. HERO PROFILE CARD (BỐ CỤC NGANG GỌN ĐẸP)
    private var heroProfileCard: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.28), Color.clear],
                            center: .center,
                            startRadius: 24,
                            endRadius: 46
                        )
                    )
                    .frame(width: 88, height: 88)

                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.8)
                    .frame(width: 78, height: 78)
                    .shadow(color: .white.opacity(0.6), radius: 6)

                CachedRemoteImage(url: catalogStore.catalog.brandAvatarURL.flatMap(URL.init(string:))) {
                    AppLogo(size: 68)
                }
                .scaledToFill()
                .frame(width: 68, height: 68)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(catalogStore.catalog.brandTitle ?? "Sovereign Solitude")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .shadow(color: .white.opacity(0.45), radius: 5)

                Text(catalogStore.catalog.brandSubtitle ?? language.text("dashboard.tagline"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    badgePill(icon: "checkmark.seal.fill", text: "PREMIUM")
                    badgePill(icon: "bolt.fill", text: "120FPS")
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .neonCard(cornerRadius: 22, padding: 16)
    }

    private func badgePill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8.5, weight: .bold))
            Text(text)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.8)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(Color.white.opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.55), lineWidth: 0.8))
    }

    // MARK: 3. LICENSE & KEY CARD
    private var licenseCard: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let remainingTime = calculateRemainingTime(from: authManager.expireDate, currentDate: context.date)
            let isExpired = remainingTime == "Hết Hạn"

            VStack(spacing: 14) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Text("THỜI HẠN LICENSE")
                            .font(.system(size: 10.5, weight: .black, design: .monospaced))
                            .foregroundColor(.white.opacity(0.75))
                            .tracking(1.4)
                    }

                    Spacer()

                    HStack(spacing: 5) {
                        Circle()
                            .fill(isExpired ? Color.red : Color.green)
                            .frame(width: 6, height: 6)
                            .shadow(color: isExpired ? .red : .green, radius: 4)
                        Text(isExpired ? "EXPIRED" : "ACTIVE")
                            .font(.system(size: 9.5, weight: .black, design: .monospaced))
                            .foregroundColor(isExpired ? .red : .white)
                            .tracking(1)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(isExpired ? Color.red.opacity(0.7) : Color.white.opacity(0.6), lineWidth: 0.9))
                }

                // Đồng hồ đếm ngược lớn
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(remainingTime)
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundColor(isExpired ? .red : .white)
                            .shadow(color: isExpired ? .red.opacity(0.6) : .white.opacity(0.45), radius: 6)

                        if !authManager.expireDate.isEmpty {
                            Text("Hết hạn: \(authManager.expireDate)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    Spacer()
                }

                Divider().background(Color.white.opacity(0.18))

                // Thanh Key + Nút Copy
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.55))
                        Text(maskedKeyPreview)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.88))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.9)
                    )

                    Button {
                        UIPasteboard.general.string = authManager.savedKey
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) { licenseKeyCopied = true }
                        AudioServicesPlaySystemSound(1104)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { licenseKeyCopied = false }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: licenseKeyCopied ? "checkmark" : "doc.on.doc.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(licenseKeyCopied ? "Đã chép" : "Copy Key")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(licenseKeyCopied ? .black : .white)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(licenseKeyCopied ? Color.white : Color.black.opacity(0.8))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.1)
                        )
                    }
                    .buttonStyle(ClassicScaleButtonStyle())
                }
            }
            .neonCard(cornerRadius: 22, padding: 16)
        }
    }

    private func calculateRemainingTime(from dateStr: String, currentDate: Date) -> String {
        guard let expDate = Self.dateFormatter.date(from: dateStr) else { return "Không xác định" }
        let diff = Int(expDate.timeIntervalSince(currentDate))
        if diff <= 0 { return "Hết Hạn" }
        let days = diff / 86400
        let hrs = (diff % 86400) / 3600
        let mins = (diff % 3600) / 60
        let secs = diff % 60
        return days > 0
            ? String(format: "%dN %02dH %02dM", days, hrs, mins)
            : String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }

    // MARK: 4. DEVICE TELEMETRY ROW (3 CỘT CÂN ĐỐI)
    private var deviceTelemetryRow: some View {
        HStack(spacing: 10) {
            telemetryTile(
                icon: "iphone",
                label: "THIẾT BỊ",
                value: AppInfo.hardwareDisplayName,
                valueColor: .white
            )
            telemetryTile(
                icon: "cpu",
                label: "PHIÊN BẢN",
                value: "iOS \(AppInfo.osVersion)",
                valueColor: .white
            )
            telemetryTile(
                icon: appState.isSupported ? "checkmark.shield.fill" : "xmark.shield.fill",
                label: "HỖ TRỢ",
                value: appState.isSupported ? "Tương thích" : "Không",
                valueColor: appState.isSupported ? .white : .red
            )
        }
    }

    private func telemetryTile(icon: String, label: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(valueColor)

            Text(value)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .neonCard(cornerRadius: 18, padding: 13)
    }

    // MARK: 5. SOCIAL & COMMUNITY LINKS
    private var socialLinksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(.white)
                Text("CỘNG ĐỒNG & HỖ TRỢ")
                    .font(.system(size: 10.5, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(1.4)
            }

            VStack(spacing: 9) {
                ForEach(catalogStore.catalog.resolvedSocialLinks.prefix(4), id: \.url) { link in
                    Button {
                        if let url = URL(string: link.url) { UIApplication.shared.open(url) }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(width: 30, height: 30)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                            Text(link.name)
                                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .black))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ClassicScaleButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .neonCard(cornerRadius: 22, padding: 16)
    }
}

// ==========================================================
// MARK: - NOTICE POPUP
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
            Color.black.opacity(0.88).ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.95), lineWidth: 2)
                            .frame(width: 84, height: 84)
                            .shadow(color: .white.opacity(0.75), radius: 8)

                        SecureRemoteImage(
                            urlString: authManager.publicAvatarURL,
                            placeholder: Image(systemName: "person.crop.circle.fill")
                        )
                        .frame(width: 74, height: 74)
                        .clipShape(Circle())
                    }

                    Text(store.catalog.brandTitle ?? "Sovereign Solitude")
                        .font(.system(size: 21, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.55), radius: 5)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 5, height: 5)
                        Text("THÔNG BÁO HỆ THỐNG")
                            .font(.system(size: 9.5, weight: .black, design: .monospaced))
                            .foregroundColor(.white.opacity(0.75))
                            .tracking(1.8)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.45), lineWidth: 0.8))
                }
                .padding(.top, 4)

                ScrollView(.vertical, showsIndicators: false) {
                    Text(noticeMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: 150)
                .padding(15)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                        )
                )

                VStack(spacing: 10) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onDismiss()
                    } label: {
                        Text("ĐÃ HIỂU")
                            .font(.system(size: 14.5, weight: .black, design: .rounded))
                            .tracking(1)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: .white.opacity(0.45), radius: 8)
                    }
                    .buttonStyle(ClassicScaleButtonStyle())

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSnoozeOneHour()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 12, weight: .semibold))
                            Text("ẨN TRONG 1 GIỜ")
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                .tracking(0.8)
                        }
                        .foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.black.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.65), lineWidth: 1)
                        )
                    }
                    .buttonStyle(ClassicScaleButtonStyle())
                }
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.black.opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white, Color.white.opacity(0.35), .white],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.3
                            )
                    )
                    .shadow(color: .white.opacity(0.32), radius: 14)
            )
            .padding(.horizontal, 24)
            .scaleEffect(showContent ? 1 : 0.88)
            .opacity(showContent ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
                showContent = true
            }
        }
    }
}
