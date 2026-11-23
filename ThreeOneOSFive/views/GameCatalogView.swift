import SwiftUI
import UIKit
import AudioToolbox
import Combine

// ==========================================================
// MARK: - 🔊 HAPTICS + ÂM THANH
// ==========================================================
final class iPhoneHaptics {
    static let shared = iPhoneHaptics()
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let soft  = UIImpactFeedbackGenerator(style: .soft)
    private init() { rigid.prepare(); light.prepare(); heavy.prepare(); soft.prepare() }

    func playTickOn() {
        AudioServicesPlaySystemSound(1520)
        rigid.impactOccurred(intensity: 1.0); rigid.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.055) {
            self.soft.impactOccurred(intensity: 0.65); self.soft.prepare()
        }
    }
    func playTickOff() { AudioServicesPlaySystemSound(1104); light.impactOccurred(intensity: 0.7); light.prepare() }
    func playTap()     { AudioServicesPlaySystemSound(1103); light.impactOccurred(intensity: 0.5); light.prepare() }
    func playLaunch() {
        AudioServicesPlaySystemSound(1306)
        heavy.impactOccurred(intensity: 1.0); heavy.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            self.rigid.impactOccurred(intensity: 0.85); self.rigid.prepare()
        }
    }
}

// ==========================================================
// MARK: - IMAGE CACHE
// ==========================================================
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
            Color.white.opacity(0.04)
            if let image = image {
                Image(uiImage: image).resizable().scaledToFill()
                    .transition(.opacity.animation(.easeOut(duration: 0.25)))
            } else {
                placeholder.resizable().scaledToFit().padding(7)
                    .foregroundColor(.white.opacity(0.4))
                    .overlay(ProgressView().tint(.white).scaleEffect(0.65).opacity(isLoading ? 1 : 0))
            }
        }
        .clipped()
        .onAppear { loadImage() }
        .onChange(of: urlString) { _ in image = nil; isLoading = true; loadImage() }
    }

    private func loadImage() {
        let cleanUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUrl.isEmpty else { isLoading = false; return }
        if let cached = CatalogImageCache.shared.object(forKey: cleanUrl as NSString) {
            self.image = cached; self.isLoading = false; return
        }
        guard !SecureNetworkManager.shared.isProxyEnabled(), let url = URL(string: cleanUrl) else {
            isLoading = false; return
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

// ==========================================================
// MARK: - 🌌 BACKGROUND EFFECTS (TỐI ƯU GPU - KHÔNG BLUR NẶNG)
// ==========================================================
private struct UnifiedSpaceCanvas: View {
    let particleCount: Int
    let starCount: Int

    struct Star {
        let xRatio: CGFloat; let yRatio: CGFloat; let size: CGFloat; let phase: Double; let speed: Double
    }
    struct Particle {
        let xRatio: CGFloat; let startOffset: Double; let speed: Double; let size: CGFloat; let opacity: Double; let sway: Double; let brightness: Double
    }

    @State private var stars: [Star] = []
    @State private var particles: [Particle] = []

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 36.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas(opaque: false, rendersAsynchronously: true) { ctx, size in
                    // 1. Sao nhấp nháy
                    for s in stars {
                        let alpha = 0.16 + 0.65 * (0.5 + 0.5 * sin(t * s.speed + s.phase))
                        let rect = CGRect(x: s.xRatio * size.width, y: s.yRatio * size.height, width: s.size, height: s.size)
                        ctx.fill(Ellipse().path(in: rect), with: .color(.white.opacity(alpha)))
                    }

                    // 2. Hạt rơi trắng neon
                    let heightSpan = Double(size.height) + 40
                    for p in particles {
                        let travel = (p.startOffset + t * p.speed).truncatingRemainder(dividingBy: heightSpan) - 20
                        let sway = sin(t * 0.55 + p.sway) * 6
                        let rect = CGRect(x: p.xRatio * size.width + CGFloat(sway), y: CGFloat(travel), width: p.size, height: p.size)
                        ctx.fill(Ellipse().path(in: rect), with: .color(Color(white: p.brightness).opacity(p.opacity)))
                    }

                    // 3. Sao băng trắng
                    for i in 0..<3 {
                        let period = 5.0 + Double(i) * 2.1
                        let offset = Double(i) * 1.7
                        let progress = (t + offset).truncatingRemainder(dividingBy: period) / period
                        if progress < 0.11 {
                            let localProgress = progress / 0.11
                            let startX = size.width * (0.08 + Double(i) * 0.3)
                            let startY = size.height * (0.06 + Double(i % 2) * 0.14)
                            let length: CGFloat = 120
                            let x = startX + localProgress * 460
                            let y = startY + localProgress * 340
                            let alpha = 1.0 - localProgress

                            var path = Path()
                            path.move(to: CGPoint(x: x - length, y: y - length * 0.74))
                            path.addLine(to: CGPoint(x: x, y: y))
                            ctx.stroke(
                                path,
                                with: .linearGradient(
                                    Gradient(colors: [.clear, Color.white.opacity(alpha * 0.45), Color.white.opacity(alpha)]),
                                    startPoint: CGPoint(x: x - length, y: y - length * 0.74),
                                    endPoint: CGPoint(x: x, y: y)
                                ),
                                style: StrokeStyle(lineWidth: 1.3, lineCap: .round)
                            )
                            let head = CGRect(x: x - 2, y: y - 2, width: 4, height: 4)
                            ctx.fill(Ellipse().path(in: head), with: .color(.white.opacity(alpha)))
                        }
                    }
                }
            }
            .onAppear {
                if stars.isEmpty {
                    stars = (0..<starCount).map { _ in
                        Star(xRatio: .random(in: 0...1), yRatio: .random(in: 0...1), size: .random(in: 1...2.4), phase: .random(in: 0...6.28), speed: .random(in: 1.2...3.0))
                    }
                }
                if particles.isEmpty {
                    let h = max(Double(geo.size.height), 600)
                    particles = (0..<particleCount).map { _ in
                        Particle(xRatio: .random(in: 0...1), startOffset: .random(in: 0...h), speed: .random(in: 10...26), size: .random(in: 1.2...3.2), opacity: .random(in: 0.25...0.75), sway: .random(in: 0...6.28), brightness: [1.0, 0.88, 0.75].randomElement() ?? 1.0)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct ModernBackground: View {
    let urlString: String
    var particleCount: Int = 26

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                SecureCatalogImage(urlString: urlString, placeholder: Image(systemName: "sparkles"))
                    .frame(width: geo.size.width, height: geo.size.height)
                    .saturation(0.25)
                    .opacity(0.38)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.42),
                        Color.black.opacity(0.72),
                        Color.black.opacity(0.94)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [Color.white.opacity(0.08), Color.clear],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: 320
                )
                RadialGradient(
                    colors: [Color.white.opacity(0.05), Color.clear],
                    center: .bottomTrailing,
                    startRadius: 10,
                    endRadius: 280
                )

                UnifiedSpaceCanvas(particleCount: particleCount, starCount: 34)
            }
        }
        .ignoresSafeArea()
    }
}

