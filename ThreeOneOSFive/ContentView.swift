import SwiftUI
import UIKit
import AudioToolbox

struct ContentView: View {
    @Environment(\.appLanguage) private var language
    @State private var tabNavigation: AppTabNavigationState
    @StateObject private var gameCatalog = GameCatalogStore.shared
    @State private var isTabBarHidden = false
    
    @AppStorage(FeatureVisibility.cleanerStorageKey) private var cleanerEnabled = true
    @AppStorage(AppThemePreferences.accentStorageKey) private var accentRaw = AppThemePreferences.defaultAccent.rawValue

    init() {
        let initialTab = AppSection.home.rawValue
        _tabNavigation = State(initialValue: AppTabNavigationState(selectedTab: initialTab))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear.ignoresSafeArea()
            
            // Nội dung chính
            Group {
                if tabNavigation.selectedTab == AppSection.home.rawValue {
                    DashboardView(cleanerEnabled: $cleanerEnabled)
                } else {
                    GameCatalogView(isTabBarHidden: $isTabBarHidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Thanh Tab Bar nổi (Kính mờ, bo Capsule gọn gàng)
            if !isTabBarHidden {
                floatingTabBar
                    .padding(.bottom, 25)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .tint((AppAccentSpectrum(rawValue: accentRaw) ?? .azure).color)
        .imageScale(.small)
        .apexScreenBackground()
    }

    // MARK: - THANH TAB GỌN GÀNG (EXPANDABLE PILL DESIGN)
    private var floatingTabBar: some View {
        HStack(spacing: 8) {
            tabButton(icon: "house.fill", title: "Trang chủ", tag: AppSection.home.rawValue)
            tabButton(icon: "lock.shield.fill", title: "Chức năng", tag: AppSection.games.rawValue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark) // Ép kính mờ tối màu
                .overlay(Capsule().stroke(Color.cyan.opacity(0.4), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
        )
    }

    private func tabButton(icon: String, title: String, tag: Int) -> some View {
        let isSelected = tabNavigation.selectedTab == tag
        
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.5)) {
                tabNavigation.select(tag)
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isSelected ? .bold : .medium))
                
                // Chỉ hiện chữ khi Tab được chọn -> Rất gọn gàng
                if isSelected {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                }
            }
            .foregroundColor(isSelected ? .cyan : .white.opacity(0.6))
            .padding(.horizontal, isSelected ? 18 : 12)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? Color.cyan.opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - HOME DASHBOARD
private struct DashboardView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var showSettings = false
    @State private var licenseKeyCopied = false
    @StateObject private var catalogStore = GameCatalogStore.shared
    @Binding var cleanerEnabled: Bool
    @AppStorage(AppThemePreferences.accentStorageKey) private var accentRaw = AppThemePreferences.defaultAccent.rawValue

    // TỐI ƯU: Khởi tạo DateFormatter 1 lần duy nhất để tránh tràn RAM khi TimelineView chạy mỗi giây
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        return formatter
    }()

    private var accent: AppAccentSpectrum {
        AppAccentSpectrum(rawValue: accentRaw) ?? .azure
    }
    
    // State cho hiệu ứng nhịp thở
    @State private var isBreathing = false

    var body: some View {
        NavigationStack {
            ZStack {
                RemoteAppBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        heroCard
                        licenseMiniWidget
                        deviceCard
                        socialCard
                        
                        // Spacer đẩy nội dung lên để không bị Tab bar che khuất
                        Spacer().frame(height: 80)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .background(Color.clear)
            }
            .apexScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(accent.color)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().environmentObject(appState)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            }
        }
    }

    private var heroCard: some View {
        VStack(spacing: 12) {
            CachedRemoteImage(url: catalogStore.catalog.brandAvatarURL.flatMap(URL.init(string:))) {
                AppLogo(size: 100)
            }
            .scaledToFill()
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(LinearGradient(colors: [accent.color, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
            )
            .shadow(color: accent.color.opacity(isBreathing ? 0.6 : 0.2), radius: isBreathing ? 15 : 5, x: 0, y: 5)

            Text(catalogStore.catalog.brandTitle ?? "Sovereign Solitude")
                .font(.title2.weight(.black))
                .tracking(1)
            
            Text(catalogStore.catalog.brandSubtitle ?? language.text("dashboard.tagline"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .apexCard()
    }

    private var licenseMiniWidget: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let remainingTime = calculateRemainingTime(from: authManager.expireDate, currentDate: context.date)
            
            HStack(spacing: 12) {
                // TỐI ƯU VÀ SỬA LỖI: Kiểm tra phiên bản iOS để dùng symbolEffect an toàn
                Group {
                    if #available(iOS 17.0, *) {
                        Image(systemName: "clock.badge.checkmark.fill")
                            .font(.title2)
                            .foregroundStyle(accent.color)
                            .symbolEffect(.pulse, options: .repeating, isActive: remainingTime != "Hết Hạn")
                    } else {
                        // Fallback cho iOS 16 trở xuống
                        Image(systemName: "clock.badge.checkmark.fill")
                            .font(.title2)
                            .foregroundStyle(accent.color)
                            .opacity(isBreathing && remainingTime != "Hết Hạn" ? 0.6 : 1.0)
                    }
                }
                
                Text(remainingTime)
                    .font(.system(.body, design: .monospaced).weight(.bold))
                    .foregroundColor(remainingTime == "Hết Hạn" ? .red : .primary)
                
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
                    HStack(spacing: 6) {
                        Image(systemName: licenseKeyCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                        Text(licenseKeyCopied ? "Đã chép" : "Copy Key")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(licenseKeyCopied ? .white : accent.color)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(licenseKeyCopied ? Color.green : Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground).opacity(0.6))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(accent.color.opacity(0.3), lineWidth: 1.5))
            )
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
        
        return days > 0 ? "\(days) ngày \(hrs) giờ" : (hrs > 0 ? String(format: "%02d:%02d:%02d", hrs, mins, secs) : String(format: "%02d:%02d", mins, secs))
    }

    private var deviceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: language.text("common.device"), systemImage: "iphone.gen3")
            metricRow(title: language.text("settings.device"), value: AppInfo.hardwareDisplayName)
            Divider().opacity(0.5)
            metricRow(title: language.text("settings.ios_version"), value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))")
            Divider().opacity(0.5)
            HStack {
                Text(language.text("settings.compatibility")).foregroundStyle(.secondary)
                Spacer()
                StatusBadge(text: language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"), tone: appState.isSupported ? .success : .danger)
            }
        }
        .padding(.vertical, 4)
        .apexCard()
    }

    private var socialCard: some View {
        linkCard(title: language.text("settings.social_media"), icon: "bubble.left.and.bubble.right.fill", rows: catalogStore.catalog.resolvedSocialLinks)
    }

    private func linkCard(title: String, icon: String, rows: [RemoteProfileLink]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader(title: title, systemImage: icon).padding(.bottom, 6)
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { Divider().opacity(0.4).padding(.vertical, 4) }
                Button {
                    if let url = URL(string: row.url) { UIApplication.shared.open(url) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "link.circle.fill")
                            .font(.title2)
                            .foregroundStyle(accent.color)
                            
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                            Text(row.role).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }.apexCard()
    }

    private func sectionHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent.color)
            Text(title).font(.subheadline.weight(.bold))
            Spacer()
        }
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).font(.body.weight(.semibold)).multilineTextAlignment(.trailing)
        }
    }
}
