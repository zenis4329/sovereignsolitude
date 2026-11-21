import SwiftUI
import UIKit
import AVFoundation

// MARK: - BỘ PHÁT ÂM THANH CYBER SFX KHÔNG CẦN FILE MP3 (0ms LAG)
final class CyberSoundEngine {
    static let shared = CyberSoundEngine()
    
    private var engine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
    private let sampleRate: Double = 44100.0
    private var isSetup = false
    private let audioQueue = DispatchQueue(label: "com.zenis.cyber.sfx", qos: .userInteractive)
    
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
            self.engine.mainMixerNode.outputVolume = 0.45
            try? self.engine.start()
            self.isSetup = true
        }
    }
    
    func playActivate() {
        // Tiếng Power-Up quét tần số từ 420Hz -> 1280Hz
        playSweep(startFreq: 420, endFreq: 1280, duration: 0.16, harmonic: true)
    }
    
    func playDeactivate() {
        // Tiếng Power-Down hạ tần số từ 880Hz -> 320Hz
        playSweep(startFreq: 880, endFreq: 320, duration: 0.13, harmonic: false)
    }
    
    func playTap() {
        // Tiếng Click ngắn gọn
        playSweep(startFreq: 1100, endFreq: 750, duration: 0.045, harmonic: false)
    }
    
    func playLaunch() {
        // Tiếng khởi động game uy lực
        playSweep(startFreq: 260, endFreq: 1450, duration: 0.28, harmonic: true)
    }
    
    private func playSweep(startFreq: Double, endFreq: Double, duration: Double, harmonic: Bool) {
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.engine.isRunning {
                try? self.engine.start()
            }
            
            let format = AVAudioFormat(standardFormatWithSampleRate: self.sampleRate, channels: 1)!
            let frameCount = AVAudioFrameCount(self.sampleRate * duration)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
            buffer.frameLength = frameCount
            
            let data = buffer.floatChannelData![0]
            var phase: Double = 0
            var phase2: Double = 0
            
            for i in 0..<Int(frameCount) {
                let progress = Double(i) / Double(frameCount)
                let currentFreq = startFreq + (endFreq - startFreq) * pow(progress, 0.85)
                
                // Envelope chống rè đầu/cuối âm
                let attack = min(1.0, progress * 18.0)
                let release = pow(1.0 - progress, 1.4)
                let envelope = Float(attack * release) * 0.35
                
                phase += (2.0 * .pi * currentFreq) / self.sampleRate
                var sample = sin(phase)
                
                if harmonic {
                    phase2 += (2.0 * .pi * (currentFreq * 1.5)) / self.sampleRate
                    sample = sample * 0.72 + sin(phase2) * 0.28
                }
                
                data[i] = Float(sample) * envelope
            }
            
            self.player.stop()
            self.player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
            self.player.play()
        }
    }
}

