import SwiftUI
import UIKit
import AVFoundation
import AudioToolbox

// MARK: - BỘ PHÁT TIẾNG "TÍCH" CHUẨN IPHONE (APPLE PAY / FACE ID CHIME - 0ms LAG)
final class iPhoneChimeEngine {
    static let shared = iPhoneChimeEngine()
    
    private var engine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
    private let sampleRate: Double = 44100.0
    private var isSetup = false
    private let audioQueue = DispatchQueue(label: "com.zenis.iphone.chime", qos: .userInteractive)
    
    private init() {
        setupEngine()
    }
    
    private func setupEngine() {
        audioQueue.async { [weak self] in
            guard let self = self, !self.isSetup else { return }
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try? session.setActive(true)
            
            let format = AVAudioFormat(standardFormatWithSampleRate: self.sampleRate, channels: 1)!
            self.engine.attach(self.player)
            self.engine.connect(self.player, to: self.engine.mainMixerNode, format: format)
            self.engine.mainMixerNode.outputVolume = 0.65
            try? self.engine.start()
            self.isSetup = true
        }
    }
    
    /// Tiếng "Tích-Tích" trong trẻo chuẩn Apple Pay / Face ID iPhone khi bật
    func playiPhoneTickOn() {
        playTwoNoteBell(
            freq1: 987.77,   // Nốt B5
            freq2: 1318.51,  // Nốt E6 (quãng 4 đúng tạo độ ngân iPhone)
            gap: 0.068,
            decay: 0.24
        )
    }
    
    /// Tiếng "Tích" trầm nhẹ khi tắt chức năng
    func playiPhoneTickOff() {
        playTwoNoteBell(
            freq1: 880.00,   // A5
            freq2: 659.25,   // E5
            gap: 0.055,
            decay: 0.16
        )
    }
    
    /// Tiếng "Tock" bàn phím iOS chuẩn khi chạm nút/tab
    func playSystemTock() {
        AudioServicesPlaySystemSound(1104)
    }
    
    /// Tiếng chuông ngân khởi động game
    func playLaunchChime() {
        playTwoNoteBell(
            freq1: 1046.50,  // C6
            freq2: 1567.98,  // G6
            gap: 0.075,
            decay: 0.32
        )
    }
    
    private func playTwoNoteBell(freq1: Double, freq2: Double, gap: Double, decay: Double) {
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.engine.isRunning {
                try? self.engine.start()
            }
            
            let totalDuration = gap + decay
            let format = AVAudioFormat(standardFormatWithSampleRate: self.sampleRate, channels: 1)!
            let frameCount = AVAudioFrameCount(self.sampleRate * totalDuration)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
            buffer.frameLength = frameCount
            
            let data = buffer.floatChannelData![0]
            let gapFrames = Int(self.sampleRate * gap)
            
            var p1: Double = 0
            var p1Over: Double = 0
            var p2: Double = 0
            var p2Over: Double = 0
            
            for i in 0..<Int(frameCount) {
                var sample: Double = 0
                
                // Nốt 1
                let t1 = Double(i) / self.sampleRate
                let env1 = min(1.0, t1 * 280.0) * exp(-t1 * 18.0)
                p1 += (2.0 * .pi * freq1) / self.sampleRate
                p1Over += (2.0 * .pi * (freq1 * 2.0)) / self.sampleRate
                sample += (sin(p1) * 0.82 + sin(p1Over) * 0.18) * env1
                
                // Nốt 2 (sau khoảng trễ 68ms)
                if i >= gapFrames {
                    let t2 = Double(i - gapFrames) / self.sampleRate
                    let env2 = min(1.0, t2 * 300.0) * exp(-t2 * 13.5)
                    p2 += (2.0 * .pi * freq2) / self.sampleRate
                    p2Over += (2.0 * .pi * (freq2 * 2.0)) / self.sampleRate
                    sample += (sin(p2) * 0.85 + sin(p2Over) * 0.15) * env2
                }
                
                data[i] = Float(sample) * 0.42
            }
            
            self.player.stop()
            self.player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            self.player.play()
        }
    }
}

// MARK: - CACHE ẢNH RAM CHỐNG LOAD LẠI
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