// ==========================================================
// MARK: - 🌟 SPARKLE BURST (TRẮNG NEON)
// ==========================================================
struct SparkleBurst: View {
    let trigger: Bool
    var body: some View {
        ZStack {
            ForEach(0..<8) { i in
                let angle = Double(i) * .pi / 4
                Circle()
                    .fill(Color.white)
                    .frame(width: 4.5, height: 4.5)
                    .offset(
                        x: trigger ? CGFloat(cos(angle)) * 32 : 0,
                        y: trigger ? CGFloat(sin(angle)) * 32 : 0
                    )
                    .opacity(trigger ? 0 : 1)
                    .scaleEffect(trigger ? 1.7 : 0.3)
            }
        }
        .allowsHitTesting(false)
    }
}

// ==========================================================
// MARK: - 🌟 AVATAR ORBITS
// ==========================================================
struct AvatarOrbits: View {
    let ringSize: CGFloat; let dotCount: Int; let dotSize: CGFloat; let speed: Double; let color: Color; var reverse: Bool = false
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 36.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas(opaque: false, rendersAsynchronously: true) { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let outerRadius = size.width / 2 - dotSize
                let innerRadius = outerRadius - 5.5

                for i in 0..<dotCount {
                    let direction = reverse ? -1.0 : 1.0
                    let angle = t * speed * direction + Double(i) * (.pi * 2 / Double(dotCount))
                    let x = center.x + CGFloat(cos(angle)) * outerRadius
                    let y = center.y + CGFloat(sin(angle)) * outerRadius
                    let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                    ctx.fill(Ellipse().path(in: rect.insetBy(dx: -1.4, dy: -1.4)), with: .color(color.opacity(0.3)))
                    ctx.fill(Ellipse().path(in: rect), with: .color(color))
                }

                let innerCount = max(4, dotCount - 3)
                let innerDot = max(2.2, dotSize - 0.8)
                for i in 0..<innerCount {
                    let angle = -t * (speed * 1.3) + Double(i) * (.pi * 2 / Double(innerCount))
                    let x = center.x + CGFloat(cos(angle)) * innerRadius
                    let y = center.y + CGFloat(sin(angle)) * innerRadius
                    let rect = CGRect(x: x - innerDot / 2, y: y - innerDot / 2, width: innerDot, height: innerDot)
                    ctx.fill(Ellipse().path(in: rect), with: .color(Color(white: 0.75).opacity(0.85)))
                }
            }
        }
        .frame(width: ringSize, height: ringSize)
        .allowsHitTesting(false)
    }
}

