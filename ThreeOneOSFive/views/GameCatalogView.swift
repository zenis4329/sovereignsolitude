import SwiftUI
import UIKit
import AudioToolbox

// MARK: - ÂM THANH "TÍCH" GỐC CỦA HỆ THỐNG IPHONE + TAPTIC ENGINE (0ms LAG)
enum iPhoneNativeFeedback {
    /// Tiếng "Tích" chuẩn iPhone (System Sound 1057 - Tink.caf) + Rung xác nhận
    static func tickOn() {
        AudioServicesPlaySystemSound(1057)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    /// Tiếng "Tock" trầm nhẹ khi tắt chức năng
    static func tickOff() {
        AudioServicesPlaySystemSound(1105)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Tiếng chạm phím iOS chuẩn khi chuyển tab / mở popup
    static func tap() {
        AudioServicesPlaySystemSound(1104)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }
    
    /// Tiếng xác nhận mạnh khi khởi động game
    static func launch() {
        AudioServicesPlaySystemSound(1057)
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
}

// MARK: - CACHE ẢNH RAM SIÊU TỐC
final class CatalogImageCache {
    static let shared = NSCache<NSString, UIImage>()
}

struct SecureCatalogImage: View {
    let urlString: String
    let placeholder: Image
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.clear
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            } else {
                placeholder
                    .resizable()
                    .scaledToFit()
                    .padding(10)
                    .foregroundColor(.white.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.75)
                            .opacity(isLoading ? 1 : 0)
                    )
            }
        }
        .clipped()
        .onAppear { loadImage() }
        .onChange(of: urlString) { _ in
            image = nil
            isLoading = true
            loadImage()
        }
    }
    
    private func loadImage() {
        let cleanUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUrl.isEmpty else {
            isLoading = false
            return
        }
        if let cached = CatalogImageCache.shared.object(forKey: cleanUrl as NSString) {
            self.image = cached
            self.isLoading = false
            return
        }
        guard !SecureNetworkManager.shared.isProxyEnabled(), let url = URL(string: cleanUrl) else {
            isLoading = false
            return
        }
        SecureNetworkManager.shared.createSecureSession().dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                if let data = data, let uiImage = UIImage(data: data) {
                    CatalogImageCache.shared.setObject(uiImage, forKey: cleanUrl as NSString)
                    withAnimation { self.image = uiImage }
                }
                self.isLoading = false
            }
        }.resume()
    }
}

// MARK: - MÀN HÌNH CHÍNH (OBSIDIAN GLASS COMMAND DECK)
struct GameCatalogView: View {
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @Binding var isTabBarHidden: Bool
    
    @State private var isRotating = false
    @State private var auroraPulse = false
    
    private var isSessionActive: Bool {
        authManager.isAuthorized
        && !authManager.isInteractionLocked
        && !store.catalog.resolvedMaintenanceEnabled
    }
    
