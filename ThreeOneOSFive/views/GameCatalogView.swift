import SwiftUI
import UIKit

// MARK: - BỘ TẢI ẢNH AN TOÀN (Fade-in mượt)
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
                    .transition(.opacity.animation(.easeInOut(duration: 0.4)))
            } else {
                placeholder
                    .resizable()
                    .scaledToFit()
                    .padding(11)
                    .foregroundColor(.white.opacity(0.32))
                    .overlay(
                        ProgressView()
                            .tint(.cyan)
                            .scaleEffect(0.85)
                            .opacity(isLoading ? 1 : 0)
                    )
            }
        }
        .clipped()
        .onAppear {
            loadImage()
        }
        .onChange(of: urlString) { _ in
            image = nil
            isLoading = true
            loadImage()
        }
    }
    
    private func loadImage() {
        guard !SecureNetworkManager.shared.isProxyEnabled() else {
            isLoading = false
            return
        }
        let cleanUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUrl.isEmpty, let url = URL(string: cleanUrl) else {
            isLoading = false
            return
        }
        SecureNetworkManager.shared.createSecureSession().dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                if let data = data, let uiImage = UIImage(data: data) {
                    withAnimation { self.image = uiImage }
                }
                self.isLoading = false
            }
        }.resume()
    }
}

// MARK: - MÀN HÌNH CHÍNH (GAME CATALOG)
struct GameCatalogView: View {
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @Binding var isTabBarHidden: Bool
    
    @State private var isRotating = false
    
    private var isSessionActive: Bool {
        authManager.isAuthorized
        && !authManager.isInteractionLocked
        && !store.catalog.resolvedMaintenanceEnabled
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.015, green: 0.025, blue: 0.05)
                    .ignoresSafeArea()
                
