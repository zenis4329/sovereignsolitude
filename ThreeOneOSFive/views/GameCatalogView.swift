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
        playSweep(startFreq: 440, endFreq: 1320, duration: 0.15, harmonic: true)
    }
    
    func playDeactivate() {
        playSweep(startFreq: 860, endFreq: 310, duration: 0.12, harmonic: false)
    }
    
    func playTap() {
        playSweep(startFreq: 1150, endFreq: 780, duration: 0.04, harmonic: false)
    }
    
    func playLaunch() {
        playSweep(startFreq: 260, endFreq: 1480, duration: 0.26, harmonic: true)
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
                    .transition(.opacity.animation(.easeInOut(duration: 0.28)))
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

// MARK: - MÀN HÌNH CHÍNH (BENTO COMMAND HUB)
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
                Color(red: 0.01, green: 0.015, blue: 0.03)
                    .ignoresSafeArea()
                
                // --- BACKGROUND ĐỘNG ---
                GeometryReader { geo in
                    SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "sparkles"))
                        .frame(width: geo.size.width, height: geo.size.height)
                        .opacity(0.55)
                        .overlay(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.35),
                                    Color(red: 0.01, green: 0.02, blue: 0.04).opacity(0.82),
                                    Color.black.opacity(0.96)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .ignoresSafeArea()
                
                CyberParticleCanvas()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        // HEADER BENTO GỌN GÀNG
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .stroke(
                                        AngularGradient(colors: [.cyan, .white, .blue, .cyan], center: .center),
                                        lineWidth: 2.5
                                    )
                                    .frame(width: 66, height: 66)
                                    .rotationEffect(.degrees(isRotating ? 360 : 0))
                                    .animation(.linear(duration: 4.5).repeatForever(autoreverses: false), value: isRotating)
                                    .drawingGroup()
                                
                                SecureCatalogImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                                    .frame(width: 58, height: 58)
                                    .clipShape(Circle())
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(authManager.publicAppName.isEmpty ? "𝐒𝐨𝐯𝐞𝐫𝐞𝐢𝐠𝐧 𝐒𝐨𝐥𝐢𝐭𝐮𝐝𝐞" : authManager.publicAppName)
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                HStack(spacing: 8) {
                                    HStack(spacing: 5) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 6, height: 6)
                                            .shadow(color: .green, radius: 4)
                                        Text("ONLINE")
                                            .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                            .foregroundColor(.cyan)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.cyan.opacity(0.12))
                                    .clipShape(Capsule())
                                    
                                    if totalEnabledMods > 0 {
                                        Text("\(totalEnabledMods) ĐANG BẬT")
                                            .font(.system(size: 9.5, weight: .black, design: .monospaced))
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.cyan)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(14)
                        .background(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        
                        // TIÊU ĐỀ DANH SÁCH GAME
                        HStack {
                            Text("CHỌN TRÒ CHƠI")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .tracking(1.4)
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("\(store.catalog.orderedGames.count) ỨNG DỤNG")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, -6)
                        
                        // DANH SÁCH GAME
                        VStack(spacing: 12) {
                            if store.catalog.orderedGames.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "gamecontroller")
                                        .font(.system(size: 28))
                                        .foregroundColor(.cyan.opacity(0.5))
                                    Text("Chưa có trò chơi nào được cấu hình")
                                        .font(.system(size: 13.5, weight: .medium))
                                        .foregroundColor(.white.opacity(0.55))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                                .background(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                                .cornerRadius(20)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
                                .padding(.horizontal, 16)
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
            SecureCatalogImage(urlString: game.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(LinearGradient(colors: [.cyan, .white.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                )
            
            VStack(alignment: .leading, spacing: 5) {
                Text(game.name)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
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
            
            HStack(spacing: 4) {
                Text("MỞ")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .black))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(LinearGradient(colors: [.cyan, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(Capsule())
            .shadow(color: .cyan.opacity(0.4), radius: 6)
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.03))
            }
        )
        .environment(\.colorScheme, .dark)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(
                    LinearGradient(colors: [.cyan.opacity(0.6), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1.2
                )
        )
    }
}

// MARK: - CUSTOM BUTTON STYLE
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
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
                        let xPos = p.x + sin(CGFloat(time) * 1.4 + p.y * 0.05) * 12
                        
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
                        CyberParticleItem(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height),
                            size: CGFloat.random(in: 1.8...3.8),
                            speed: CGFloat.random(in: 18...35),
                            opacity: Double.random(in: 0.18...0.55),
                            isCyan: i % 3 == 0
                        )
                    )
                }
            }
        }
    }
}

