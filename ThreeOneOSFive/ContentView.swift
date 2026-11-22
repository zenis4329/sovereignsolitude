import SwiftUI
import UIKit
import AudioToolbox

// ==========================================================
// MARK: - NỀN APP (ẢNH NỀN + HIỆU ỨNG CHUYỂN ĐỘNG)
// ==========================================================
struct AppDynamicBackground: View {
    let urlString: String
    
    var body: some View {
        ZStack {
            // 1. Ảnh nền App (từ Server)
            SecureRemoteImage(urlString: urlString, placeholder: Image(systemName: "photo"))
                .scaledToFill()
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .opacity(0.6)
            
            // 2. Lớp phủ Gradient tối
            LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color(red: 0.03, green: 0.04, blue: 0.08).opacity(0.85),
                    Color.black.opacity(0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // 3. Aurora Waves
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    let colors: [Color] = [.cyan, .purple, .blue]
                    for i in 0..<3 {
                        var path = Path()
                        let phase = Double(i) * 2.2
                        let amplitude = size.height * 0.08
                        let yBase = size.height * (0.35 + Double(i) * 0.2)
                        path.move(to: CGPoint(x: 0, y: yBase))
                        for x in stride(from: 0, through: size.width, by: 6) {
                            let y = yBase + sin((Double(x) / 150) + t * 0.4 + phase) * amplitude
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        path.addLine(to: CGPoint(x: size.width, y: size.height))
                        path.addLine(to: CGPoint(x: 0, y: size.height))
                        path.closeSubpath()
                        ctx.fill(path, with: .color(colors[i].opacity(0.08)))
                    }
                }
            }
            .blur(radius: 40)
            
            // 4. Bụi sáng
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    for i in 0..<15 {
                        let x = (Double(i) * 137.5 + t * 15).truncatingRemainder(dividingBy: Double(size.width))
                        let y = (Double(i) * 73.3 + t * 8).truncatingRemainder(dividingBy: Double(size.height))
                        let r = CGFloat(1 + (i % 3))
                        let alpha = 0.2 + 0.4 * sin(t + Double(i))
                        let rect = CGRect(x: x, y: y, width: r, height: r)
                        ctx.fill(Ellipse().path(in: rect), with: .color(.cyan.opacity(alpha)))
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// ==========================================================
// MARK: - VIEW MODIFIER (⚠️ ĐÃ XOÁ ClassicScaleButtonStyle vì trùng)
// ==========================================================
extension View {
    func premiumGlassCard() -> some View {
        self
            .padding(18)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                    
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(colors: [Color.black.opacity(0.3), Color.black.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.5), Color.white.opacity(0.1), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .shadow(color: Color.cyan.opacity(0.15), radius: 15, x: 0, y: 8)
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
            // ✅ FIX: Dùng authManager.publicBackgroundURL thay vì catalog.backgroundURL
            AppDynamicBackground(urlString: authManager.publicBackgroundURL)
            
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
                .overlay(
                    Capsule().stroke(
                        LinearGradient(colors: [.cyan.opacity(0.6), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 1.2
                    )
                )
                .shadow(color: .cyan.opacity(0.2), radius: 20, x: 0, y: 10)
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
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                            .matchedGeometryEffect(id: "TAB_BG", in: tabAnimation)
                            .shadow(color: .cyan.opacity(0.6), radius: 10, x: 0, y: 4)
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
    @State private var rotationAngle: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    heroSection
                    licenseCard
                    
                    HStack(alignment: .top, spacing: 14) {
                        deviceCard
                            .frame(maxWidth: .infinity)
                        
                        socialGrid
                            .frame(maxWidth: .infinity)
                    }
                    
                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .cyan.opacity(0.8), radius: 5)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().environmentObject(appState)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            }
        }
    }

    // MARK: - 1. HERO SECTION
    private var heroSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.3))
                    .frame(width: 110, height: 110)
                    .blur(radius: 25)
                    .scaleEffect(isBreathing ? 1.15 : 0.9)
                
                TimelineView(.animation) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { ctx, size in
                        let center = CGPoint(x: size.width/2, y: size.height/2)
                        for i in 0..<8 {
                            let angle = t * 0.8 + Double(i) * (.pi * 2 / 8)
                            let radius: CGFloat = 54
                            let x = center.x + CGFloat(cos(angle)) * radius
                            let y = center.y + CGFloat(sin(angle)) * radius
                            let rect = CGRect(x: x - 2, y: y - 2, width: 4, height: 4)
                            ctx.fill(Ellipse().path(in: rect), with: .color(.cyan))
                        }
                    }
                }
                .frame(width: 120, height: 120)
                
                Circle()
                    .stroke(AngularGradient(colors: [.cyan, .purple, .blue, .cyan], center: .center), lineWidth: 3)
                    .frame(width: 96, height: 96)
                    .rotationEffect(.degrees(rotationAngle))
                    .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: rotationAngle)
                    .onAppear { rotationAngle = 360 }

                CachedRemoteImage(url: catalogStore.catalog.brandAvatarURL.flatMap(URL.init(string:))) {
                    AppLogo(size: 86)
                }
                .scaledToFill()
                .frame(width: 86, height: 86)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
            .frame(height: 130)