                // --- BACKGROUND ĐỘNG ---
                GeometryReader { geo in
                    SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "sparkles"))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .opacity(0.65)
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.35),
                                    Color(red: 0.02, green: 0.04, blue: 0.08).opacity(0.75),
                                    Color(red: 0.01, green: 0.02, blue: 0.04).opacity(0.95)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .ignoresSafeArea()
                
                // --- ÁNH SÁNG AMBIENT NEON ---
                Circle()
                    .fill(Color.cyan.opacity(0.14))
                    .frame(width: 300, height: 300)
                    .blur(radius: 90)
                    .offset(x: -110, y: -260)
                    .ignoresSafeArea()
                
                Circle()
                    .fill(Color.blue.opacity(0.16))
                    .frame(width: 280, height: 280)
                    .blur(radius: 95)
                    .offset(x: 130, y: 240)
                    .ignoresSafeArea()
                
                // --- HIỆU ỨNG TUYẾT RƠI ---
                CatalogSnowfallView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                
                // --- NỘI DUNG CHÍNH ---
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 26) {
                        
                        // TOP STATUS BAR
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.shield.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.cyan)
                                Text("SOVEREIGN CONTROL")
                                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                    .tracking(1.2)
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                            
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 7, height: 7)
                                    .shadow(color: .green, radius: 5)
                                Text("ONLINE")
                                    .font(.system(size: 10.5, weight: .black, design: .monospaced))
                                    .tracking(1)
                                    .foregroundColor(.cyan)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.cyan.opacity(0.45), lineWidth: 1))
                            .shadow(color: .cyan.opacity(0.25), radius: 8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 44)
                        
                        // HERO AVATAR & BRAND
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.cyan.opacity(0.2))
                                    .frame(width: 144, height: 144)
                                    .blur(radius: 24)
                                
                                Circle()
                                    .stroke(
                                        AngularGradient(
                                            gradient: Gradient(colors: [.cyan, .blue, .indigo, .cyan]),
                                            center: .center
                                        ),
                                        lineWidth: 3.5
                                    )
                                    .frame(width: 122, height: 122)
                                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                                    .animation(.linear(duration: 4.5).repeatForever(autoreverses: false), value: isRotating)
                                    .drawingGroup()
                                
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    .frame(width: 132, height: 132)
                                
                                SecureCatalogImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                                    .frame(width: 110, height: 110)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.28), lineWidth: 1))
                            }
                            .onAppear { isRotating = true }
                            
                            VStack(spacing: 4) {
                                Text(authManager.publicAppName.isEmpty ? "𝐒𝐨𝐯𝐞𝐫𝐞𝐢𝐠𝐧 𝐒𝐨𝐥𝐢𝐭𝐮𝐝𝐞" : authManager.publicAppName)
                                    .font(.system(size: 27, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.white, .cyan.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                                    )
                                    .shadow(color: .cyan.opacity(0.6), radius: 12)
                                
                                Text("Chọn trò chơi bên dưới để cấu hình")
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundColor(.white.opacity(0.55))
                            }
                        }
                        
                        // TIÊU ĐỀ DANH SÁCH GAME
                        HStack {
                            Text("DANH SÁCH ỨNG DỤNG")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .tracking(1.4)
                                .foregroundColor(.cyan.opacity(0.85))
                            
                            Spacer()
                            
                            Text("\(store.catalog.orderedGames.count) GAME")
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.55))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, -10)
                        
                        // DANH SÁCH GAME CARDS
                        VStack(spacing: 14) {
                            if store.catalog.orderedGames.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "gamecontroller")
                                        .font(.system(size: 32))
                                        .foregroundColor(.cyan.opacity(0.5))
                                    Text("Chưa có trò chơi nào được cấu hình")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.55))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 44)
                                .background(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                                .cornerRadius(22)
                                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                .padding(.horizontal, 20)
                            } else {
                                ForEach(store.catalog.orderedGames) { game in
                                    NavigationLink(destination: GameDetailView(gameID: game.id, isTabBarHidden: $isTabBarHidden)) {
                                        GameCatalogCardRow(game: game)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .disabled(!isSessionActive)
                                    .simultaneousGesture(TapGesture().onEnded {
                                        guard isSessionActive else { return }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.easeInOut(duration: 0.22)) { isTabBarHidden = true }
                                    })
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.bottom, 120)
                    }
                }
                .disabled(!isSessionActive)
                .allowsHitTesting(isSessionActive)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
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
private struct GameCatalogCardRow: View {
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
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 64, height: 64)
                
                SecureCatalogImage(urlString: game.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                    .frame(width: 58, height: 58)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(
                            LinearGradient(colors: [.cyan, .blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 2
                        )
                    )
                    .shadow(color: .cyan.opacity(0.45), radius: 8)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(game.name)
                    .font(.system(size: 17.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label("\(activeVisibleItemsCount) chức năng", systemImage: "square.grid.2x2.fill")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                    
                    if enabledModCount > 0 {
                        Text("• \(enabledModCount) đang bật")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                }
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 38, height: 38)
                    .shadow(color: .cyan.opacity(0.55), radius: 8)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.black.opacity(0.25)],
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
                        colors: [.cyan.opacity(0.65), .white.opacity(0.08), .blue.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: .black.opacity(0.45), radius: 14, y: 7)
    }
}

// MARK: - CUSTOM BUTTON STYLE
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - HIỆU ỨNG TUYẾT RƠI
struct CatalogSnowParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var blur: CGFloat
}

struct CatalogSnowfallView: View {
    @State private var particles: [CatalogSnowParticle] = []
    
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    for particle in particles {
                        let yPos = (particle.y + CGFloat(time) * 28).truncatingRemainder(dividingBy: size.height + 100)
                        
                        context.opacity = particle.opacity
                        context.addFilter(.blur(radius: particle.blur))
                        
                        let rect = CGRect(
                            x: particle.x + sin(CGFloat(time) + particle.y * 0.1) * 18,
                            y: yPos,
                            width: particle.size,
                            height: particle.size
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(.white))
                    }
                }
            }
            .onAppear {
                guard particles.isEmpty else { return }
                for _ in 0..<36 {
                    particles.append(
                        CatalogSnowParticle(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: -100...geo.size.height),
                            size: CGFloat.random(in: 2...5),
                            opacity: Double.random(in: 0.18...0.6),
                            blur: CGFloat.random(in: 0...1)
                        )
                    )
                }
            }
        }
    }
}