// MARK: - MÀN HÌNH CHÍNH (PITCH-BLACK LUXURY HUB)
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
    
    private var totalEnabledMods: Int {
        store.catalog.orderedGames.reduce(0) { partial, game in
            partial + game.items.filter { $0.hidden != true && store.isMultiItemOn(item: $0) }.count
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                // --- BACKGROUND MỜ TINH TẾ ---
                GeometryReader { geo in
                    SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "sparkles"))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .opacity(0.45)
                        .overlay(
                            LinearGradient(
                                colors: [Color.black.opacity(0.35), Color.black.opacity(0.85), Color.black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .ignoresSafeArea()
                
                // --- HIỆU ỨNG HẠT SÁNG RƠI NHẸ 60FPS ---
                AmbientStarfieldCanvas()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // DYNAMIC STATUS PILL
                        HStack {
                            HStack(spacing: 7) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 7, height: 7)
                                    .shadow(color: .green, radius: 5)
                                Text("SYSTEM ONLINE")
                                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                    .tracking(1.1)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            
                            Spacer()
                            
                            if totalEnabledMods > 0 {
                                Text("\(totalEnabledMods) ACTIVE")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 3.5)
                                    .background(Color.cyan)
                                    .clipShape(Capsule())
                                    .shadow(color: .cyan.opacity(0.6), radius: 6)
                            } else {
                                Text("READY")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.cyan)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        
                        // HERO BRAND CARD
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.cyan.opacity(0.18))
                                    .frame(width: 104, height: 104)
                                    .blur(radius: 18)
                                
                                Circle()
                                    .stroke(
                                        AngularGradient(colors: [.white, .cyan, .blue, .white], center: .center),
                                        lineWidth: 2.5
                                    )
                                    .frame(width: 88, height: 88)
                                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                                    .animation(.linear(duration: 5).repeatForever(autoreverses: false), value: isRotating)
                                    .drawingGroup()
                                
                                SecureCatalogImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                                    .frame(width: 78, height: 78)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                            }
                            
                            VStack(spacing: 4) {
                                Text(authManager.publicAppName.isEmpty ? "𝐒𝐨𝐯𝐞𝐫𝐞𝐢𝐠𝐧 𝐒𝐨𝐥𝐢𝐭𝐮𝐝𝐞" : authManager.publicAppName)
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: .white.opacity(0.25), radius: 8)
                                
                                Text("Chọn trò chơi để mở bảng điều khiển")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .padding(.vertical, 6)
                        
                        // DANH SÁCH GAME
                        VStack(spacing: 12) {
                            if store.catalog.orderedGames.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "gamecontroller")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white.opacity(0.4))
                                    Text("Chưa có trò chơi nào được cấu hình")
                                        .font(.system(size: 13.5, weight: .medium))
                                        .foregroundColor(.white.opacity(0.55))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 22))
                                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.12), lineWidth: 1))
                                .padding(.horizontal, 18)
                            } else {
                                ForEach(store.catalog.orderedGames) { game in
                                    NavigationLink(destination: GameDetailView(gameID: game.id, isTabBarHidden: $isTabBarHidden)) {
                                        GameHubRow(game: game)
                                    }
                                    .buttonStyle(SpringPressStyle())
                                    .disabled(!isSessionActive)
                                    .simultaneousGesture(TapGesture().onEnded {
                                        guard isSessionActive else { return }
                                        iPhoneChimeEngine.shared.playSystemTock()
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        withAnimation(.easeInOut(duration: 0.2)) { isTabBarHidden = true }
                                    })
                                    .padding(.horizontal, 18)
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
private struct GameHubRow: View {
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
            SecureCatalogImage(urlString: game.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1.2)
                )
            
            VStack(alignment: .leading, spacing: 5) {
                Text(game.name)
                    .font(.system(size: 17.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("\(activeVisibleItemsCount) chức năng")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                    
                    if enabledModCount > 0 {
                        Text("• \(enabledModCount) đang bật")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.cyan)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.cyan.opacity(0.35), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: .cyan.opacity(0.12), radius: 14, y: 6)
    }
}

// MARK: - HIỆU ỨNG NHÚN KHI CHẠM
struct SpringPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

// MARK: - NỀN HẠT SÁNG RƠI NHẸ (60FPS GPU)
struct AmbientStarParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var speed: CGFloat
    var opacity: Double
}

struct AmbientStarfieldCanvas: View {
    @State private var stars: [AmbientStarParticle] = []
    
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    for star in stars {
                        let yPos = (star.y + CGFloat(time) * star.speed).truncatingRemainder(dividingBy: size.height + 40)
                        let xPos = star.x + sin(CGFloat(time) * 1.1 + star.y * 0.04) * 10
                        context.opacity = star.opacity
                        let rect = CGRect(x: xPos, y: yPos, width: star.size, height: star.size)
                        context.fill(Path(ellipseIn: rect), with: .color(.white))
                    }
                }
            }
            .onAppear {
                guard stars.isEmpty else { return }
                for _ in 0..<26 {
                    stars.append(
                        AmbientStarParticle(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height),
                            size: CGFloat.random(in: 1.5...3.4),
                            speed: CGFloat.random(in: 14...28),
                            opacity: Double.random(in: 0.15...0.55)
                        )
                    )
                }
            }
        }
    }
}