            VStack(spacing: 6) {
                Text(catalogStore.catalog.brandTitle ?? "Sovereign Solitude")
                    .font(.system(size: 24, weight: .black, design: .serif))
                    .tracking(1.2)
                    .foregroundColor(.white)
                    .shadow(color: .cyan.opacity(0.5), radius: 10)
                
                HStack(spacing: 6) {
                    Circle().fill(Color.green).frame(width: 6, height: 6).shadow(color: .green, radius: 4)
                    Text(catalogStore.catalog.brandSubtitle ?? language.text("dashboard.tagline"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(.top, 10)
    }

    // MARK: - 2. LICENSE CARD
    private var licenseCard: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let remainingTime = calculateRemainingTime(from: authManager.expireDate, currentDate: context.date)
            
            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg").foregroundColor(.cyan)
                        Text("DIGITAL LICENSE").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    if remainingTime != "Hết Hạn" {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 5, height: 5)
                            Text("ACTIVE").font(.system(size: 9, weight: .bold)).foregroundColor(.green)
                        }
                    }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Thời Gian Còn Lại").font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.5))
                        Text(remainingTime)
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundColor(remainingTime == "Hết Hạn" ? .red : .white)
                    }
                    
                    Spacer()
                    
                    Button {
                        UIPasteboard.general.string = authManager.savedKey
                        withAnimation { licenseKeyCopied = true }
                        AudioServicesPlaySystemSound(1104)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { licenseKeyCopied = false } }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: licenseKeyCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            Text(licenseKeyCopied ? "Đã chép" : "Copy")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(LinearGradient(colors: licenseKeyCopied ? [.green, .mint] : [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(ClassicScaleButtonStyle())
                }
            }
            .premiumGlassCard()
        }
    }

    private func calculateRemainingTime(from dateStr: String, currentDate: Date) -> String {
        guard let expDate = Self.dateFormatter.date(from: dateStr) else { return "Không xác định" }
        let diff = Int(expDate.timeIntervalSince(currentDate))
        if diff <= 0 { return "Hết Hạn" }
        let days = diff / 86400
        let hrs = (diff % 86400) / 3600
        let mins = (diff % 3600) / 60
        return days > 0 ? "\(days) Ngày \(hrs) Giờ" : String(format: "%02d:%02d:%02d", hrs, mins, diff % 60)
    }

    // MARK: - 3. DEVICE CARD
    private var deviceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "iphone.gen3").foregroundColor(.cyan)
                Text("THIẾT BỊ").font(.system(size: 12, weight: .black)).foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                deviceRow(label: "Máy", value: AppInfo.hardwareDisplayName)
                Divider().background(Color.white.opacity(0.1))
                deviceRow(label: "iOS", value: AppInfo.osVersion)
                Divider().background(Color.white.opacity(0.1))
                deviceRow(label: "Hỗ trợ", value: appState.isSupported ? "Có" : "Không", color: appState.isSupported ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumGlassCard()
    }

    private func deviceRow(label: String, value: String, color: Color = .white) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(.white.opacity(0.5))
            Text(value).font(.system(size: 13, weight: .bold)).foregroundColor(color).lineLimit(1)
        }
    }

    // MARK: - 4. SOCIAL GRID
    private var socialGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "network").foregroundColor(.cyan)
                Text("LIÊN KẾT").font(.system(size: 12, weight: .black)).foregroundColor(.white)
            }
            
            VStack(spacing: 10) {
                ForEach(catalogStore.catalog.resolvedSocialLinks.prefix(3), id: \.url) { link in
                    Button {
                        if let url = URL(string: link.url) { UIApplication.shared.open(url) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "link").font(.system(size: 12, weight: .bold)).foregroundColor(.cyan)
                            Text(link.name).font(.system(size: 12, weight: .bold)).foregroundColor(.white).lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.3))
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(ClassicScaleButtonStyle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumGlassCard()
    }
}

// ==========================================================
// MARK: - THÔNG BÁO POPUP
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
            Color.black.opacity(0.85).ignoresSafeArea()
            
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.cyan.opacity(0.3)).frame(width: 90, height: 90).blur(radius: 20)
                        Circle().stroke(LinearGradient(colors: [.cyan, .white, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2.5).frame(width: 76, height: 76).shadow(color: .cyan.opacity(0.8), radius: 8)
                        SecureRemoteImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill")).frame(width: 68, height: 68).clipShape(Circle())
                    }
                    
                    Text("𝐒𝐨𝐯𝐞𝐫𝐞𝐢𝐠𝐧 𝐒𝐨𝐥𝐢𝐭𝐮𝐝𝐞")
                        .font(.system(size: 22, weight: .black, design: .serif))
                        .foregroundColor(.white).shadow(color: .cyan.opacity(0.6), radius: 8)
                    
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 6, height: 6).shadow(color: .green, radius: 4)
                        Text("THÔNG BÁO HỆ THỐNG")
                            .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.cyan).tracking(1.5)
                    }
                }
                .padding(.top, 10)
                
                ScrollView(.vertical, showsIndicators: false) {
                    Text(noticeMessage)
                        .font(.system(size: 15, weight: .medium)).foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center).lineSpacing(4).padding(.horizontal, 10).frame(maxWidth: .infinity)
                }
                .frame(maxHeight: 150).padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.4)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1)))
                
                VStack(spacing: 12) {
                    Button(action: { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); onDismiss() }) {
                        Text("OK").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(14).shadow(color: .cyan.opacity(0.4), radius: 8, y: 4)
                    }
                    Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); onSnoozeOneHour() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("HIDE FOR 1H")
                        }.font(.system(size: 14, weight: .bold)).foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color.white.opacity(0.1)).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                }.padding(.bottom, 10)
            }
            .padding(24)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 28).fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
                    RoundedRectangle(cornerRadius: 28).fill(LinearGradient(colors: [Color.cyan.opacity(0.15), Color.black.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            )
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(LinearGradient(colors: [Color.cyan.opacity(0.8), Color.white.opacity(0.2), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.5), radius: 30, y: 15).shadow(color: Color.cyan.opacity(0.2), radius: 15)
            .padding(.horizontal, 24)
            .scaleEffect(showContent ? 1 : 0.8).opacity(showContent ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showContent = true }
        }
    }
}