// MARK: - CHI TIẾT GAME (DANH MỤC CHỨC NĂNG)
private struct GameDetailView: View {
    let gameID: String
    @Binding var isTabBarHidden: Bool
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var selectedTabID = "aim"
    @Environment(\.dismiss) private var dismiss

    private var catalog: GameCatalog { store.catalog }
    private var game: GameCatalogGame? { catalog.games.first(where: { $0.id == gameID }) }
    
    private var isSessionActive: Bool {
        authManager.isAuthorized
        && !authManager.isInteractionLocked
        && !store.catalog.resolvedMaintenanceEnabled
    }
    
    private var items: [GameCatalogItem] {
        (game?.items ?? [])
            .filter { $0.hidden != true && $0.category.rawValue == selectedTabID }
            .sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
    }
    
    private var availableTabs: [GameCatalogTab] {
        let fallbackTabs: [GameCatalogTab] = catalog.resolvedTabs
        guard let game else { return fallbackTabs }
        let ownTabs = game.resolvedTabs(fallback: fallbackTabs)
        guard let selected = game.tabIDs else { return ownTabs }
        return ownTabs.filter { selected.contains($0.id) }
    }

    var body: some View {
        ZStack {
            Color(red: 0.015, green: 0.025, blue: 0.05)
                .ignoresSafeArea()
            
            GeometryReader { geo in
                SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "photo"))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.55)
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.45), Color.black.opacity(0.82), Color.black.opacity(0.95)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // TOP NAVIGATION BAR
                HStack(spacing: 12) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.22)) { isTabBarHidden = false }
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .background(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.cyan.opacity(0.5), lineWidth: 1))
                            .shadow(color: .cyan.opacity(0.3), radius: 6)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text(game?.name ?? "Danh sách Mod")
                            .font(.system(size: 19, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .shadow(color: .cyan.opacity(0.6), radius: 8)
                        
                        Text("\(items.count) tính năng khả dụng")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.cyan.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Icon game thu nhỏ ở góc phải
                    SecureCatalogImage(urlString: game?.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                .padding(.bottom, 14)
                
                // THANH TAB DANH MỤC DẠNG PILL NGANG (Chạm 1 lần chuyển ngay)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(availableTabs) { tab in
                            let isSelected = selectedTabID == tab.id
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    selectedTabID = tab.id
                                }
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 13, weight: .bold))
                                    Text(tab.title)
                                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(isSelected ? .black : .white.opacity(0.85))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    Group {
                                        if isSelected {
                                            LinearGradient(colors: [.cyan, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        } else {
                                            Color.white.opacity(0.07)
                                        }
                                    }
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(isSelected ? Color.white.opacity(0.6) : Color.white.opacity(0.14), lineWidth: 1)
                                )
                                .shadow(color: isSelected ? .cyan.opacity(0.45) : .clear, radius: 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
                .padding(.bottom, 8)
                
                // DANH SÁCH CHỨC NĂNG
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 13) {
                        if items.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 34))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("Chưa có chức năng nào trong mục này")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.55))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 50)
                            .background(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08), lineWidth: 1))
                            .padding(.top, 16)
                        } else {
                            ForEach(items) { item in
                                ModItemRow(item: item)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 125)
                }
            }
            
            // NÚT KHỞI ĐỘNG GAME NỔI Ở ĐÁY
            VStack {
                Spacer()
                Button {
                    guard isSessionActive else { return }
                    let rawLaunch = (game?.launchURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if let url = URL(string: rawLaunch), !rawLaunch.isEmpty {
                        UIApplication.shared.open(url)
                    }
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .black))
                        Text("KHỞI ĐỘNG GAME")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .tracking(1)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(colors: [.cyan, Color(red: 0.1, green: 0.75, blue: 1.0)], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.55), lineWidth: 1.2))
                    .shadow(color: .cyan.opacity(0.55), radius: 18, y: 8)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 22)
                .padding(.bottom, 26)
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
}

