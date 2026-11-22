import SwiftUI
import UIKit
import AudioToolbox

// MARK: - ÂM THANH "TÍCH" GỐC CỦA IPHONE + TAPTIC ENGINE (0ms LAG)
enum iPhoneNativeFeedback {
    /// Tiếng "Tích" gốc của hệ thống iOS (Tink - 1057) + Rung xác nhận
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

// MARK: - HÌNH KHỐI VÁT GÓC 45° ESPORTS HUD (CHAMFERED SHAPE)
struct CyberChamferShape: InsettableShape {
    var cut: CGFloat = 10
    var insetAmount: CGFloat = 0
    
    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let c = min(cut, min(r.width, r.height) / 2)
        var path = Path()
        
        // Bắt đầu từ góc trên-trái (vát chéo)
        path.move(to: CGPoint(x: r.minX + c, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        // Vát chéo góc dưới-phải
        path.addLine(to: CGPoint(x: r.maxX - c, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        path.closeSubpath()
        
        return path
    }
    
    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
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
                    .transition(.opacity.animation(.easeInOut(duration: 0.22)))
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

// MARK: - MÀN HÌNH CHÍNH (PITCH-BLACK CYBER HUD)
struct GameCatalogView: View {
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @Binding var isTabBarHidden: Bool
    
    @State private var spinRing = false
    @State private var pulseDot = false
    
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
                
                // BACKGROUND MỜ SÂU + LƯỚI TỌA ĐỘ MỜ
                GeometryReader { geo in
                    SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "sparkles"))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .opacity(0.32)
                        .overlay(
                            LinearGradient(
                                colors: [Color.black.opacity(0.4), Color.black.opacity(0.88), Color.black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .ignoresSafeArea()
                
                // HẠT ÁNH SÁNG RƠI NHẸ 60FPS
                CyberDustCanvas()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // 1. TOP TELEMETRY BAR (GỌN SẮC NÉT)
                        HStack {
                            HStack(spacing: 7) {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(pulseDot ? 1.35 : 0.85)
                                    .shadow(color: .white, radius: 6)
                                
                                Text("SYS // ONLINE")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .tracking(1.4)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            if totalEnabledMods > 0 {
                                Button {
                                    iPhoneNativeFeedback.tickOff()
                                    store.disableAllEnabledMods()
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "power")
                                            .font(.system(size: 9.5, weight: .black))
                                        Text("TẮT HẾT [\(totalEnabledMods)]")
                                            .font(.system(size: 10, weight: .black, design: .monospaced))
                                    }
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.white)
                                    .clipShape(CyberChamferShape(cut: 6))
                                    .shadow(color: .white.opacity(0.5), radius: 8)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text("V2.6 // READY")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .tracking(1)
                                    .foregroundColor(.white.opacity(0.55))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.04))
                        .clipShape(CyberChamferShape(cut: 9))
                        .overlay(
                            CyberChamferShape(cut: 9)
                                .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        
                        // 2. TRUNG TÂM THƯƠNG HIỆU (HUD RETICLE + AVATAR)
                        VStack(spacing: 12) {
                            ZStack {
                                // Vòng quét đứt nét xoay chậm
                                Circle()
                                    .stroke(style: StrokeStyle(lineWidth: 1.2, dash: [6, 5]))
                                    .foregroundColor(.white.opacity(0.45))
                                    .frame(width: 108, height: 108)
                                    .rotationEffect(.degrees(spinRing ? 360 : 0))
                                    .animation(.linear(duration: 12).repeatForever(autoreverses: false), value: spinRing)
                                    .drawingGroup()
                                
                                // Vòng ánh sáng trắng xoay ngược
                                Circle()
                                    .stroke(
                                        AngularGradient(colors: [.white, .clear, .white.opacity(0.7), .clear], center: .center),
                                        lineWidth: 2.2
                                    )
                                    .frame(width: 94, height: 94)
                                    .rotationEffect(.degrees(spinRing ? -360 : 0))
                                    .animation(.linear(duration: 4.5).repeatForever(autoreverses: false), value: spinRing)
                                    .drawingGroup()
                                
                                SecureCatalogImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                                    .frame(width: 82, height: 82)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                                    .shadow(color: .white.opacity(0.25), radius: 12)
                            }
                            
                            VStack(spacing: 4) {
                                Text(authManager.publicAppName.isEmpty ? "𝐒𝐨𝐯𝐞𝐫𝐞𝐢𝐠𝐧 𝐒𝐨𝐥𝐢𝐭𝐮𝐝𝐞" : authManager.publicAppName)
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: .white.opacity(0.35), radius: 10)
                                
                                Text("CHỌN MỤC TIÊU BÊN DƯỚI ĐỂ KÍCH HOẠT")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .tracking(1.5)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(.vertical, 4)
                        
                        // 3. DANH SÁCH GAME (THẺ VÁT GÓC ESPORTS)
                        VStack(spacing: 14) {
                            if store.catalog.orderedGames.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "gamecontroller")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white.opacity(0.35))
                                    Text("Chưa có trò chơi nào được cấu hình")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.55))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 42)
                                .background(Color.white.opacity(0.03))
                                .clipShape(CyberChamferShape(cut: 14))
                                .overlay(CyberChamferShape(cut: 14).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                                .padding(.horizontal, 16)
                            } else {
                                ForEach(store.catalog.orderedGames) { game in
                                    NavigationLink(destination: GameDetailView(gameID: game.id, isTabBarHidden: $isTabBarHidden)) {
                                        CyberGameDeckCard(game: game)
                                    }
                                    .buttonStyle(CyberPressStyle())
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
                spinRing = true
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseDot = true
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

// MARK: - THẺ GAME TRÊN MÀN HÌNH CHÍNH (PHONG CÁCH ESPORTS HUD)
private struct CyberGameDeckCard: View {
    let game: GameCatalogGame
    @StateObject private var store = GameCatalogStore.shared
    @State private var arrowPhase = false
    
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
            // ICON GAME VÁT GÓC VIỀN TRẮNG PHÁT SÁNG
            ZStack {
                SecureCatalogImage(urlString: game.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                    .frame(width: 62, height: 62)
                    .clipShape(CyberChamferShape(cut: 11))
                    .overlay(
                        CyberChamferShape(cut: 11)
                            .strokeBorder(Color.white.opacity(0.65), lineWidth: 1.3)
                    )
                    .shadow(color: .white.opacity(0.22), radius: 8)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("TARGET")
                        .font(.system(size: 8.5, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white)
                        .clipShape(CyberChamferShape(cut: 4))
                    
                    if enabledModCount > 0 {
                        Text("\(enabledModCount) ACTIVE")
                            .font(.system(size: 8.5, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.18))
                            .clipShape(CyberChamferShape(cut: 4))
                    }
                }
                
                Text(game.name)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text("\(activeVisibleItemsCount) mô-đun chức năng sẵn sàng")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }
            
            Spacer(minLength: 4)
            
            // NÚT TRUY CẬP >>> ĐỘNG
            HStack(spacing: -3) {
                ForEach(0..<3, id: \.self) { idx in
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.black)
                        .opacity(arrowPhase ? (idx == 2 ? 1.0 : 0.45) : (idx == 0 ? 1.0 : 0.45))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.white)
            .clipShape(CyberChamferShape(cut: 8))
            .shadow(color: .white.opacity(0.45), radius: 8)
        }
        .padding(14)
        .background(
            ZStack {
                Color.white.opacity(0.04)
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(CyberChamferShape(cut: 16))
        .overlay(
            CyberChamferShape(cut: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), Color.white.opacity(0.12), Color.white.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                arrowPhase = true
            }
        }
    }
}

// MARK: - HIỆU ỨNG NHÚN TACTILE
struct CyberPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - HẠT ÁNH SÁNG RƠI NHẸ (60FPS GPU)
struct CyberDustParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var speed: CGFloat
    var opacity: Double
}

struct CyberDustCanvas: View {
    @State private var dots: [CyberDustParticle] = []
    
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    for dot in dots {
                        let yPos = (dot.y + CGFloat(time) * dot.speed).truncatingRemainder(dividingBy: size.height + 40)
                        let xPos = dot.x + sin(CGFloat(time) * 1.1 + dot.y * 0.04) * 8
                        context.opacity = dot.opacity
                        let rect = CGRect(x: xPos, y: yPos, width: dot.size, height: dot.size)
                        context.fill(Path(rect), with: .color(.white))
                    }
                }
            }
            .onAppear {
                guard dots.isEmpty else { return }
                for _ in 0..<24 {
                    dots.append(
                        CyberDustParticle(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height),
                            size: CGFloat.random(in: 1.5...3.0),
                            speed: CGFloat.random(in: 14...26),
                            opacity: Double.random(in: 0.14...0.5)
                        )
                    )
                }
            }
        }
    }
}

// MARK: - MÀN HÌNH CHI TIẾT GAME (COMMAND MATRIX 2 CỘT + LASER RAIL TABS)
private struct GameDetailView: View {
    let gameID: String
    @Binding var isTabBarHidden: Bool
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var selectedTabID = "aim"
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var onlyActive = false
    @State private var launchChevronPulse = false
    @Namespace private var laserRail
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
                if onlyActive && !store.isMultiItemOn(item: item) { return false }
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
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: 9),
        GridItem(.flexible(), spacing: 9)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            GeometryReader { geo in
                SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "photo"))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.28)
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.45), Color.black.opacity(0.92), Color.black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .ignoresSafeArea()
            
            VStack(spacing: 10) {
                // 1. TOP HUD BAR SIÊU GỌN
                HStack(spacing: 10) {
                    Button {
                        iPhoneNativeFeedback.tap()
                        withAnimation(.easeInOut(duration: 0.2)) { isTabBarHidden = false }
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.06))
                            .clipShape(CyberChamferShape(cut: 8))
                            .overlay(CyberChamferShape(cut: 8).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(game?.name.uppercased() ?? "COMMAND MATRIX")
                            .font(.system(size: 16.5, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(activeCountInGame > 0 ? "ACTIVE: \(activeCountInGame) MÔ-ĐUN" : "SYSTEM STANDBY")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundColor(activeCountInGame > 0 ? .white : .white.opacity(0.45))
                    }
                    
                    Spacer()
                    
                    // Nút Tắt hết
                    if activeCountInGame > 0 {
                        Button {
                            iPhoneNativeFeedback.tickOff()
                            store.disableAllEnabledMods()
                        } label: {
                            Text("OFF ALL")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .clipShape(CyberChamferShape(cut: 6))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Nút lọc Đang bật
                    Button {
                        iPhoneNativeFeedback.tap()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                            onlyActive.toggle()
                        }
                    } label: {
                        Text("\(activeCountInGame)")
                            .font(.system(size: 11.5, weight: .black, design: .monospaced))
                            .foregroundColor(onlyActive ? .black : .white)
                            .frame(width: 34, height: 34)
                            .background(onlyActive ? Color.white : Color.white.opacity(0.06))
                            .clipShape(CyberChamferShape(cut: 7))
                            .overlay(CyberChamferShape(cut: 7).strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    // Nút Tìm kiếm
                    Button {
                        iPhoneNativeFeedback.tap()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                            showSearch.toggle()
                            if !showSearch { searchText = "" }
                        }
                    } label: {
                        Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.06))
                            .clipShape(CyberChamferShape(cut: 7))
                            .overlay(CyberChamferShape(cut: 7).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                
                // THANH TÌM KIẾM THU GỌN
                if showSearch {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                        TextField("Nhập tên mô-đun...", text: $searchText)
                            .font(.system(size: 12.5, design: .monospaced))
                            .foregroundColor(.white)
                            .tint(.white)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.45))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.05))
                    .clipShape(CyberChamferShape(cut: 8))
                    .overlay(CyberChamferShape(cut: 8).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                    .padding(.horizontal, 14)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // 2. THANH DANH MỤC LASER RAIL (KHÔNG TRÀN MÀN HÌNH)
                Group {
                    if availableTabs.count <= 3 {
                        HStack(spacing: 0) {
                            ForEach(availableTabs) { tab in
                                laserTabButton(tab: tab, stretch: true)
                            }
                        }
                        .padding(.horizontal, 14)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(availableTabs) { tab in
                                    laserTabButton(tab: tab, stretch: false)
                                }
                            }
                            .padding(.horizontal, 14)
                        }
                    }
                }
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.white.opacity(0.12)),
                    alignment: .bottom
                )
                
                // 3. LƯỚI MÔ-ĐUN 2 CỘT VÁT GÓC SIÊU GỌN
                ScrollView(showsIndicators: false) {
                    if items.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "square.dashed")
                                .font(.system(size: 26))
                                .foregroundColor(.white.opacity(0.3))
                            Text(onlyActive ? "CHƯA CÓ MÔ-ĐUN NÀO ĐANG BẬT" : "DANH MỤC TRỐNG")
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                        .background(Color.white.opacity(0.03))
                        .clipShape(CyberChamferShape(cut: 14))
                        .overlay(CyberChamferShape(cut: 14).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: 9) {
                            ForEach(items) { item in
                                CyberModMatrixCell(item: item)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 4)
                        .padding(.bottom, 22)
                    }
                }
            }
            // DOCK KHỞI ĐỘNG GAME VÁT GÓC NỔI Ở ĐÁY
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    SecureCatalogImage(urlString: game?.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                        .frame(width: 44, height: 44)
                        .clipShape(CyberChamferShape(cut: 9))
                        .overlay(CyberChamferShape(cut: 9).strokeBorder(Color.white.opacity(0.5), lineWidth: 1))
                    
                    Button {
                        guard isSessionActive else { return }
                        iPhoneNativeFeedback.launch()
                        let rawLaunch = (game?.launchURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if let url = URL(string: rawLaunch), !rawLaunch.isEmpty {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .black))
                            Text("KHỞI ĐỘNG GAME")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .tracking(1)
                            
                            HStack(spacing: -3) {
                                ForEach(0..<3, id: \.self) { idx in
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .black))
                                        .opacity(launchChevronPulse ? (idx == 2 ? 1.0 : 0.35) : (idx == 0 ? 1.0 : 0.35))
                                }
                            }
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.white)
                        .clipShape(CyberChamferShape(cut: 10))
                        .shadow(color: .white.opacity(0.45), radius: 10)
                    }
                    .buttonStyle(CyberPressStyle())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.92))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.white.opacity(0.16)),
                    alignment: .top
                )
            }
        }
        .disabled(!isSessionActive)
        .allowsHitTesting(isSessionActive)
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                launchChevronPulse = true
            }
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
    private func laserTabButton(tab: GameCatalogTab, stretch: Bool) -> some View {
        let isSelected = selectedTabID == tab.id
        Button {
            iPhoneNativeFeedback.tap()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                selectedTabID = tab.id
            }
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 11, weight: .bold))
                    Text(tab.title.uppercased())
                        .font(.system(size: 11.5, weight: .black, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .foregroundColor(isSelected ? .white : .white.opacity(0.45))
                .frame(maxWidth: stretch ? .infinity : nil)
                .padding(.top, 6)
                
                // THANH LASER SÁNG TRƯỢT DƯỚI CHÂN TAB
                ZStack {
                    Color.clear.frame(height: 2.5)
                    if isSelected {
                        Rectangle()
                            .fill(Color.white)
                            .frame(height: 2.5)
                            .shadow(color: .white, radius: 5)
                            .matchedGeometryEffect(id: "LASER_TAB_LINE", in: laserRail)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ô MÔ-ĐUN CHỨC NĂNG VÁT GÓC (CHAMFERED MATRIX CELL + TIẾNG TÍCH IPHONE)
private struct CyberModMatrixCell: View {
    let item: GameCatalogItem
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var showDetailSheet = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var sweepOffset: CGFloat = -150
    
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
        return cleanSub.isEmpty ? "CHẠM ĐỂ BẬT" : cleanSub
    }
    
    var body: some View {
        let hasLink = !item.resolvedFileURLs.isEmpty
        let isOn = store.isMultiItemOn(item: item)
        let busy = store.isMultiItemBusy(item: item)
        
        VStack(alignment: .leading, spacing: 6) {
            // HÀNG TRÊN: ĐÈN LED + NHÃN + HDSD
            HStack(spacing: 6) {
                // Đèn LED trạng thái vuông vát góc
                ZStack {
                    CyberChamferShape(cut: 4)
                        .fill(isOn ? Color.white : Color.white.opacity(0.08))
                        .frame(width: 22, height: 22)
                        .shadow(color: isOn ? .white.opacity(0.75) : .clear, radius: 5)
                    
                    if busy {
                        ProgressView()
                            .tint(isOn ? .black : .white)
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: isOn ? "checkmark" : "power")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(isOn ? .black : .white.opacity(0.65))
                    }
                }
                
                Text(badgeLabel)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundColor(isHighlightedBadge ? .black : .white.opacity(0.8))
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 2)
                    .background(isHighlightedBadge ? Color.white : Color.white.opacity(0.14))
                    .clipShape(CyberChamferShape(cut: 3))
                
                Spacer(minLength: 0)
                
                if hasGuide {
                    Button {
                        iPhoneNativeFeedback.tap()
                        showDetailSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer(minLength: 0)
            
            // HÀNG DƯỚI: TÊN CHỨC NĂNG + TRẠNG THÁI
            VStack(alignment: .leading, spacing: 2.5) {
                Text(item.name)
                    .font(.system(size: 12.8, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(busy ? Color.yellow : (isOn ? Color.white : Color.white.opacity(0.3)))
                        .frame(width: 4.5, height: 4.5)
                    
                    Text(busy ? "ĐANG NẠP..." : (isOn ? "ON // ACTIVE" : subtitleDisplay))
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(busy ? .yellow : (isOn ? .white : .white.opacity(0.45)))
                        .lineLimit(1)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(
            ZStack {
                Color.black.opacity(0.85)
                
                LinearGradient(
                    colors: isOn
                        ? [Color.white.opacity(0.18), Color.white.opacity(0.04)]
                        : [Color.white.opacity(0.04), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // TIA SÁNG QUÉT CHÉO KHI KÍCH HOẠT
                if isOn {
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.42), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 60)
                    .rotationEffect(.degrees(22))
                    .offset(x: sweepOffset)
                    .allowsHitTesting(false)
                }
            }
        )
        .clipShape(CyberChamferShape(cut: 11))
        .overlay(
            CyberChamferShape(cut: 11)
                .strokeBorder(
                    isOn ? Color.white : Color.white.opacity(0.18),
                    lineWidth: isOn ? 1.5 : 0.9
                )
        )
        .shadow(color: isOn ? .white.opacity(0.28) : .clear, radius: 8)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !busy, (hasLink || isOn) else { return }
            toggleFeature(currentlyOn: isOn)
        }
        .opacity(hasLink ? 1 : 0.45)
        .animation(.spring(response: 0.22, dampingFraction: 0.75), value: isOn)
        .onChange(of: isOn) { active in
            if active {
                sweepOffset = -140
                withAnimation(.easeOut(duration: 0.48)) {
                    sweepOffset = 170
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
        
        // Tiếng "Tích" gốc của iPhone + Taptic rung xác nhận
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
                                .clipShape(CyberChamferShape(cut: 12))
                                .overlay(CyberChamferShape(cut: 12).strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                        }
                        
                        if let guide = item.usageGuide, !guide.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "text.book.closed.fill")
                                        .foregroundColor(.white)
                                    Text("HƯỚNG DẪN SỬ DỤNG")
                                        .font(.system(size: 13, weight: .black, design: .monospaced))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Button {
                                        iPhoneNativeFeedback.tickOn()
                                        UIPasteboard.general.string = guide
                                        copied = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                            Text(copied ? "ĐÃ COPY" : "COPY")
                                        }
                                        .font(.system(size: 11, weight: .black, design: .monospaced))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.white)
                                        .clipShape(CyberChamferShape(cut: 6))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Text(guide)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.05))
                                    .clipShape(CyberChamferShape(cut: 10))
                                    .overlay(CyberChamferShape(cut: 10).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                                
                                if isYouTubeLink {
                                    Button {
                                        iPhoneNativeFeedback.tap()
                                        if let url = URL(string: guide.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                            UIApplication.shared.open(url)
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "play.rectangle.fill")
                                            Text("MỞ VIDEO HƯỚNG DẪN")
                                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                        }
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.white)
                                        .clipShape(CyberChamferShape(cut: 10))
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
                    Button("ĐÓNG") {
                        iPhoneNativeFeedback.tap()
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
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