struct ClassicScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.965 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// ==========================================================
// MARK: - STATUS CARD HELPER (NỀN ĐEN VIỀN TRẮNG NEON)
// ==========================================================
struct StatusCard: View {
    let icon: String; let title: String; let value: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.85), Color.white.opacity(0.25), Color.white.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.1
                )
        )
    }
}

// ==========================================================
// MARK: - MÀN HÌNH CHÍNH
// ==========================================================
struct GameCatalogView: View {
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @Binding var isTabBarHidden: Bool
    @State private var ringRotate: Double = 0
    @State private var isDisablingAll = false
    
    // Nút gạt ANTIBAN (Chỉ làm cảnh)
    @AppStorage("isAntiBanFakeEnabled") private var isAntiBanFakeEnabled: Bool = true

    private var isSessionActive: Bool {
        authManager.isAuthorized
        && !authManager.isInteractionLocked
        && !store.catalog.resolvedMaintenanceEnabled
        && AntiDebug.checkEnvironment() == .safe
    }

    private var allEnabledItems: [GameCatalogItem] {
        store.catalog.orderedGames
            .flatMap { $0.items }
            .filter { store.isMultiItemOn(item: $0) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ModernBackground(urlString: authManager.publicBackgroundURL, particleCount: 24)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        profileCard
                        featuredGameCard
                        systemStatusSection
                        antiBanBanner
                    }
                    .padding(.bottom, 100)
                }
                .disabled(!isSessionActive)
                .allowsHitTesting(isSessionActive)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                authManager.enforceImmediateOfflineExpirationCheck()
                store.rememberCatalogItems()
                withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) { ringRotate = 360 }
                if !isSessionActive {
                    forceDisableAllMods(playSound: false)
                }
            }
            .onChange(of: isSessionActive) { active in
                if !active {
                    isTabBarHidden = false
                    forceDisableAllMods(playSound: false)
                }
            }
            .onChange(of: authManager.isAuthorized) { a in
                if !a {
                    isTabBarHidden = false
                    forceDisableAllMods(playSound: false)
                }
            }
            .onChange(of: store.catalog.resolvedMaintenanceEnabled) { m in
                if m {
                    isTabBarHidden = false
                    forceDisableAllMods(playSound: false)
                }
            }
        }
    }

    private func forceDisableAllMods(playSound: Bool = true) {
        guard !isDisablingAll else { return }
        let targets = allEnabledItems
        if playSound { iPhoneHaptics.shared.playTickOff() }
        isDisablingAll = true
        Task {
            store.disableAllEnabledMods()
            for item in targets {
                if store.isMultiItemOn(item: item) {
                    await store.setMultiEnabled(false, item: item)
                }
            }
            await MainActor.run {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) {
                    isDisablingAll = false
                }
            }
        }
    }

    // MARK: PROFILE CARD
    private var profileCard: some View {
        HStack(spacing: 14) {
            avatarView

            VStack(alignment: .leading, spacing: 5) {
                Text(authManager.publicAppName.isEmpty ? "Sovereign Solitude" : authManager.publicAppName)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white).lineLimit(1)
                    .shadow(color: .white.opacity(0.45), radius: 5)
                
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text("Online").font(.system(size: 9.5, weight: .bold)).foregroundColor(.white)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 2.5)
                    .background(Color.black.opacity(0.75)).clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.45), lineWidth: 0.8))
                    
                    if isAntiBanFakeEnabled {
                        HStack(spacing: 4) {
                            Image(systemName: "shield.checkered").font(.system(size: 9, weight: .bold))
                            Text("ANTIBAN").font(.system(size: 9.5, weight: .black, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 7).padding(.vertical, 2.5)
                        .background(Color.white.opacity(0.14)).clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.8), lineWidth: 0.9))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }

            Spacer(minLength: 4)

            if totalEnabledAll > 0 || isDisablingAll {
                Button {
                    forceDisableAllMods(playSound: true)
                } label: {
                    VStack(spacing: 2) {
                        if isDisablingAll {
                            ProgressView().tint(.black).scaleEffect(0.75)
                        } else {
                            Image(systemName: "power").font(.system(size: 13, weight: .black))
                        }
                        Text(isDisablingAll ? "Đang tắt" : "Tắt hết")
                            .font(.system(size: 8.5, weight: .black))
                    }
                    .foregroundColor(.black).frame(width: 48, height: 48)
                    .background(LinearGradient(colors: [.white, Color(white: 0.86)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Color.white, lineWidth: 1))
                }
                .disabled(isDisablingAll)
                .buttonStyle(ClassicScaleButtonStyle())
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.black.opacity(0.78)))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white, Color.white.opacity(0.35), Color.white.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.3
                )
        )
        .shadow(color: .white.opacity(0.2), radius: 10)
        .padding(.horizontal, 16).padding(.top, 10)
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color.white.opacity(0.32), Color.clear], center: .center, startRadius: 22, endRadius: 44))
                .frame(width: 88, height: 88)
            AvatarOrbits(ringSize: 84, dotCount: 7, dotSize: 3.2, speed: 0.65, color: .white)
            Circle()
                .stroke(AngularGradient(colors: [.white, Color(white: 0.35), .white, Color(white: 0.75), .white], center: .center), style: StrokeStyle(lineWidth: 2.2, dash: [4, 6]))
                .frame(width: 64, height: 64).rotationEffect(.degrees(ringRotate))
            SecureCatalogImage(urlString: authManager.publicAvatarURL, placeholder: Image(systemName: "person.crop.circle.fill"))
                .frame(width: 54, height: 54).clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1.2))
        }
        .frame(width: 88, height: 88)
    }

    // MARK: FEATURED GAME CARD
    private var featuredGameCard: some View {
        Group {
            if let game = store.catalog.orderedGames.first {
                NavigationLink(destination: GameDetailView(gameID: game.id, isTabBarHidden: $isTabBarHidden)) {
                    VStack(spacing: 12) {
                        HStack {
                            SecureCatalogImage(urlString: game.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(LinearGradient(colors: [.white, Color.white.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.4)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(game.name)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("Hệ thống Mod & Bypass")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .black)).foregroundColor(.black)
                                .frame(width: 32, height: 32)
                                .background(LinearGradient(colors: [.white, Color(white: 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .clipShape(Circle())
                        }
                        
                        Divider().background(Color.white.opacity(0.22))
                        
                        HStack {
                            Label("Truy cập nhanh", systemImage: "bolt.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.65))
                            Spacer()
                            Text("VÀO MENU CHỨC NĂNG")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.black.opacity(0.78)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white, Color.white.opacity(0.3), Color.white.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.3
                            )
                    )
                    .shadow(color: .white.opacity(0.18), radius: 10)
                }
                .buttonStyle(ClassicScaleButtonStyle())
                .padding(.horizontal, 16)
            } else {
                Text("Chưa có trò chơi nào").foregroundColor(.white.opacity(0.5)).padding()
            }
        }
    }

    // MARK: SYSTEM STATUS
    private var systemStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TRẠNG THÁI HỆ THỐNG")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.6)).tracking(1.2)
                .padding(.horizontal, 20)
            
            HStack(spacing: 10) {
                StatusCard(icon: "shield.lefthalf.filled", title: "Bypass", value: "An Toàn", color: .white)
                StatusCard(icon: "lock.shield.fill", title: "Anti-Ban", value: isAntiBanFakeEnabled ? "Online" : "Off", color: isAntiBanFakeEnabled ? .white : .gray)
                StatusCard(icon: "antenna.radiowaves.left.and.right", title: "Server", value: "VN", color: .white)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 6)
    }

    // MARK: ANTIBAN BANNER (NỀN ĐEN VIỀN TRẮNG NEON)
    private var antiBanBanner: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: isAntiBanFakeEnabled ? "checkmark.shield.fill" : "xmark.shield.fill")
                    .font(.system(size: 36))
                    .foregroundColor(isAntiBanFakeEnabled ? .white : .red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isAntiBanFakeEnabled ? "ANTIBAN ONLINE" : "ANTIBAN ĐÃ TẮT")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(isAntiBanFakeEnabled ? .white : .red)
                    
                    Text(isAntiBanFakeEnabled ? "Hệ thống đang bảo vệ bạn an toàn." : "Cảnh báo: Nguy cơ bị ban rất cao!")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }
                
                Spacer()
                
                Toggle("", isOn: $isAntiBanFakeEnabled)
                    .labelsHidden()
                    .tint(.white)
                    .scaleEffect(0.95)
                    .onChange(of: isAntiBanFakeEnabled) { val in
                        if val { iPhoneHaptics.shared.playTickOn() }
                        else { iPhoneHaptics.shared.playTickOff() }
                    }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: isAntiBanFakeEnabled
                            ? [.white, Color.white.opacity(0.35), .white]
                            : [Color.red.opacity(0.85), Color.white.opacity(0.3), Color.red.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.3
                )
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAntiBanFakeEnabled)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var totalEnabledAll: Int {
        allEnabledItems.count
    }
}

// ==========================================================
// MARK: - MÀN HÌNH CHI TIẾT
// ==========================================================
private struct GameDetailView: View {
    let gameID: String
    @Binding var isTabBarHidden: Bool
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var selectedTabID = "aim"
    @State private var onlyActiveFilter = false
    @State private var isDisablingAll = false
    @Environment(\.dismiss) private var dismiss

    private var catalog: GameCatalog { store.catalog }
    private var game: GameCatalogGame? { catalog.games.first(where: { $0.id == gameID }) }
    private var isSessionActive: Bool {
        authManager.isAuthorized
        && !authManager.isInteractionLocked
        && !store.catalog.resolvedMaintenanceEnabled
        && AntiDebug.checkEnvironment() == .safe
    }

    private var items: [GameCatalogItem] {
        (game?.items ?? [])
            .filter { $0.hidden != true && $0.category.rawValue == selectedTabID }
            .filter { item in !onlyActiveFilter || store.isMultiItemOn(item: item) }
            .sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
    }
    private var activeCountInGame: Int { (game?.items ?? []).filter { $0.hidden != true && store.isMultiItemOn(item: $0) }.count }
    private var allActiveItems: [GameCatalogItem] {
        store.catalog.orderedGames
            .flatMap { $0.items }
            .filter { store.isMultiItemOn(item: $0) }
    }
    private var totalActiveAllGames: Int { allActiveItems.count }
    
    private var availableTabs: [GameCatalogTab] {
        let fallback: [GameCatalogTab] = catalog.resolvedTabs
        guard let game else { return fallback }
        let own = game.resolvedTabs(fallback: fallback)
        guard let selected = game.tabIDs else { return own }
        return own.filter { selected.contains($0.id) }
    }
    private var currentTab: GameCatalogTab? { availableTabs.first(where: { $0.id == selectedTabID }) ?? availableTabs.first }
    private var currentCount: Int { (game?.items ?? []).filter { $0.hidden != true && $0.category.rawValue == selectedTabID }.count }

    var body: some View {
        ZStack {
            ModernBackground(urlString: authManager.publicBackgroundURL, particleCount: 16)
            VStack(spacing: 12) {
                headerSection
                categoryBar
                modList
            }
            .safeAreaInset(edge: .bottom) { launchButton }
        }
        .disabled(!isSessionActive).allowsHitTesting(isSessionActive).navigationBarHidden(true)
        .onAppear {
            authManager.enforceImmediateOfflineExpirationCheck()
            store.rememberCatalogItems()
            if !isSessionActive {
                forceDisableAllAndDismiss()
                return
            }
            withAnimation { isTabBarHidden = true }
            if !availableTabs.contains(where: { $0.id == selectedTabID }) { selectedTabID = availableTabs.first?.id ?? "aim" }
        }
        .onDisappear { withAnimation { isTabBarHidden = false } }
        .onChange(of: isSessionActive) { active in if !active { forceDisableAllAndDismiss() } }
        .onChange(of: authManager.isAuthorized) { a in if !a { forceDisableAllAndDismiss() } }
        .onChange(of: store.catalog.resolvedMaintenanceEnabled) { m in if m { forceDisableAllAndDismiss() } }
    }

    private func forceDisableAll(playSound: Bool = true) {
        guard !isDisablingAll else { return }
        let targets = allActiveItems
        if playSound { iPhoneHaptics.shared.playTickOff() }
        isDisablingAll = true
        Task {
            store.disableAllEnabledMods()
            for item in targets {
                if store.isMultiItemOn(item: item) {
                    await store.setMultiEnabled(false, item: item)
                }
            }
            await MainActor.run {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    isDisablingAll = false
                }
            }
        }
    }

    private func forceDisableAllAndDismiss() {
        forceDisableAll(playSound: false)
        withAnimation { isTabBarHidden = false }
        dismiss()
    }

    private var headerSection: some View {
        HStack(spacing: 10) {
            Button {
                iPhoneHaptics.shared.playTap(); withAnimation(.easeInOut(duration: 0.2)) { isTabBarHidden = false }; dismiss()
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.black.opacity(0.8)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.65), lineWidth: 1.1))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(game?.name ?? "Game")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white).lineLimit(1)
                HStack(spacing: 4) {
                    Circle()
                        .fill(activeCountInGame > 0 ? Color.white : Color.green)
                        .frame(width: 5, height: 5)
                    Text(activeCountInGame > 0 ? "\(activeCountInGame) mod đang bật" : "Sẵn sàng")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(activeCountInGame > 0 ? .white : .white.opacity(0.6))
                }
            }
            Spacer(minLength: 4)
            if totalActiveAllGames > 0 || isDisablingAll {
                Button {
                    forceDisableAll(playSound: true)
                } label: {
                    HStack(spacing: 5) {
                        if isDisablingAll {
                            ProgressView().tint(.black).scaleEffect(0.7)
                            Text("Đang tắt").font(.system(size: 10.5, weight: .black, design: .rounded))
                        } else {
                            Image(systemName: "power").font(.system(size: 11, weight: .black))
                            Text("Tắt all").font(.system(size: 10.5, weight: .black, design: .rounded))
                            Text("\(totalActiveAllGames)")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Color.black)
                                .clipShape(Circle())
                        }
                    }
                    .foregroundColor(.black).padding(.horizontal, 10).padding(.vertical, 7)
                    .background(LinearGradient(colors: [.white, Color(white: 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white, lineWidth: 1))
                }
                .disabled(isDisablingAll)
                .buttonStyle(ClassicScaleButtonStyle())
            }
            SecureCatalogImage(urlString: game?.iconURL ?? "", placeholder: Image(systemName: "gamecontroller.fill"))
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white, Color.white.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.3)
                )
        }.padding(.horizontal, 16).padding(.top, 6)
    }

    private var categoryBar: some View {
        HStack(spacing: 9) {
            Menu {
                ForEach(availableTabs) { tab in
                    let count = (game?.items ?? []).filter { $0.hidden != true && $0.category.rawValue == tab.id }.count
                    Button {
                        iPhoneHaptics.shared.playTap(); withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selectedTabID = tab.id }
                    } label: { Label("\(tab.title) (\(count))", systemImage: tab.icon) }
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: currentTab?.icon ?? "square.grid.2x2.fill").font(.system(size: 13, weight: .bold))
                    Text(currentTab?.title.uppercased() ?? "DANH MỤC").font(.system(size: 12.5, weight: .heavy, design: .rounded)).lineLimit(1)
                    Text("\(currentCount)").font(.system(size: 9.5, weight: .black, design: .rounded)).foregroundColor(.white).frame(minWidth: 18, minHeight: 18).background(Color.black).clipShape(Capsule())
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .black))
                }
                .foregroundColor(.black).padding(.horizontal, 12).padding(.vertical, 10)
                .background(LinearGradient(colors: [.white, Color(white: 0.88)], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white, lineWidth: 1))
            }.frame(maxWidth: .infinity)

            Button {
                iPhoneHaptics.shared.playTap(); withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) { onlyActiveFilter.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: onlyActiveFilter ? "checkmark.circle.fill" : "circle.dashed").font(.system(size: 12, weight: .bold))
                    Text("Đang bật").font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(onlyActiveFilter ? .black : .white)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Group {
                    if onlyActiveFilter {
                        LinearGradient(colors: [.white, Color(white: 0.86)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    } else {
                        Color.black.opacity(0.8)
                    }
                })
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(onlyActiveFilter ? Color.white : Color.white.opacity(0.5), lineWidth: 1.1)
                )
            }.buttonStyle(.plain)
        }.padding(.horizontal, 16)
    }

    private var modList: some View {
        ScrollView(showsIndicators: false) {
            if items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray").font(.system(size: 28, weight: .ultraLight)).foregroundColor(.white.opacity(0.45))
                    Text(onlyActiveFilter ? "Chưa có mod nào đang bật" : "Không có mod trong mục này").font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity).padding(.vertical, 44)
                .background(Color.black.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                .padding(.horizontal, 16).padding(.top, 6)
            } else {
                LazyVStack(spacing: 9) {
                    ForEach(items) { item in ModernModRow(item: item, fallbackAvatarURL: authManager.publicAvatarURL) }
                }.padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 20)
            }
        }
    }

    private var launchButton: some View {
        Button {
            authManager.enforceImmediateOfflineExpirationCheck()
            guard isSessionActive else {
                forceDisableAllAndDismiss()
                return
            }
            iPhoneHaptics.shared.playLaunch()
            let raw = (game?.launchURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: raw), !raw.isEmpty { UIApplication.shared.open(url) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill").font(.system(size: 13, weight: .black))
                Text("KHỞI ĐỘNG GAME").font(.system(size: 14, weight: .black, design: .rounded)).tracking(0.9)
            }
            .foregroundColor(.black).frame(maxWidth: .infinity).frame(height: 48)
            .background(LinearGradient(colors: [.white, Color(white: 0.88)], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Color.white, lineWidth: 1.2))
            .shadow(color: .white.opacity(0.4), radius: 8)
        }.buttonStyle(ClassicScaleButtonStyle()).padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
        .background(LinearGradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.9), Color.black], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }
}