// MARK: - MÀN HÌNH CHI TIẾT GAME (BENTO GRID 2 CỘT + SEGMENTED TABS GỌN ĐẸP)
private struct GameDetailView: View {
    let gameID: String
    @Binding var isTabBarHidden: Bool
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var selectedTabID = "aim"
    @State private var searchText = ""
    @State private var showSearchBar = false
    @State private var onlyActiveFilter = false
    @Namespace private var tabAnimation
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
        GridItem(.flexible(), spacing: 11),
        GridItem(.flexible(), spacing: 11)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            GeometryReader { geo in
                SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "photo"))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.38)
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.45), Color.black.opacity(0.88), Color.black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .ignoresSafeArea()
            
            VStack(spacing: 12) {
                // 1. TOP BAR TINH GỌN
                HStack(spacing: 10) {
                    Button {
                        iPhoneChimeEngine.shared.playSystemTock()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) { isTabBarHidden = false }
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(game?.name ?? "Danh sách Mod")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        HStack(spacing: 5) {
                            Circle()
                                .fill(activeCountInGame > 0 ? Color.cyan : Color.white.opacity(0.35))
                                .frame(width: 6, height: 6)
                            Text(activeCountInGame > 0 ? "Đang bật \(activeCountInGame) tính năng" : "Chạm thẻ để kích hoạt")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(activeCountInGame > 0 ? .cyan : .white.opacity(0.5))
                        }
                    }
                    
                    Spacer()
                    
                    // Nút lọc "Đang bật"
                    Button {
                        iPhoneChimeEngine.shared.playSystemTock()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            onlyActiveFilter.toggle()
                        }
                    } label: {
                        Text("\(activeCountInGame)")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundColor(onlyActiveFilter ? .black : .cyan)
                            .frame(width: 36, height: 36)
                            .background(onlyActiveFilter ? Color.cyan : Color.cyan.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.cyan.opacity(0.45), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    // Nút mở/đóng tìm kiếm nhanh
                    Button {
                        iPhoneChimeEngine.shared.playSystemTock()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            showSearchBar.toggle()
                            if !showSearchBar { searchText = "" }
                        }
                    } label: {
                        Image(systemName: showSearchBar ? "xmark" : "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                // THANH TÌM KIẾM ẨN/HIỆN THÔNG MINH
                if showSearchBar {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12.5))
                            .foregroundColor(.cyan)
                        TextField("Nhập tên tính năng cần tìm...", text: $searchText)
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
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // 2. SEGMENTED TAB BAR GỌN ĐẸP (KHÔNG BAO GIỜ TRÀN VIỀN)
                Group {
                    if availableTabs.count <= 3 {
                        HStack(spacing: 4) {
                            ForEach(availableTabs) { tab in
                                tabButtonView(tab: tab, stretch: true)
                            }
                        }
                        .padding(4)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                        .padding(.horizontal, 16)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(availableTabs) { tab in
                                    tabButtonView(tab: tab, stretch: false)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                
                // 3. LƯỚI BENTO 2 CỘT CHỨC NĂNG
                ScrollView(showsIndicators: false) {
                    if items.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "tray")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.3))
                            Text(onlyActiveFilter ? "Chưa có tính năng nào đang bật" : "Chưa có chức năng trong mục này")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    } else {
                        LazyVGrid(columns: columns, spacing: 11) {
                            ForEach(items) { item in
                                BentoModCard(item: item)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 2)
                        .padding(.bottom, 24)
                    }
                }
            }
            // DOCK KHỞI ĐỘNG GAME NỔI GỌN Ở ĐÁY
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    SecureCatalogImage(urlString: game?.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.2))
                    
                    Button {
                        guard isSessionActive else { return }
                        iPhoneChimeEngine.shared.playLaunchChime()
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        let rawLaunch = (game?.launchURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if let url = URL(string: rawLaunch), !rawLaunch.isEmpty {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .black))
                            Text("KHỞI ĐỘNG GAME")
                                .font(.system(size: 14.5, weight: .black, design: .monospaced))
                                .tracking(0.8)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(
                            LinearGradient(colors: [.white, .cyan], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                        .shadow(color: .cyan.opacity(0.45), radius: 12, y: 4)
                    }
                    .buttonStyle(SpringPressStyle())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
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
    private func tabButtonView(tab: GameCatalogTab, stretch: Bool) -> some View {
        let isSelected = selectedTabID == tab.id
        Button {
            iPhoneChimeEngine.shared.playSystemTock()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                selectedTabID = tab.id
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11.5, weight: .bold))
                Text(tab.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(isSelected ? .black : .white.opacity(0.75))
            .frame(maxWidth: stretch ? .infinity : nil)
            .padding(.horizontal, stretch ? 8 : 14)
            .padding(.vertical, 9)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(LinearGradient(colors: [.white, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .matchedGeometryEffect(id: "ACTIVE_TAB_BG", in: tabAnimation)
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

// MARK: - THẺ BENTO 2 CỘT (HIỆU ỨNG SÓNG + LASER SWEEP + TIẾNG TÍCH IPHONE)
private struct BentoModCard: View {
    let item: GameCatalogItem
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var showDetailSheet = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var sweepOffset: CGFloat = -160
    @State private var rippleScale: CGFloat = 0.6
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
        
        VStack(alignment: .leading, spacing: 10) {
            // HÀNG TRÊN: TRẠNG THÁI + NHÃN + HDSD
            HStack(spacing: 6) {
                ZStack {
                    // Vòng sóng lan tỏa khi kích hoạt
                    Circle()
                        .stroke(Color.cyan, lineWidth: 1.5)
                        .frame(width: 28, height: 28)
                        .scaleEffect(rippleScale)
                        .opacity(rippleOpacity)
                    
                    Circle()
                        .fill(isOn ? Color.cyan : Color.white.opacity(0.08))
                        .frame(width: 28, height: 28)
                    
                    if busy {
                        ProgressView()
                            .tint(isOn ? .black : .cyan)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: isOn ? "checkmark" : "power")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(isOn ? .black : .white.opacity(0.65))
                    }
                }
                
                Text(badgeLabel)
                    .font(.system(size: 8.5, weight: .black, design: .monospaced))
                    .foregroundColor(isHighlightedBadge ? .black : .white.opacity(0.8))
                    .padding(.horizontal, 6.5)
                    .padding(.vertical, 2.5)
                    .background(
                        isHighlightedBadge
                        ? AnyView(LinearGradient(colors: [.white, .cyan], startPoint: .leading, endPoint: .trailing))
                        : AnyView(Color.white.opacity(0.14))
                    )
                    .clipShape(Capsule())
                
                Spacer(minLength: 0)
                
                if hasGuide {
                    Button {
                        iPhoneChimeEngine.shared.playSystemTock()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showDetailSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer(minLength: 2)
            
            // HÀNG DƯỚI: TÊN CHỨC NĂNG + TRẠNG THÁI GỌN
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(busy ? "Đang nạp..." : (isOn ? "Đã kích hoạt" : subtitleDisplay))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(busy ? .yellow : (isOn ? .cyan : .white.opacity(0.45)))
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: isOn
                                ? [Color.cyan.opacity(0.22), Color.blue.opacity(0.08)]
                                : [Color.white.opacity(0.05), Color.black.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // TIA SÁNG QUÉT CHÉO KHI KÍCH HOẠT
                if isOn {
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.35), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 75)
                    .rotationEffect(.degrees(22))
                    .offset(x: sweepOffset)
                    .allowsHitTesting(false)
                }
            }
        )
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isOn
                    ? LinearGradient(colors: [.white, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isOn ? 1.5 : 1
                )
        )
        .shadow(color: isOn ? .cyan.opacity(0.28) : .clear, radius: 10, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !busy, (hasLink || isOn) else { return }
            toggleFeature(currentlyOn: isOn)
        }
        .opacity(hasLink ? 1 : 0.48)
        .animation(.spring(response: 0.26, dampingFraction: 0.75), value: isOn)
        .onChange(of: isOn) { active in
            if active {
                sweepOffset = -150
                rippleScale = 0.8
                rippleOpacity = 0.9
                withAnimation(.easeOut(duration: 0.55)) {
                    sweepOffset = 180
                    rippleScale = 1.9
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
            iPhoneChimeEngine.shared.playiPhoneTickOff()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { await store.setMultiEnabled(false, item: item) }
            return
        }
        
        guard isSessionActive else { return }
        
        iPhoneChimeEngine.shared.playiPhoneTickOn()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        
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
                                        iPhoneChimeEngine.shared.playSystemTock()
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
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
                                
                                if isYouTubeLink {
                                    Button {
                                        iPhoneChimeEngine.shared.playSystemTock()
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
                        iPhoneChimeEngine.shared.playSystemTock()
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