// MARK: - BỘ TẢI ẢNH AN TOÀN + CACHE RAM CHỐNG LOAD LẠI
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
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            } else {
                placeholder
                    .resizable()
                    .scaledToFit()
                    .padding(10)
                    .foregroundColor(.white.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .tint(.cyan)
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

// MARK: - MÀN HÌNH CHÍNH (TACTICAL HUB GỌN 1 KHUNG)
struct GameCatalogView: View {
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @Binding var isTabBarHidden: Bool
    
    @State private var isRotating = false
    @State private var pulseGlow = false
    
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
                Color(red: 0.012, green: 0.02, blue: 0.04)
                    .ignoresSafeArea()
                
                // --- BACKGROUND ĐỘNG ---
                GeometryReader { geo in
                    SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "sparkles"))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .opacity(0.6)
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.3),
                                    Color(red: 0.015, green: 0.03, blue: 0.06).opacity(0.78),
                                    Color(red: 0.01, green: 0.015, blue: 0.03).opacity(0.96)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .ignoresSafeArea()
                
                // --- ÁNH SÁNG AMBIENT NEON ---
                Circle()
                    .fill(Color.cyan.opacity(pulseGlow ? 0.18 : 0.1))
                    .frame(width: 280, height: 280)
                    .blur(radius: 85)
                    .offset(x: -90, y: -250)
                    .ignoresSafeArea()
                
                // --- HẠT NĂNG LƯỢNG BAY NHẸ (60FPS GPU) ---
                CyberParticleCanvas()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                
                // --- NỘI DUNG CHÍNH ---
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        
                        // TOP BAR NHỎ GỌN
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "cpu.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.cyan)
                                Text("SOVEREIGN OS")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .tracking(1.1)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
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
                                Text(totalEnabledMods > 0 ? "\(totalEnabledMods) ACTIVE" : "ONLINE")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .tracking(0.8)
                                    .foregroundColor(.cyan)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.cyan.opacity(0.45), lineWidth: 1))
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        
                        // HERO AVATAR & TÊN THƯƠNG HIỆU (THU GỌN CHIỀU CAO ĐỂ THẤY GAME NGAY)
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.cyan.opacity(0.22))
                                    .frame(width: 112, height: 112)
                                    .blur(radius: 18)
                                
                                Circle()
                                    .stroke(
                                        AngularGradient(
                                            gradient: Gradient(colors: [.cyan, .blue, .purple, .cyan]),
                                            center: .center
                                        ),
                                        lineWidth: 3
                                    )
                                    .frame(width: 96, height: 96)
                                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                                    .animation(.linear(duration: 4).repeatForever(autoreverses: false), value: isRotating)
                                    .drawingGroup()
                                
                                Circle()
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                    .foregroundColor(.cyan.opacity(0.45))
                                    .frame(width: 106, height: 106)
                                    .rotationEffect(.degrees(isRotating ? -360 : 0))
                                    .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: isRotating)
                                    .drawingGroup()
                                
                                SecureCatalogImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                                    .frame(width: 86, height: 86)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                            }
                            
                            VStack(spacing: 3) {
                                Text(authManager.publicAppName.isEmpty ? "𝐒𝐨𝐯𝐞𝐫𝐞𝐢𝐠𝐧 𝐒𝐨𝐥𝐢𝐭𝐮𝐝𝐞" : authManager.publicAppName)
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.white, .cyan.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                                    )
                                    .shadow(color: .cyan.opacity(0.55), radius: 10)
                                
                                Text("Chạm vào trò chơi để mở bảng điều khiển")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.55))
                            }
                        }
                        
                        // TIÊU ĐỀ KHU VỰC GAME
                        HStack {
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.cyan)
                                    .frame(width: 3, height: 13)
                                Text("TRÒ CHƠI HỖ TRỢ")
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    .tracking(1.3)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            
                            Spacer()
                            
                            Text("\(store.catalog.orderedGames.count) GAME")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.cyan.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        
                        // DANH SÁCH GAME CARDS
                        VStack(spacing: 12) {
                            if store.catalog.orderedGames.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "gamecontroller")
                                        .font(.system(size: 30))
                                        .foregroundColor(.cyan.opacity(0.5))
                                    Text("Chưa có trò chơi nào được cấu hình")
                                        .font(.system(size: 13.5, weight: .medium))
                                        .foregroundColor(.white.opacity(0.55))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 36)
                                .background(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                                .cornerRadius(20)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                .padding(.horizontal, 18)
                            } else {
                                ForEach(store.catalog.orderedGames) { game in
                                    NavigationLink(destination: GameDetailView(gameID: game.id, isTabBarHidden: $isTabBarHidden)) {
                                        GameCatalogCardRow(game: game)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .disabled(!isSessionActive)
                                    .simultaneousGesture(TapGesture().onEnded {
                                        guard isSessionActive else { return }
                                        CyberSoundEngine.shared.playTap()
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
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    pulseGlow = true
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
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.16))
                    .frame(width: 58, height: 58)
                
                SecureCatalogImage(urlString: game.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 2
                        )
                    )
                    .shadow(color: .cyan.opacity(0.45), radius: 7)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(game.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Label("\(activeVisibleItemsCount) tính năng", systemImage: "square.grid.2x2.fill")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    if enabledModCount > 0 {
                        Text("\(enabledModCount) đang bật")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.cyan)
                            .clipShape(Capsule())
                    }
                }
            }
            
            Spacer()
            
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 36, height: 36)
                    .shadow(color: .cyan.opacity(0.5), radius: 8)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13.5, weight: .heavy))
                    .foregroundColor(.white)
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
                            colors: [Color.white.opacity(0.08), Color.black.opacity(0.28)],
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
                    LinearGradient(
                        colors: [.cyan.opacity(0.65), .white.opacity(0.1), .blue.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
    }
}

