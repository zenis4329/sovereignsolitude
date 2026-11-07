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

    // MARK: - THANH TAB BAR (EXPANDABLE PILL - KÍNH MỜ)
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
                .environment(\.colorScheme, .dark)
                .overlay(Capsule().stroke(LinearGradient(colors: [.cyan.opacity(0.6), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2))
                .shadow(color: Color.cyan.opacity(0.15), radius: 15, x: 0, y: 8)
        )
    }

    private func tabButton(icon: String, title: String, tag: Int) -> some View {
        let isSelected = tabNavigation.selectedTab == tag
        
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.5)) {
                tabNavigation.select(tag)
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isSelected ? .bold : .medium))
                
                if isSelected {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                }
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.5))
            .padding(.horizontal, isSelected ? 20 : 14)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(isSelected ? LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [.clear, .clear], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: isSelected ? .cyan.opacity(0.5) : .clear, radius: 8, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - EXTENSION TẠO HIỆU ỨNG GLASSMORPHISM SIÊU ĐẸP CHO CÁC CARD
extension View {
    func premiumGlassCard() -> some View {
        self
            .padding(20)
            .background(.ultraThinMaterial)
            .environment(\.colorScheme, .dark) // Giữ nền kính mờ tối màu để làm nổi bật chữ trắng/cyan
            .background(Color.black.opacity(0.15))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh")
        return formatter
    }()

    private var accent: AppAccentSpectrum { AppAccentSpectrum(rawValue: accentRaw) ?? .azure }
    
    @State private var isBreathing = false
    @State private var rotationAngle: Double = 0 // Cho viền xoay Avatar

    var body: some View {
        NavigationStack {
            ZStack {
                RemoteAppBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) { // Khoảng cách giữa các thẻ thoáng hơn
                        heroCard
                        licenseMiniWidget
                        deviceCard
                        socialCard
                        
                        Spacer().frame(height: 90) // Tránh tabbar che
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                }
                .background(Color.clear)
            }
            .apexScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .white.opacity(0.8), radius: 5)
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

    // MARK: - AVATAR & TIÊU ĐỀ
    private var heroCard: some View {
        VStack(spacing: 14) {
            // Avatar Viền Xoay Neon
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(gradient: Gradient(colors: [.cyan, .purple, .blue, .cyan]), center: .center),
                        lineWidth: 3.5
                    )
                    .frame(width: 110, height: 110)
                    .shadow(color: .cyan.opacity(0.7), radius: 12)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: rotationAngle)
                    .onAppear { rotationAngle = 360 }

                CachedRemoteImage(url: catalogStore.catalog.brandAvatarURL.flatMap(URL.init(string:))) {
                    AppLogo(size: 98)
                }
                .scaledToFill()
                .frame(width: 98, height: 98)
                .clipShape(Circle())
            }

            VStack(spacing: 4) {
                Text(catalogStore.catalog.brandTitle ?? "Sovereign Solitude")
                    .font(.system(size: 26, weight: .black, design: .serif))
                    .tracking(1.2)
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.6), radius: 8)
                
                Text(catalogStore.catalog.brandSubtitle ?? language.text("dashboard.tagline"))
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - THẺ LICENSE (Kính Mờ)
    private var licenseMiniWidget: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let remainingTime = calculateRemainingTime(from: authManager.expireDate, currentDate: context.date)
            
            HStack(spacing: 14) {
                Group {
                    if #available(iOS 17.0, *) {
                        Image(systemName: "clock.badge.checkmark.fill")
                            .font(.title)
                            .foregroundStyle(.cyan)
                            .symbolEffect(.pulse, options: .repeating, isActive: remainingTime != "Hết Hạn")
                    } else {
                        Image(systemName: "clock.badge.checkmark.fill")
                            .font(.title)
                            .foregroundStyle(.cyan)
                            .opacity(isBreathing && remainingTime != "Hết Hạn" ? 0.6 : 1.0)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Thời Gian Còn Lại")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white.opacity(0.6))
                        .textCase(.uppercase)
                    
                    Text(remainingTime)
                        .font(.system(.title3, design: .monospaced).weight(.black))
                        .foregroundColor(remainingTime == "Hết Hạn" ? .red : .white)
                        .shadow(color: remainingTime == "Hết Hạn" ? .red.opacity(0.5) : .white.opacity(0.5), radius: 5)
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
                    HStack(spacing: 4) {
                        Image(systemName: licenseKeyCopied ? "checkmark" : "doc.on.doc.fill")
                        if licenseKeyCopied {
                            Text("Đã chép").font(.caption.weight(.bold))
                        }
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, licenseKeyCopied ? 12 : 14)
                    .padding(.vertical, 12)
                    .background(
                        licenseKeyCopied 
                        ? LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing) 
                        : LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(12)
                    .shadow(color: licenseKeyCopied ? .green.opacity(0.5) : .cyan.opacity(0.5), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
            .premiumGlassCard() // Gọi hàm Kính mờ siêu đẹp
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

    // MARK: - THẺ THÔNG TIN THIẾT BỊ
    private var deviceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: language.text("common.device"), systemImage: "iphone.gen3")
            
            VStack(spacing: 12) {
                metricRow(title: language.text("settings.device"), value: AppInfo.hardwareDisplayName)
                Divider().background(Color.white.opacity(0.2))
                metricRow(title: language.text("settings.ios_version"), value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))")
                Divider().background(Color.white.opacity(0.2))
                
                HStack {
                    Text(language.text("settings.compatibility")).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    // Huy hiệu Status xanh lá/đỏ
                    Text(language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"))
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(appState.isSupported ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                        .cornerRadius(8)
                }
            }
        }
        .premiumGlassCard()
    }

    // MARK: - THẺ MẠNG XÃ HỘI
    private var socialCard: some View {
        linkCard(title: language.text("settings.social_media"), icon: "network", rows: catalogStore.catalog.resolvedSocialLinks)
    }

    private func linkCard(title: String, icon: String, rows: [RemoteProfileLink]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: title, systemImage: icon)
            
            VStack(spacing: 14) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Divider().background(Color.white.opacity(0.2)) }
                    Button {
                        if let url = URL(string: row.url) { UIApplication.shared.open(url) }
                    } label: {
                        HStack(spacing: 14) {
                            // Icon Link dạng vòng tròn nổi bật
                            ZStack {
                                Circle().fill(Color.cyan.opacity(0.2)).frame(width: 36, height: 36)
                                Image(systemName: "link")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.cyan)
                            }
                                
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.name).font(.body.weight(.bold)).foregroundColor(.white)
                                Text(row.role).font(.caption.weight(.medium)).foregroundColor(.white.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .premiumGlassCard()
    }

    // MARK: - COMPONENT DÙNG CHUNG
    private func sectionHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3.weight(.bold))
                .foregroundStyle(.cyan)
                .shadow(color: .cyan.opacity(0.6), radius: 5)
            
            Text(title)
                .font(.headline.weight(.black))
                .foregroundColor(.white)
            Spacer()
        }
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(.white.opacity(0.7))
            Spacer(minLength: 12)
            Text(value)
                .font(.body.weight(.bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - GIAO DIỆN THÔNG BÁO MỚI (ĐÃ ĐÍNH KÈM)
struct NoticeBannerView: View {
    let onDismiss: () -> Void
    let onSnoozeOneHour: () -> Void
    
    @StateObject private var authManager = CustomAuthManager.shared
    @StateObject private var store = GameCatalogStore.shared
    
    // Lấy nội dung thông báo từ config
    private var noticeMessage: String {
        let msg = store.catalog.noticeMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        return msg.isEmpty ? "Chúc Anh Em Chơi Game Vui Vẻ 🥰" : msg
    }
    
    var body: some View {
        ZStack {
            // Lớp nền tối mờ đè lên toàn bộ app
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    // Không cho phép tắt bằng cách chạm ra ngoài
                }
            
            // KHUNG THÔNG BÁO (GLASSMORPHISM)
            VStack(spacing: 20) {
                
                // 1. HEADER: AVATAR & TÊN APP
                VStack(spacing: 12) {
                    ZStack {
                        // Hào quang phát sáng
                        Circle()
                            .fill(Color(hex: "#00f2fe").opacity(0.3))
                            .frame(width: 90, height: 90)
                            .blur(radius: 15)
                        
                        // Vòng viền Neon
                        Circle()
                            .stroke(
                                LinearGradient(colors: [Color(hex: "#00f2fe"), Color(hex: "#4facfe"), .white], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 2.5
                            )
                            .frame(width: 76, height: 76)
                            .shadow(color: Color(hex: "#00f2fe").opacity(0.8), radius: 8)
                        
                        // Avatar
                        SecureRemoteImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                            .frame(width: 68, height: 68)
                            .clipShape(Circle())
                    }
                    
                    // Tên App
                    Text("𝐒𝐨𝐯𝐞𝐫𝐞𝐢𝐠𝐧 𝐒𝐨𝐥𝐢𝐭𝐮𝐝𝐞")
                        .font(.system(size: 22, weight: .black, design: .serif))
                        .foregroundColor(.white)
                        .shadow(color: Color(hex: "#00f2fe").opacity(0.6), radius: 8)
                    
                    // Tiêu đề Thông báo
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                            .shadow(color: .green, radius: 4)
                        Text("THÔNG BÁO HỆ THỐNG")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "#00f2fe"))
                            .tracking(1.5)
                    }
                }
                .padding(.top, 10)
                
                // 2. NỘI DUNG THÔNG BÁO
                ScrollView(.vertical, showsIndicators: false) {
                    Text(noticeMessage)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: 150)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                
                // 3. CÁC NÚT BẤM
                VStack(spacing: 12) {
                    // Nút OK
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onDismiss()
                    }) {
                        Text("OK")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(colors: [Color(hex: "#00f2fe"), Color(hex: "#4facfe")], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(14)
                            .shadow(color: Color(hex: "#00f2fe").opacity(0.4), radius: 8, y: 4)
                    }
                    
                    // Nút Ẩn 1 Giờ
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSnoozeOneHour()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("HIDE FOR 1H")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding(.bottom, 10)
                
            }
            .padding(24)
            .background(
                // Nền kính mờ (Glassmorphism)
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                    
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#00f2fe").opacity(0.15), Color.black.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            // Viền phát sáng
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#00f2fe").opacity(0.8), Color.white.opacity(0.2), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
            .shadow(color: Color(hex: "#00f2fe").opacity(0.2), radius: 15)
            .padding(.horizontal, 24)
        }
    }
}