// MARK: - CHI TIẾT GAME (BỐ CỤC CHIA CỘT BENTO: SIDEBAR TRÁI + DANH SÁCH GỌN PHẢI)
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

    var body: some View {
        ZStack {
            Color(red: 0.01, green: 0.015, blue: 0.03)
                .ignoresSafeArea()
            
            GeometryReader { geo in
                SecureCatalogImage(urlString: authManager.publicBackgroundURL, placeholder: Image(systemName: "photo"))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(0.45)
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.5), Color.black.opacity(0.86), Color.black.opacity(0.97)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .ignoresSafeArea()
            
            VStack(spacing: 10) {
                // 1. TOP HEADER GỌN
                HStack(spacing: 10) {
                    Button {
                        CyberSoundEngine.shared.playTap()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
                        Text(game?.name ?? "Bảng điều khiển")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(activeCountInGame > 0 ? "Đang kích hoạt \(activeCountInGame) tính năng" : "Chạm thẻ để bật nhanh")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(activeCountInGame > 0 ? .cyan : .white.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    // Nút lọc nhanh "Đang bật"
                    Button {
                        CyberSoundEngine.shared.playTap()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.18)) {
                            onlyActiveFilter.toggle()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(onlyActiveFilter ? Color.black : Color.cyan)
                                .frame(width: 6, height: 6)
                            Text("Bật (\(activeCountInGame))")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                        }
                        .foregroundColor(onlyActiveFilter ? .black : .cyan)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(onlyActiveFilter ? Color.cyan : Color.cyan.opacity(0.14))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.cyan.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                
                // 2. THANH TÌM KIẾM SIÊU MẢNH
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.cyan.opacity(0.8))
                    
                    TextField("Tìm nhanh chức năng...", text: $searchText)
                        .font(.system(size: 12.5, weight: .medium))
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 14)
                
                // 3. KHU VỰC CHÍNH CHIA 2 CỘT (SIDEBAR DANH MỤC TRÁI + DANH SÁCH CHỨC NĂNG PHẢI)
                HStack(alignment: .top, spacing: 10) {
                    
                    // --- CỘT TRÁI: THANH DANH MỤC DỌC GỌN GÀNG ---
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(availableTabs) { tab in
                                let isSelected = selectedTabID == tab.id
                                let tabItems = (game?.items ?? []).filter { $0.hidden != true && $0.category.rawValue == tab.id }
                                let activeInTab = tabItems.filter { store.isMultiItemOn(item: $0) }.count
                                
                                Button {
                                    CyberSoundEngine.shared.playTap()
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.78)) {
                                        selectedTabID = tab.id
                                    }
                                } label: {
                                    VStack(spacing: 5) {
                                        ZStack(alignment: .topTrailing) {
                                            Image(systemName: tab.icon)
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(isSelected ? .black : .cyan)
                                                .frame(width: 34, height: 34)
                                                .background(
                                                    isSelected
                                                    ? Color.white.opacity(0.28)
                                                    : Color.cyan.opacity(0.12)
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                            
                                            if activeInTab > 0 {
                                                Circle()
                                                    .fill(isSelected ? Color.black : Color.green)
                                                    .frame(width: 7, height: 7)
                                                    .offset(x: 2, y: -2)
                                            }
                                        }
                                        
                                        Text(tab.title)
                                            .font(.system(size: 10, weight: .black, design: .rounded))
                                            .foregroundColor(isSelected ? .black : .white.opacity(0.85))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.8)
                                        
                                        Text("\(tabItems.count)")
                                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                                            .foregroundColor(isSelected ? .black.opacity(0.75) : .white.opacity(0.45))
                                    }
                                    .frame(width: 74)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 4)
                                    .background(
                                        Group {
                                            if isSelected {
                                                LinearGradient(colors: [.cyan, .mint], startPoint: .top, endPoint: .bottom)
                                            } else {
                                                Color.white.opacity(0.05)
                                            }
                                        }
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(isSelected ? Color.white.opacity(0.65) : Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                    .shadow(color: isSelected ? .cyan.opacity(0.35) : .clear, radius: 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .frame(width: 76)
                    
                    // --- CỘT PHẢI: DANH SÁCH CHỨC NĂNG SIÊU GỌN ---
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            if items.isEmpty {
                                VStack(spacing: 10) {
                                    Image(systemName: "tray")
                                        .font(.system(size: 26))
                                        .foregroundColor(.white.opacity(0.3))
                                    Text(onlyActiveFilter ? "Chưa có mục nào đang bật" : "Trống")
                                        .font(.system(size: 12.5, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 44)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
                            } else {
                                ForEach(items) { item in
                                    CompactModRow(item: item)
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
                .padding(.horizontal, 14)
            }
            // DOCK KHỞI ĐỘNG GAME NỔI GỌN Ở ĐÁY (KHÔNG CHE MẤT MỤC CUỐI)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    SecureCatalogImage(urlString: game?.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.cyan.opacity(0.5), lineWidth: 1))
                    
                    Button {
                        guard isSessionActive else { return }
                        CyberSoundEngine.shared.playLaunch()
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
                            LinearGradient(colors: [.cyan, Color(red: 0.15, green: 0.8, blue: 1.0)], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .cyan.opacity(0.45), radius: 10, y: 4)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.white.opacity(0.1)),
                    alignment: .top
                )
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

// MARK: - THẺ CHỨC NĂNG SIÊU GỌN (CHẠM CẢ THẺ ĐỂ BẬT/TẮT + LASER SWEEP + SFX)
private struct CompactModRow: View {
    let item: GameCatalogItem
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var showDetailSheet = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var sweepOffset: CGFloat = -220
    
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
        return cleanSub.isEmpty ? "Chạm để bật/tắt" : cleanSub
    }
    
    var body: some View {
        let hasLink = !item.resolvedFileURLs.isEmpty
        let isOn = store.isMultiItemOn(item: item)
        let busy = store.isMultiItemBusy(item: item)
        
        HStack(spacing: 10) {
            // THANH ĐÈN LED TRẠNG THÁI BÊN TRÁI
            RoundedRectangle(cornerRadius: 3)
                .fill(isOn ? Color.cyan : Color.white.opacity(0.18))
                .frame(width: 4, height: 34)
                .shadow(color: isOn ? .cyan : .clear, radius: 5)
            
            // TÊN & MÔ TẢ GỌN
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(item.name)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(badgeLabel)
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundColor(isHighlightedBadge ? .black : .white.opacity(0.8))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(
                            isHighlightedBadge
                            ? AnyView(LinearGradient(colors: [.cyan, .mint], startPoint: .leading, endPoint: .trailing))
                            : AnyView(Color.white.opacity(0.15))
                        )
                        .clipShape(Capsule())
                }
                
                Text(busy ? "Đang nạp gói dữ liệu..." : (isOn ? "Đang hoạt động" : subtitleDisplay))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(busy ? .yellow : (isOn ? .cyan : .white.opacity(0.48)))
                    .lineLimit(1)
            }
            
            Spacer(minLength: 4)
            
            // NÚT HDSD NHỎ (NẾU CÓ)
            if hasGuide {
                Button {
                    CyberSoundEngine.shared.playTap()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showDetailSheet = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.cyan.opacity(0.85))
                        .frame(width: 28, height: 28)
                        .background(Color.cyan.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            // CHỈ BÁO BẬT / TẮT GỌN
            ZStack {
                if busy {
                    ProgressView()
                        .tint(.cyan)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isOn ? .cyan : .white.opacity(0.28))
                        .shadow(color: isOn ? .cyan.opacity(0.6) : .clear, radius: 5)
                }
            }
            .frame(width: 28, height: 28)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            colors: isOn
                                ? [Color.cyan.opacity(0.18), Color.blue.opacity(0.08)]
                                : [Color.white.opacity(0.06), Color.white.opacity(0.03)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                // HIỆU ỨNG LASER QUÉT NGANG KHI KÍCH HOẠT
                if isOn {
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.32), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 90)
                    .rotationEffect(.degrees(18))
                    .offset(x: sweepOffset)
                    .allowsHitTesting(false)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(
                    isOn ? Color.cyan.opacity(0.85) : Color.white.opacity(0.1),
                    lineWidth: isOn ? 1.3 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard !busy, (hasLink || isOn) else { return }
            toggleFeature(currentlyOn: isOn)
        }
        .opacity(hasLink ? 1 : 0.48)
        .animation(.spring(response: 0.25, dampingFraction: 0.78), value: isOn)
        .onChange(of: isOn) { active in
            if active {
                sweepOffset = -220
                withAnimation(.easeOut(duration: 0.6)) {
                    sweepOffset = 240
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