// MARK: - CUSTOM BUTTON STYLE
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - HIỆU ỨNG HẠT CYBER BAY NHẸ (60FPS GPU)
struct CyberParticleItem: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var speed: CGFloat
    var opacity: Double
    var isCyan: Bool
}

struct CyberParticleCanvas: View {
    @State private var particles: [CyberParticleItem] = []
    
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    for p in particles {
                        let rawY = p.y - CGFloat(time) * p.speed
                        let yPos = (rawY.truncatingRemainder(dividingBy: size.height + 60) + size.height + 60)
                            .truncatingRemainder(dividingBy: size.height + 60) - 30
                        let xPos = p.x + sin(CGFloat(time) * 1.4 + p.y * 0.05) * 14
                        
                        context.opacity = p.opacity
                        let rect = CGRect(x: xPos, y: yPos, width: p.size, height: p.size)
                        context.fill(Path(ellipseIn: rect), with: .color(p.isCyan ? .cyan : .white))
                    }
                }
            }
            .onAppear {
                guard particles.isEmpty else { return }
                for i in 0..<28 {
                    particles.append(
                        CyberParticleItem(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height),
                            size: CGFloat.random(in: 1.8...4.2),
                            speed: CGFloat.random(in: 18...38),
                            opacity: Double.random(in: 0.2...0.65),
                            isCyan: i % 3 == 0
                        )
                    )
                }
            }
        }
    }
}