// MARK: - HÀNG CHỨA TỪNG CHỨC NĂNG (KÍCH HOẠT MƯỢT TỚI 10 FILE .3105)
private struct ModItemRow: View {
    let item: GameCatalogItem
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var showDetailSheet = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
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
        return cleanSub.isEmpty ? "Chạm công tắc để kích hoạt" : cleanSub
    }
    
    var body: some View {
        let hasLink = !item.resolvedFileURLs.isEmpty
        let isOn = store.isMultiItemOn(item: item)
        let busy = store.isMultiItemBusy(item: item)
        
        HStack(spacing: 13) {
            // ICON AVATAR
            ZStack {
                Circle()
                    .fill(isOn ? Color.cyan.opacity(0.22) : Color.white.opacity(0.05))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .stroke(isOn ? Color.cyan : Color.white.opacity(0.12), lineWidth: 1.5)
                    )
                    .shadow(color: isOn ? .cyan.opacity(0.55) : .clear, radius: 8)
                
                if !authManager.publicAvatarURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    SecureCatalogImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: isOn ? "shield.fill" : "shield"))
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                } else {
                    Image(systemName: isOn ? "shield.fill" : "shield")
                        .foregroundColor(isOn ? .cyan : .white.opacity(0.5))
                        .font(.system(size: 20, weight: .semibold))
                }
            }
            
            // TÊN & MÔ TẢ
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(item.name)
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(badgeLabel)
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(isHighlightedBadge ? .black : .white.opacity(0.85))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(
                            Group {
                                if isHighlightedBadge {
                                    LinearGradient(colors: [.cyan, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                                } else {
                                    Color.white.opacity(0.18)
                                }
                            }
                        )
                        .cornerRadius(6)
                }
                
                Text(subtitleDisplay)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isOn ? .cyan.opacity(0.85) : .white.opacity(0.52))
                    .lineLimit(1)
            }
            
            Spacer(minLength: 6)
            
            // NÚT XEM HDSD / ẢNH NHANH (Nếu có)
            if hasGuide {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showDetailSheet = true
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.cyan)
                        .frame(width: 32, height: 32)
                        .background(Color.cyan.opacity(0.12))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            
            // CÔNG TẮC KÍCH HOẠT MƯỢT
            if busy {
                ProgressView()
                    .tint(.cyan)
                    .scaleEffect(1.05)
                    .frame(width: 51, height: 31)
            } else {
                Toggle("", isOn: Binding(
                    get: { store.isMultiItemOn(item: item) },
                    set: { value in
                        if !value {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            Task { await store.setMultiEnabled(false, item: item) }
                            return
                        }
                        
                        guard isSessionActive else { return }
                        
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                ))
                .labelsHidden()
                .tint(.cyan)
                .disabled(!hasLink && !isOn)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: isOn
                                ? [Color.cyan.opacity(0.12), Color.blue.opacity(0.06)]
                                : [Color.white.opacity(0.04), Color.black.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isOn ? Color.cyan.opacity(0.85) : Color.white.opacity(0.12),
                    lineWidth: isOn ? 1.5 : 1
                )
        )
        .shadow(color: isOn ? .cyan.opacity(0.22) : .black.opacity(0.3), radius: 10, y: 4)
        .opacity(hasLink ? 1 : 0.55)
        .animation(.easeInOut(duration: 0.2), value: isOn)
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
                Color(red: 0.02, green: 0.03, blue: 0.06).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        if let imgURL = item.imageURL, !imgURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            SecureCatalogImage(urlString: imgURL, placeholder: Image(systemName: "photo"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 250)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.cyan.opacity(0.5), lineWidth: 1))
                                .shadow(color: .cyan.opacity(0.2), radius: 12)
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
                                        UIPasteboard.general.string = guide
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                
                                if isYouTubeLink {
                                    Button {
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
                                        .shadow(color: .red.opacity(0.4), radius: 8, y: 4)
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
                    Button("Đóng") { dismiss() }
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