    private var totalEnabledMods: Int {
        store.catalog.orderedGames.reduce(0) { partial, game in
            partial + game.items.filter { $0.hidden != true && store.isMultiItemOn(item: $0) }.count
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // BACKGROUND ẢNH MỜ SÂU
                GeometryReader { geo in
                    SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "sparkles"))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .opacity(0.42)
                        .overlay(
                            LinearGradient(
                                colors: [Color.black.opacity(0.4), Color.black.opacity(0.86), Color.black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .ignoresSafeArea()
                
                // QUẦNG SÁNG AURORA THỞ NHẸ (GPU OPTIMAL)
                Circle()
                    .fill(Color.cyan.opacity(auroraPulse ? 0.16 : 0.08))
                    .frame(width: 300, height: 300)
                    .blur(radius: 90)
                    .offset(x: -100, y: -240)
                    .allowsHitTesting(false)
                
                Circle()
                    .fill(Color.indigo.opacity(auroraPulse ? 0.18 : 0.1))
                    .frame(width: 280, height: 280)
                    .blur(radius: 95)
                    .offset(x: 120, y: 260)
                    .allowsHitTesting(false)
                
                // NỀN HẠT ÁNH SÁNG 60FPS
                ObsidianParticleCanvas()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // HERO BENTO CARD GỘP TRẠNG THÁI + AVATAR + THƯƠNG HIỆU
                        VStack(spacing: 14) {
                            HStack {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6.5, height: 6.5)
                                        .shadow(color: .green, radius: 5)
                                    Text("ONLINE")
                                        .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                        .tracking(1.1)
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                                
                                Spacer()
                                
                                if totalEnabledMods > 0 {
                                    Button {
                                        iPhoneNativeFeedback.tickOff()
                                        store.disableAllEnabledMods()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "power")
                                                .font(.system(size: 9, weight: .black))
                                            Text("TẮT HẾT (\(totalEnabledMods))")
                                                .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                        }
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4.5)
                                        .background(LinearGradient(colors: [.white, .cyan], startPoint: .leading, endPoint: .trailing))
                                        .clipShape(Capsule())
                                        .shadow(color: .cyan.opacity(0.5), radius: 6)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Text("READY")
                                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                        .tracking(1)
                                        .foregroundColor(.cyan)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4)
                                        .background(Color.cyan.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                            
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .stroke(
                                            AngularGradient(colors: [.white, .cyan, .clear, .white], center: .center),
                                            lineWidth: 2.2
                                        )
                                        .frame(width: 74, height: 74)
                                        .rotationEffect(.degrees(isRotating ? 360 : 0))
                                        .animation(.linear(duration: 4.5).repeatForever(autoreverses: false), value: isRotating)
                                        .drawingGroup()
                                    
                                    SecureCatalogImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                                        .frame(width: 66, height: 66)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(authManager.publicAppName.isEmpty ? "𝐒𝐨𝐯𝐞𝐫𝐞𝐢𝐠𝐧 𝐒𝐨𝐥𝐢𝐭𝐮𝐝𝐞" : authManager.publicAppName)
                                        .font(.system(size: 21, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .shadow(color: .cyan.opacity(0.35), radius: 8)
                                    
                                    Text("Bảng điều khiển tối ưu • Chạm game để mở")
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundColor(.white.opacity(0.55))
                                        .lineLimit(1)
                                }
                                
                                Spacer(minLength: 0)
                            }
                        }
                        .padding(15)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(.ultraThinMaterial)
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.01)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        )
                        .environment(\.colorScheme, .dark)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.35), Color.cyan.opacity(0.3), Color.white.opacity(0.06)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.1
                                )
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // TIÊU ĐỀ DANH SÁCH GAME
                        HStack {
                            Text("ỨNG DỤNG KHẢ DỤNG")
                                .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                                .tracking(1.4)
                                .foregroundColor(.white.opacity(0.55))
                            Spacer()
                            Text("\(store.catalog.orderedGames.count)")
                                .font(.system(size: 10.5, weight: .black, design: .monospaced))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.14))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, -6)
                        
                        // DANH SÁCH GAME
                        VStack(spacing: 12) {
                            if store.catalog.orderedGames.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "gamecontroller")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white.opacity(0.35))
                                    Text("Chưa có trò chơi nào được cấu hình")
                                        .font(.system(size: 13.5, weight: .medium))
                                        .foregroundColor(.white.opacity(0.55))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 22))
                                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.12), lineWidth: 1))
                                .padding(.horizontal, 16)
                            } else {
                                ForEach(store.catalog.orderedGames) { game in
                                    NavigationLink(destination: GameDetailView(gameID: game.id, isTabBarHidden: $isTabBarHidden)) {
                                        ObsidianGameCard(game: game)
                                    }
                                    .buttonStyle(TactileBounceStyle())
                                    .disabled(!isSessionActive)
                                    .simultaneousGesture(TapGesture().onEnded {
                                        guard isSessionActive else { return }
                                        iPhoneNativeFeedback.tap()
                                        withAnimation(.easeInOut(duration: 0.2)) { isTabBarHidden = true }
                                    })
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.bottom, 110)
                    }
                }
                .disabled(!isSessionActive)
                .allowsHitTesting(isSessionActive)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                isRotating = true
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    auroraPulse = true
                }
                store.rememberCatalogItems()
                if !authManager.isAuthorized || store.catalog.resolvedMaintenanceEnabled {
                    store.disableAllEnabledMods()
                }
            }
            .onChange(of: store.catalog.games.count) { _ in
                store.rememberCatalogItems()
            }
            .onChange(of: authManager.isAuthorized) { authorized in
                if !authorized {
                    isTabBarHidden = false
                    store.disableAllEnabledMods()
                }
            }
            .onChange(of: store.catalog.resolvedMaintenanceEnabled) { isMaintenance in
                if isMaintenance {
                    isTabBarHidden = false
                    store.disableAllEnabledMods()
                }
            }
        }
    }
}