// MARK: - CHI TIẾT GAME (LƯỚI 2 CỘT GỌN ĐẸP + TÌM KIẾM NHANH)
private struct GameDetailView: View {
    let gameID: String
    @Binding var isTabBarHidden: Bool
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var selectedTabID = "aim"
    @State private var searchText = ""
    @State private var onlyActiveFilter = false
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
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: 11),
        GridItem(.flexible(), spacing: 11)
    ]

    var body: some View {
        ZStack {
            Color(red: 0.012, green: 0.02, blue: 0.04)
                .ignoresSafeArea()
            
            GeometryReader { geo in
                SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "photo"))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.5)
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.45), Color.black.opacity(0.84), Color.black.opacity(0.96)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // HEADER NHỎ GỌN
                HStack(spacing: 12) {
                    Button {
                        CyberSoundEngine.shared.playTap()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) { isTabBarHidden = false }
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.cyan.opacity(0.45), lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(game?.name ?? "Danh sách Mod")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(activeCountInGame > 0 ? "Đang bật \(activeCountInGame) tính năng" : "Sẵn sàng kích hoạt")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(activeCountInGame > 0 ? .cyan : .white.opacity(0.55))
                    }
                    
                    Spacer()
                    
                    SecureCatalogImage(urlString: game?.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                        .frame(width: 38, height: 38)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.cyan.opacity(0.4), lineWidth: 1))
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)
                
                // THANH TAB PILL NGANG
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableTabs) { tab in
                            let isSelected = selectedTabID == tab.id
                            let tabItemCount = (game?.items ?? []).filter { $0.hidden != true && $0.category.rawValue == tab.id }.count
                            
                            Button {
                                CyberSoundEngine.shared.playTap()
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                    selectedTabID = tab.id
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 12, weight: .bold))
                                    Text(tab.title)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                    Text("\(tabItemCount)")
                                        .font(.system(size: 10, weight: .black, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(isSelected ? Color.black.opacity(0.18) : Color.white.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                                .foregroundColor(isSelected ? .black : .white.opacity(0.85))
                                .padding(.horizontal, 13)
                                .padding(.vertical, 8.5)
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
                                        .stroke(isSelected ? Color.white.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1)
                                )
                                .shadow(color: isSelected ? .cyan.opacity(0.4) : .clear, radius: 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }
                .padding(.bottom, 8)
                
                // THANH TÌM KIẾM + LỌC ĐANG BẬT SIÊU GỌN
                HStack(spacing: 8) {
                    HStack(spacing: 7) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.cyan.opacity(0.8))
                        
                        TextField("Tìm nhanh tính năng...", text: $searchText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .tint(.cyan)
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                        }
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                    
                    Button {
                        CyberSoundEngine.shared.playTap()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            onlyActiveFilter.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(onlyActiveFilter ? Color.black : Color.cyan)
                                .frame(width: 6, height: 6)
                            Text("Đang bật")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(onlyActiveFilter ? .black : .cyan)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(onlyActiveFilter ? Color.cyan : Color.cyan.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                
                // LƯỚI 2 CỘT CHỨC NĂNG (GỌN GÀNG - XEM ĐƯỢC NHIỀU MỤC CÙNG LÚC)
                ScrollView(showsIndicators: false) {
                    if items.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "tray")
                                .font(.system(size: 30))
                                .foregroundColor(.white.opacity(0.3))
                            Text(onlyActiveFilter ? "Chưa có tính năng nào đang bật ở tab này" : "Chưa có chức năng nào trong mục này")
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 44)
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .cornerRadius(18)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: 11) {
                            ForEach(items) { item in
                                ModGridTile(item: item)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 105)
                    }
                }
            }
            
            // NÚT KHỞI ĐỘNG GAME NỔI Ở ĐÁY
            VStack {
                Spacer()
                Button {
                    guard isSessionActive else { return }
                    CyberSoundEngine.shared.playLaunch()
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    let rawLaunch = (game?.launchURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if let url = URL(string: rawLaunch), !rawLaunch.isEmpty {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 15, weight: .black))
                        Text("KHỞI ĐỘNG GAME")
                            .font(.system(size: 15.5, weight: .black, design: .monospaced))
                            .tracking(1)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(colors: [.cyan, Color(red: 0.12, green: 0.78, blue: 1.0)], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.6), lineWidth: 1.2))
                    .shadow(color: .cyan.opacity(0.5), radius: 16, y: 6)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.horizontal, 18)
                .padding(.bottom, 20)
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