// ==========================================================
// MARK: - MOD ROW (ĐEN TUYỀN VIỀN TRẮNG NEON)
// ==========================================================
private struct ModernModRow: View {
    let item: GameCatalogItem
    let fallbackAvatarURL: String
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var showDetailSheet = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var localToggle: Bool = false
    @State private var burst = false
    @State private var iconScale: CGFloat = 1.0

    private var isSessionActive: Bool {
        authManager.isAuthorized
        && !authManager.isInteractionLocked
        && !store.catalog.resolvedMaintenanceEnabled
        && AntiDebug.checkEnvironment() == .safe
    }
    private var isVip: Bool { item.name.localizedCaseInsensitiveContains("VIP") || item.name.localizedCaseInsensitiveContains("AIM HEAD") || item.name.localizedCaseInsensitiveContains("CAN CHECK") }
    private var badgeLabel: String {
        let custom = (item.badge ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? (isVip ? "VIP" : "") : custom
    }
    private var hasBadge: Bool { !badgeLabel.isEmpty }
    private var hasGuide: Bool { !(item.usageGuide ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !(item.imageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var cardAvatarURL: String {
        let img = (item.imageURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return img.isEmpty ? fallbackAvatarURL : img
    }
    private var subtitleDisplay: String {
        let s = (item.subtitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? "Sẵn sàng kích hoạt" : s
    }

    var body: some View {
        let hasLink = !item.resolvedFileURLs.isEmpty
        let isOn = store.isMultiItemOn(item: item)
        let busy = store.isMultiItemBusy(item: item)

        HStack(spacing: 11) {
            ZStack {
                SparkleBurst(trigger: burst).frame(width: 44, height: 44)
                SecureCatalogImage(urlString: cardAvatarURL, placeholder: Image(systemName: "bolt.fill"))
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(
                                isOn
                                    ? LinearGradient(colors: [.white, Color.white.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Color.white.opacity(0.38), Color.white.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: isOn ? 1.5 : 1.0
                            )
                    )
                    .scaleEffect(iconScale)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(item.name)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white).lineLimit(1)
                    if hasBadge {
                        Text(badgeLabel)
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 5).padding(.vertical, 1.5)
                            .background(LinearGradient(colors: [.white, Color(white: 0.85)], startPoint: .leading, endPoint: .trailing))
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 4) {
                    Circle()
                        .fill(busy ? Color.yellow : (isOn ? Color.white : Color.white.opacity(0.3)))
                        .frame(width: 5, height: 5)
                    Text(busy ? "Đang nạp..." : (isOn ? "Đang bật" : subtitleDisplay))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(busy ? .yellow : (isOn ? .white : .white.opacity(0.55)))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Button { iPhoneHaptics.shared.playTap(); showDetailSheet = true } label: {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 17))
                    .foregroundColor(.white.opacity(isOn ? 0.8 : 0.4))
            }.buttonStyle(.plain)
            
            if busy {
                ProgressView().tint(.white).scaleEffect(0.72).frame(width: 42, height: 26)
            } else {
                Toggle("", isOn: $localToggle)
                    .labelsHidden()
                    .tint(.white)
                    .scaleEffect(0.82)
                    .disabled(!hasLink && !isOn)
                    .onAppear { localToggle = isOn }
                    .onChange(of: isOn) { v in if localToggle != v { localToggle = v } }
                    .onChange(of: localToggle) { v in if v != isOn { handleToggle(v) } }
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isOn ? Color.white.opacity(0.11) : Color.black.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isOn
                        ? LinearGradient(colors: [.white, Color.white.opacity(0.7), .white], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.38), Color.white.opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: isOn ? 1.5 : 1.0
                )
        )
        .opacity(hasLink ? 1 : 0.5)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isOn)
        .onChange(of: isSessionActive) { active in
            if !active {
                showDetailSheet = false
                showErrorAlert = false
                if localToggle { localToggle = false }
                if store.isMultiItemOn(item: item) {
                    Task { await store.setMultiEnabled(false, item: item) }
                }
            }
        }
        .sheet(isPresented: $showDetailSheet) { ModDetailSheet(item: item) }
        .alert("Lỗi kích hoạt Mod", isPresented: $showErrorAlert) { Button("OK", role: .cancel) { } } message: { Text(errorMessage) }
    }

    private func handleToggle(_ newVal: Bool) {
        guard !store.isMultiItemBusy(item: item) else { localToggle = store.isMultiItemOn(item: item); return }
        if newVal {
            // 1. Kiểm tra ngay trước khi kích hoạt mod
            authManager.enforceImmediateOfflineExpirationCheck()
            guard isSessionActive else {
                localToggle = false
                store.disableAllEnabledMods()
                return
            }

            iPhoneHaptics.shared.playTickOn()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { iconScale = 1.15 }
            withAnimation(.easeOut(duration: 0.45)) { burst = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { iconScale = 1.0 } }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { var tx = Transaction(); tx.disablesAnimations = true; withTransaction(tx) { burst = false } }
            
            Task {
                await store.setMultiEnabled(true, item: item)
                
                // 2. Hậu kiểm sau khi nạp mod: nếu key vừa hết hạn hoặc phiên bị khóa trong lúc nạp -> tắt ngay
                await MainActor.run {
                    authManager.enforceImmediateOfflineExpirationCheck()
                }
                if !isSessionActive {
                    await store.setMultiEnabled(false, item: item)
                    await MainActor.run {
                        localToggle = false
                        store.disableAllEnabledMods()
                    }
                    return
                }
                
                if let error = store.lastError {
                    await MainActor.run {
                        errorMessage = error
                        showErrorAlert = true
                    }
                } else if hasGuide {
                    await MainActor.run {
                        showDetailSheet = true
                    }
                }
            }
        } else {
            iPhoneHaptics.shared.playTickOff()
            Task { await store.setMultiEnabled(false, item: item) }
        }
    }
}

// ==========================================================
// MARK: - MOD DETAIL SHEET
// ==========================================================
struct ModDetailSheet: View {
    let item: GameCatalogItem
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = GameCatalogStore.shared
    @StateObject private var authManager = CustomAuthManager.shared
    @State private var copied = false

    private var isYouTubeLink: Bool { let g = (item.usageGuide ?? "").lowercased(); return g.contains("youtube.com") || g.contains("youtu.be") }

    var body: some View {
        NavigationStack {
            ZStack {
                ModernBackground(urlString: authManager.publicBackgroundURL, particleCount: 14)
                ScrollView {
                    VStack(spacing: 16) {
                        if let imgURL = item.imageURL, !imgURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            SecureCatalogImage(urlString: imgURL, placeholder: Image(systemName: "photo"))
                                .frame(maxWidth: .infinity).frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.75), lineWidth: 1.2))
                        }
                        if let guide = item.usageGuide, !guide.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "text.book.closed.fill").foregroundColor(.white)
                                    Text("Hướng dẫn").font(.headline).foregroundColor(.white)
                                    Spacer()
                                    Button {
                                        iPhoneHaptics.shared.playTickOn(); UIPasteboard.general.string = guide; copied = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                                    } label: {
                                        HStack(spacing: 4) { Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc"); Text(copied ? "Đã Copy" : "Copy") }
                                            .font(.caption.bold())
                                            .foregroundColor(copied ? .black : .white)
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .background(copied ? Color.white : Color.black.opacity(0.8))
                                            .clipShape(Capsule())
                                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.7), lineWidth: 1))
                                    }.buttonStyle(.plain)
                                }
                                Text(guide)
                                    .font(.body).foregroundColor(.white.opacity(0.92))
                                    .padding(13).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.black.opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(Color.white.opacity(0.45), lineWidth: 1))
                                if isYouTubeLink {
                                    Button {
                                        iPhoneHaptics.shared.playTap()
                                        if let url = URL(string: guide.trimmingCharacters(in: .whitespacesAndNewlines)) { UIApplication.shared.open(url) }
                                    } label: {
                                        HStack(spacing: 8) { Image(systemName: "play.rectangle.fill"); Text("Mở Video Hướng Dẫn") }
                                            .font(.headline).foregroundColor(.black)
                                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                                            .background(LinearGradient(colors: [.white, Color(white: 0.86)], startPoint: .leading, endPoint: .trailing))
                                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                        if (item.imageURL ?? "").isEmpty && (item.usageGuide ?? "").isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.questionmark").font(.system(size: 44)).foregroundColor(.white.opacity(0.35))
                                Text("Chưa có hướng dẫn").foregroundColor(.white.opacity(0.6))
                            }.padding(.top, 50)
                        }
                    }.padding(18)
                }
            }
            .navigationTitle(item.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Đóng") { iPhoneHaptics.shared.playTap(); dismiss() }.foregroundColor(.white).font(.headline.bold()) } }
            .onChange(of: authManager.isAuthorized) { a in if !a { dismiss() } }
            .onChange(of: authManager.isInteractionLocked) { locked in if locked { dismiss() } }
            .onChange(of: store.catalog.resolvedMaintenanceEnabled) { m in if m { dismiss() } }
        }
    }
}