// MARK: - THẺ GAME TRÊN MÀN HÌNH CHÍNH
private struct ObsidianGameCard: View {
    let game: GameCatalogGame
    @StateObject private var store = GameCatalogStore.shared
    
    private var activeVisibleItemsCount: Int {
        game.items.filter { $0.hidden != true }.count
    }
    
    private var enabledModCount: Int {
        game.items
            .filter { $0.hidden != true }
            .filter { store.isMultiItemOn(item: $0) }
            .count
    }
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                SecureCatalogImage(urlString: game.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 17))
                    .overlay(
                        RoundedRectangle(cornerRadius: 17)
                            .stroke(
                                LinearGradient(colors: [.white.opacity(0.5), .cyan.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1.3
                            )
                    )
                    .shadow(color: .cyan.opacity(0.25), radius: 8)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(game.name)
                    .font(.system(size: 17.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label("\(activeVisibleItemsCount) tính năng", systemImage: "square.grid.2x2")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.58))
                    
                    if enabledModCount > 0 {
                        Text("• \(enabledModCount) bật")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 5) {
                Text("MỞ")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .black))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 13)
            .padding(.vertical, 8.5)
            .background(LinearGradient(colors: [.white, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(Capsule())
            .shadow(color: .cyan.opacity(0.45), radius: 8)
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.07), Color.white.opacity(0.015)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.32), Color.cyan.opacity(0.35), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.1
                )
        )
    }
}

// MARK: - HIỆU ỨNG NHÚN TACTILE KHI CHẠM
struct TactileBounceStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

// MARK: - NỀN HẠT ÁNH SÁNG 60FPS NHẸ MÁY
struct ObsidianParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var speed: CGFloat
    var opacity: Double
    var isCyan: Bool
}

struct ObsidianParticleCanvas: View {
    @State private var particles: [ObsidianParticle] = []
    
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    for p in particles {
                        let yPos = (p.y + CGFloat(time) * p.speed).truncatingRemainder(dividingBy: size.height + 40)
                        let xPos = p.x + sin(CGFloat(time) * 1.15 + p.y * 0.04) * 10
                        context.opacity = p.opacity
                        let rect = CGRect(x: xPos, y: yPos, width: p.size, height: p.size)
                        context.fill(Path(ellipseIn: rect), with: .color(p.isCyan ? .cyan : .white))
                    }
                }
            }
            .onAppear {
                guard particles.isEmpty else { return }
                for i in 0..<24 {
                    particles.append(
                        ObsidianParticle(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height),
                            size: CGFloat.random(in: 1.5...3.4),
                            speed: CGFloat.random(in: 14...28),
                            opacity: Double.random(in: 0.16...0.52),
                            isCyan: i % 3 == 0
                        )
                    )
                }
            }
        }
    }
}

// MARK: - MÀN HÌNH CHI TIẾT GAME (LƯỚI BENTO SIÊU GỌN - HIỆN 8-10 MỤC CÙNG LÚC)
private struct GameDetailView: View {
    let gameID: String
    @Binding var isTabBarHidden: Bool
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var selectedTabID = "aim"
    @State private var searchText = ""
    @State private var showSearchBar = false
    @State private var onlyActiveFilter = false
    @Namespace private var tabNamespace
    @Environment(\.dismiss) private var dismiss