// MARK: - THẺ LƯỚI 2 CỘT SIÊU GỌN + HIỆU ỨNG LASER SWEEP + ÂM THANH SFX
private struct ModGridTile: View {
    let item: GameCatalogItem
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var showDetailSheet = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var sweepOffset: CGFloat = -160
    
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
        return cleanSub.isEmpty ? "Sẵn sàng kích hoạt" : cleanSub
    }
    
    var body: some View {
        let hasLink = !item.resolvedFileURLs.isEmpty
        let isOn = store.isMultiItemOn(item: item)
        let busy = store.isMultiItemBusy(item: item)
        
        VStack(alignment: .leading, spacing: 10) {
            // HÀNG TRÊN: AVATAR NHỎ + BADGE + NÚT HDSD
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isOn ? Color.cyan.opacity(0.24) : Color.white.opacity(0.06))
                        .frame(width: 34, height: 34)
                        .overlay(Circle().stroke(isOn ? Color.cyan : Color.white.opacity(0.14), lineWidth: 1.2))
                    
                    if !authManager.publicAvatarURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        SecureCatalogImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "bolt.fill"))
                            .frame(width: 30, height: 30)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: isOn ? "bolt.fill" : "shield")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(isOn ? .cyan : .white.opacity(0.6))
                    }
                }
                
                Text(badgeLabel)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundColor(isHighlightedBadge ? .black : .white.opacity(0.85))
                    .padding(.horizontal, 6.5)
                    .padding(.vertical, 2.5)
                    .background(
                        Group {
                            if isHighlightedBadge {
                                LinearGradient(colors: [.cyan, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                            } else {
                                Color.white.opacity(0.16)
                            }
                        }
                    )
                    .clipShape(Capsule())
                
                Spacer(minLength: 0)
                
                if hasGuide {
                    Button {
                        CyberSoundEngine.shared.playTap()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showDetailSheet = true
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.cyan.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // TÊN CHỨC NĂNG & MÔ TẢ
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(subtitleDisplay)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isOn ? .cyan.opacity(0.85) : .white.opacity(0.5))
                    .lineLimit(1)
            }
            
            // NÚT KÍCH HOẠT NGUYÊN KHỐI (CHẠM CỰC NHẠY + PHÁT TIẾNG)
            Button {
                guard !busy, (hasLink || isOn) else { return }
                toggleFeature(currentlyOn: isOn)
            } label: {
                HStack(spacing: 6) {
                    if busy {
                        ProgressView()
                            .tint(isOn ? .cyan : .black)
                            .scaleEffect(0.8)
                        Text("ĐANG NẠP...")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                    } else {
                        Image(systemName: isOn ? "checkmark.circle.fill" : "power")
                            .font(.system(size: 11.5, weight: .black))
                        Text(isOn ? "ĐANG BẬT" : "KÍCH HOẠT")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .tracking(0.5)
                    }
                }
                .foregroundColor(isOn ? .black : .cyan)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(
                    Group {
                        if isOn {
                            LinearGradient(colors: [.cyan, .mint], startPoint: .leading, endPoint: .trailing)
                        } else {
                            Color.cyan.opacity(0.14)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isOn ? Color.white.opacity(0.5) : Color.cyan.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(busy || (!hasLink && !isOn))
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: isOn
                                ? [Color.cyan.opacity(0.16), Color.blue.opacity(0.08)]
                                : [Color.white.opacity(0.04), Color.black.opacity(0.22)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // TIA LASER QUÉT NGANG KHI KÍCH HOẠT
                if isOn {
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.28), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 70)
                    .rotationEffect(.degrees(20))
                    .offset(x: sweepOffset)
                    .allowsHitTesting(false)
                }
            }
        )
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    isOn ? Color.cyan.opacity(0.9) : Color.white.opacity(0.12),
                    lineWidth: isOn ? 1.5 : 1
                )
        )
        .shadow(color: isOn ? .cyan.opacity(0.25) : .black.opacity(0.28), radius: 8, y: 4)
        .opacity(hasLink ? 1 : 0.52)
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isOn)
        .onChange(of: isOn) { active in
            if active {
                sweepOffset = -150
                withAnimation(.easeOut(duration: 0.65)) {
                    sweepOffset = 180
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
            CyberSoundEngine.shared.playDeactivate()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { await store.setMultiEnabled(false, item: item) }
            return
        }
        
        guard isSessionActive else { return }
        
        CyberSoundEngine.shared.playActivate()
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
                Color(red: 0.015, green: 0.025, blue: 0.05).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 18) {
                        if let imgURL = item.imageURL, !imgURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            SecureCatalogImage(urlString: imgURL, placeholder: Image(systemName: "photo"))
                                .frame(maxWidth: .infinity)
                                .frame(height: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cyan.opacity(0.5), lineWidth: 1))
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
                                        CyberSoundEngine.shared.playTap()
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
                                        CyberSoundEngine.shared.playTap()
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
                    Button("Đóng") {
                        CyberSoundEngine.shared.playTap()
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