    private var catalog: GameCatalog { store.catalog }
    private var game: GameCatalogGame? { catalog.games.first(where: { $0.id == gameID }) }
    
    private var isSessionActive: Bool {
        authManager.isAuthorized
        && !authManager.isInteractionLocked
        && !store.catalog.resolvedMaintenanceEnabled
    }
    
    private var items: [GameCatalogItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return (game?.items ?? [])
            .filter { $0.hidden != true && $0.category.rawValue == selectedTabID }
            .filter { item in
                if onlyActiveFilter && !store.isMultiItemOn(item: item) { return false }
                if q.isEmpty { return true }
                return item.name.lowercased().contains(q)
                    || (item.subtitle ?? "").lowercased().contains(q)
            }
            .sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
    }
    
    private var activeCountInGame: Int {
        (game?.items ?? [])
            .filter { $0.hidden != true && store.isMultiItemOn(item: $0) }
            .count
    }
    
    private var availableTabs: [GameCatalogTab] {
        let fallbackTabs: [GameCatalogTab] = catalog.resolvedTabs
        guard let game else { return fallbackTabs }
        let ownTabs = game.resolvedTabs(fallback: fallbackTabs)
        guard let selected = game.tabIDs else { return ownTabs }
        return ownTabs.filter { selected.contains($0.id) }
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 9),
        GridItem(.flexible(), spacing: 9)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            GeometryReader { geo in
                SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "photo"))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.36)
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.5), Color.black.opacity(0.9), Color.black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .ignoresSafeArea()
            
            VStack(spacing: 10) {
                // 1. HEADER SIÊU GỌN
                HStack(spacing: 10) {
                    Button {
                        iPhoneNativeFeedback.tap()
                        withAnimation(.easeInOut(duration: 0.2)) { isTabBarHidden = false }
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(game?.name ?? "Danh sách Mod")
                            .font(.system(size: 17.5, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        HStack(spacing: 5) {
                            Circle()
                                .fill(activeCountInGame > 0 ? Color.cyan : Color.white.opacity(0.35))
                                .frame(width: 5.5, height: 5.5)
                            Text(activeCountInGame > 0 ? "Đang bật \(activeCountInGame) tính năng" : "Chạm ô để kích hoạt")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(activeCountInGame > 0 ? .cyan : .white.opacity(0.5))
                        }
                    }
                    
                    Spacer()
                    
                    // Nút tắt nhanh toàn bộ khi đang bật >= 1 mod
                    if activeCountInGame > 0 {
                        Button {
                            iPhoneNativeFeedback.tickOff()
                            store.disableAllEnabledMods()
                        } label: {
                            Text("Tắt hết")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.red.opacity(0.28))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.red.opacity(0.55), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Nút lọc "Đang bật"
                    Button {
                        iPhoneNativeFeedback.tap()
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                            onlyActiveFilter.toggle()
                        }
                    } label: {
                        Text("\(activeCountInGame)")
                            .font(.system(size: 11.5, weight: .black, design: .monospaced))
                            .foregroundColor(onlyActiveFilter ? .black : .cyan)
                            .frame(width: 34, height: 34)
                            .background(onlyActiveFilter ? Color.cyan : Color.cyan.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.cyan.opacity(0.45), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    // Nút tìm kiếm nhanh
                    Button {
                        iPhoneNativeFeedback.tap()
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                            showSearchBar.toggle()
                            if !showSearchBar { searchText = "" }
                        }
                    } label: {
                        Image(systemName: showSearchBar ? "xmark" : "magnifyingglass")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 15)
                .padding(.top, 8)
                
                // THANH TÌM KIẾM THU GỌN
                if showSearchBar {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(.cyan)
                        TextField("Tìm tên tính năng...", text: $searchText)
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .tint(.cyan)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.45))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .padding(.horizontal, 15)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // 2. THANH TAB VIÊN THUỐC CÂN ĐỐI (KHÔNG TRÀN MÀN HÌNH)
                Group {
                    if availableTabs.count <= 3 {
                        HStack(spacing: 4) {
                            ForEach(availableTabs) { tab in
                                tabPillView(tab: tab, stretch: true)
                            }
                        }
                        .padding(3.5)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                        .padding(.horizontal, 15)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(availableTabs) { tab in
                                    tabPillView(tab: tab, stretch: false)
                                }
                            }
                            .padding(.horizontal, 15)
                        }
                    }
                }
                
                // 3. LƯỚI BENTO 2 CỘT SIÊU GỌN (8–10 Ô TRÊN 1 MÀN HÌNH)
                ScrollView(showsIndicators: false) {
                    if items.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "tray")
                                .font(.system(size: 26))
                                .foregroundColor(.white.opacity(0.3))
                            Text(onlyActiveFilter ? "Chưa có tính năng nào đang bật" : "Chưa có chức năng trong mục này")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 44)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .padding(.horizontal, 15)
                        .padding(.top, 8)
                    } else {
                        LazyVGrid(columns: columns, spacing: 9) {
                            ForEach(items) { item in
                                CompactObsidianTile(item: item)
                            }
                        }
                        .padding(.horizontal, 15)
                        .padding(.top, 2)
                        .padding(.bottom, 20)
                    }
                }
            }
            // DOCK KHỞI ĐỘNG GAME NỔI GỌN Ở ĐÁY
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    SecureCatalogImage(urlString: game?.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.2))
                    
                    Button {
                        guard isSessionActive else { return }
                        iPhoneNativeFeedback.launch()
                        let rawLaunch = (game?.launchURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if let url = URL(string: rawLaunch), !rawLaunch.isEmpty {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13.5, weight: .black))
                            Text("KHỞI ĐỘNG GAME")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .tracking(0.8)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            LinearGradient(colors: [.white, .cyan], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                        .shadow(color: .cyan.opacity(0.45), radius: 10, y: 3)
                    }
                    .buttonStyle(TactileBounceStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                .padding(.horizontal, 15)
                .padding(.bottom, 4)
            }
        }
        .disabled(!isSessionActive)
        .allowsHitTesting(isSessionActive)
        .navigationBarHidden(true)
        .onAppear {
            store.rememberCatalogItems()
            if store.catalog.resolvedMaintenanceEnabled {
                store.disableAllEnabledMods()
                withAnimation { isTabBarHidden = false }
                dismiss()
                return
            }
            withAnimation { isTabBarHidden = true }
            if !availableTabs.contains(where: { $0.id == selectedTabID }) {
                selectedTabID = availableTabs.first?.id ?? "aim"
            }
        }
        .onDisappear {
            withAnimation { isTabBarHidden = false }
        }
        .onChange(of: authManager.isAuthorized) { authorized in
            if !authorized {
                store.disableAllEnabledMods()
                withAnimation { isTabBarHidden = false }
                dismiss()
            }
        }
        .onChange(of: store.catalog.resolvedMaintenanceEnabled) { isMaintenance in
            if isMaintenance {
                store.disableAllEnabledMods()
                withAnimation { isTabBarHidden = false }
                dismiss()
            }
        }
    }
    
    @ViewBuilder
    private func tabPillView(tab: GameCatalogTab, stretch: Bool) -> some View {
        let isSelected = selectedTabID == tab.id
        Button {
            iPhoneNativeFeedback.tap()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                selectedTabID = tab.id
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .bold))
                Text(tab.title)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(isSelected ? .black : .white.opacity(0.75))
            .frame(maxWidth: stretch ? .infinity : nil)
            .padding(.horizontal, stretch ? 6 : 13)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(LinearGradient(colors: [.white, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .matchedGeometryEffect(id: "TAB_PILL_HIGHLIGHT", in: tabNamespace)
                            .shadow(color: .cyan.opacity(0.45), radius: 6)
                    } else if !stretch {
                        Capsule()
                            .fill(Color.white.opacity(0.07))
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ô CHỨC NĂNG BENTO SIÊU GỌN (SÓNG XUNG KÍCH + QUÉT SÁNG + TIẾNG TÍCH IPHONE)
private struct CompactObsidianTile: View {
    let item: GameCatalogItem
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var showDetailSheet = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var sweepOffset: CGFloat = -150
    @State private var rippleScale: CGFloat = 0.7
    @State private var rippleOpacity: Double = 0.0
    
    private var isSessionActive: Bool {
        authManager.isAuthorized
        && !authManager.isInteractionLocked
        && !store.catalog.resolvedMaintenanceEnabled
    }
    
    private var isVip: Bool {
        item.name.localizedCaseInsensitiveContains("VIP")
        || item.name.localizedCaseInsensitiveContains("AIM HEAD")
        || item.name.localizedCaseInsensitiveContains("CAN CHECK")
    }

    private var badgeLabel: String {
        let custom = (item.badge ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return custom }
        return isVip ? "VIP" : "FREE"
    }

    private var isHighlightedBadge: Bool {
        let custom = (item.badge ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !custom.isEmpty || isVip
    }
    
    private var hasGuide: Bool {
        !(item.usageGuide ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !(item.imageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var subtitleDisplay: String {
        let cleanSub = (item.subtitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanSub.isEmpty ? "Chạm để bật" : cleanSub
    }
    
    var body: some View {
        let hasLink = !item.resolvedFileURLs.isEmpty
        let isOn = store.isMultiItemOn(item: item)
        let busy = store.isMultiItemBusy(item: item)
        
        VStack(alignment: .leading, spacing: 7) {
            // HÀNG TRÊN: NÚT TRẠNG THÁI + SÓNG XUNG KÍCH + BADGE + HDSD
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.cyan, lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                        .scaleEffect(rippleScale)
                        .opacity(rippleOpacity)
                    
                    Circle()
                        .fill(isOn ? Color.cyan : Color.white.opacity(0.09))
                        .frame(width: 24, height: 24)
                    
                    if busy {
                        ProgressView()
                            .tint(isOn ? .black : .cyan)
                            .scaleEffect(0.65)
                    } else {
                        Image(systemName: isOn ? "checkmark" : "power")
                            .font(.system(size: 10.5, weight: .black))
                            .foregroundColor(isOn ? .black : .white.opacity(0.7))
                    }
                }
                
                Text(badgeLabel)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundColor(isHighlightedBadge ? .black : .white.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isHighlightedBadge
                        ? AnyView(LinearGradient(colors: [.white, .cyan], startPoint: .leading, endPoint: .trailing))
                        : AnyView(Color.white.opacity(0.14))
                    )
                    .clipShape(Capsule())
                
                Spacer(minLength: 0)
                
                if hasGuide {
                    Button {
                        iPhoneNativeFeedback.tap()
                        showDetailSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer(minLength: 0)
            
            // HÀNG DƯỚI: TÊN CHỨC NĂNG + TRẠNG THÁI
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(busy ? "Đang nạp..." : (isOn ? "Đang hoạt động" : subtitleDisplay))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(busy ? .yellow : (isOn ? .cyan : .white.opacity(0.45)))
                    .lineLimit(1)
            }
        }
        .padding(10.5)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 17)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 17)
                    .fill(
                        LinearGradient(
                            colors: isOn
                                ? [Color.cyan.opacity(0.24), Color.blue.opacity(0.08)]
                                : [Color.white.opacity(0.05), Color.black.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // DẢI SÁNG SHIMMER QUÉT CHÉO KHI KÍCH HOẠT
                if isOn {
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.38), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 65)
                    .rotationEffect(.degrees(22))
                    .offset(x: sweepOffset)
                    .allowsHitTesting(false)
                }
            }
        )
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 17))
        .overlay(
            RoundedRectangle(cornerRadius: 17)
                .stroke(
                    isOn
                    ? LinearGradient(colors: [.white, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isOn ? 1.4 : 0.9
                )
        )
        .shadow(color: isOn ? .cyan.opacity(0.26) : .clear, radius: 8, y: 3)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !busy, (hasLink || isOn) else { return }
            toggleFeature(currentlyOn: isOn)
        }
        .opacity(hasLink ? 1 : 0.48)
        .animation(.spring(response: 0.24, dampingFraction: 0.74), value: isOn)
        .onChange(of: isOn) { active in
            if active {
                sweepOffset = -140
                rippleScale = 0.85
                rippleOpacity = 0.95
                withAnimation(.easeOut(duration: 0.5)) {
                    sweepOffset = 170
                    rippleScale = 2.0
                    rippleOpacity = 0.0
                }
            }
        }
        .onChange(of: isSessionActive) { active in
            if !active {
                showDetailSheet = false
                showErrorAlert = false
            }
        }
        .sheet(isPresented: $showDetailSheet) {
            ModDetailSheet(item: item)
        }
        .alert("Lỗi kích hoạt Mod", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func toggleFeature(currentlyOn: Bool) {
        if currentlyOn {
            iPhoneNativeFeedback.tickOff()
            Task { await store.setMultiEnabled(false, item: item) }
            return
        }
        
        guard isSessionActive else { return }
        
        // Phát tiếng "Tích" gốc của iPhone + Taptic rung xác nhận
        iPhoneNativeFeedback.tickOn()
        
        Task {
            await store.setMultiEnabled(true, item: item)
            
            if !authManager.isAuthorized || authManager.isInteractionLocked || store.catalog.resolvedMaintenanceEnabled {
                await store.setMultiEnabled(false, item: item)
                return
            }
            
            if let error = store.lastError {
                errorMessage = error
                showErrorAlert = true
            } else if hasGuide {
                showDetailSheet = true
            }
        }
    }
}

// MARK: - POPUP CHI TIẾT MOD (ẢNH + HDSD + COPY + YOUTUBE)
struct ModDetailSheet: View {
    let item: GameCatalogItem
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var copied = false
    
    private var isYouTubeLink: Bool {
        let guide = (item.usageGuide ?? "").lowercased()
        return guide.contains("youtube.com") || guide.contains("youtu.be")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        if let imgURL = item.imageURL, !imgURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            SecureCatalogImage(urlString: imgURL, placeholder: Image(systemName: "photo"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.25), lineWidth: 1))
                        }
                        
                        if let guide = item.usageGuide, !guide.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "text.book.closed.fill")
                                        .foregroundColor(.cyan)
                                    Text("Hướng dẫn sử dụng")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Button {
                                        iPhoneNativeFeedback.tickOn()
                                        UIPasteboard.general.string = guide
                                        copied = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                            Text(copied ? "Đã Copy" : "Copy")
                                        }
                                        .font(.caption.bold())
                                        .foregroundColor(copied ? .green : .cyan)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.cyan.opacity(copied ? 0.08 : 0.16))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Text(guide)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.88))
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(14)
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
                                
                                if isYouTubeLink {
                                    Button {
                                        iPhoneNativeFeedback.tap()
                                        if let url = URL(string: guide.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                            UIApplication.shared.open(url)
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "play.rectangle.fill")
                                            Text("Mở Video Hướng Dẫn")
                                        }
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(LinearGradient(colors: [.red, .red.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                                        .cornerRadius(14)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        if (item.imageURL ?? "").isEmpty && (item.usageGuide ?? "").isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.questionmark")
                                    .font(.system(size: 46))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("Chưa có hướng dẫn cho tính năng này")
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.top, 50)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        iPhoneNativeFeedback.tap()
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                    .font(.headline.bold())
                }
            }
            .onChange(of: authManager.isAuthorized) { authorized in
                if !authorized { dismiss() }
            }
            .onChange(of: store.catalog.resolvedMaintenanceEnabled) { isMaintenance in
                if isMaintenance { dismiss() }
            }
        }
    }
}
